"""Install agenda and reminders with preflight checks and backups."""
import argparse
from datetime import datetime
from pathlib import Path
import re
import shutil
import xml.etree.ElementTree as ET


def add_import(text, directive):
    return text if directive in text else directive + '\n' + text


def patch_controller(text):
    old = 'taskNotices(tasks, DateTime.now())'
    new = 'buildTaskNotices(tasks, DateTime.now())'
    if old not in text and new not in text:
        raise ValueError('Notification getter differs in app_controller.dart')
    text = text.replace(old, new)
    text = add_import(text, "import 'task_rules.dart';")
    if 'void refreshTaskNotices()' not in text:
        marker = '  void readNotice(String id)'
        if marker not in text:
            raise ValueError('readNotice not found in app_controller.dart')
        text = text.replace(marker,
            '  void refreshTaskNotices() { notifyListeners(); }\n' + marker, 1)
    return text


def patch_main(text):
    text = add_import(text, "import 'core/task_reminder_service.dart';")
    call = 'TaskReminderService.instance.start(controller);'
    if call not in text:
        marker = '  runApp('
        if marker not in text:
            raise ValueError('runApp not found in main.dart')
        text = text.replace(marker, '  ' + call + '\n\n' + marker, 1)
    return text


def patch_shell(text):
    marker = 'class _AppShellState extends State<AppShell> {'
    if marker not in text:
        raise ValueError('AppShell not found in app.dart')
    before, shell = text.split(marker, 1)
    if 'void _openTaskReminder()' not in shell:
        if '_support.start();' not in shell or '_support.stop();' not in shell:
            raise ValueError('AppShell lifecycle differs')
        shell = shell.replace('_support.start();', '''_support.start();
    TaskReminderService.instance.openedTaskId.addListener(_openTaskReminder);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTaskReminder());''', 1)
        shell = shell.replace('_support.stop();', '''TaskReminderService.instance.openedTaskId.removeListener(_openTaskReminder);
    _support.stop();''', 1)
        method = '''
  bool _openingTaskReminder = false;
  void _openTaskReminder() {
    if (!mounted || _openingTaskReminder) { return; }
    final id = TaskReminderService.instance.openedTaskId.value;
    if (id == null) { return; }
    _openingTaskReminder = true;
    TaskReminderService.instance.openedTaskId.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) { return; }
      final tasks = AppScope.of(context).tasks.where((task) => task.id == id);
      if (tasks.isNotEmpty) {
        final task = tasks.first;
        await Navigator.of(context).push<void>(MaterialPageRoute<void>(
          builder: (_) => TaskFormScreen(isExam: task.isExam, edit: task),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bu görev artık mevcut değil.'),
        ));
      }
      _openingTaskReminder = false;
      if (mounted && TaskReminderService.instance.openedTaskId.value != null) {
        _openTaskReminder();
      }
    });
  }
'''
        shell = method + shell
    text = before + marker + shell
    text = add_import(text, "import 'core/task_reminder_service.dart';")
    return add_import(text, "import 'features/agenda_screen.dart';")


def patch_manifest(text):
    if '</application>' not in text:
        raise ValueError('Android application closing tag missing')
    permissions = ''
    for name in ['POST_NOTIFICATIONS', 'RECEIVE_BOOT_COMPLETED']:
        full = 'android.permission.' + name
        if full not in text:
            permissions += f'    <uses-permission android:name="{full}"/>\n'
    if permissions:
        text = re.sub(r'(<manifest\b[^>]*>)', lambda match: match[0] + '\n' + permissions, text, count=1)
    receivers = ''
    if 'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver' not in text:
        receivers += '        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>\n'
    if 'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver' not in text:
        receivers += '''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
    text = text.replace('</application>', receivers + '    </application>', 1) if receivers else text
    ET.fromstring(text)
    return text


def patch_gradle(text, kotlin):
    flag = 'isCoreLibraryDesugaringEnabled = true' if kotlin else 'coreLibraryDesugaringEnabled true'
    text = re.sub(r'(?:isCoreLibraryDesugaringEnabled\s*=|coreLibraryDesugaringEnabled\s*=?)\s*false', flag, text)
    if not re.search(r'(?:isCoreLibraryDesugaringEnabled|coreLibraryDesugaringEnabled)\s*=?\s*true', text):
        if 'compileOptions {' in text:
            text = text.replace('compileOptions {', 'compileOptions {\n        ' + flag, 1)
        elif 'android {' in text:
            text = text.replace('android {', 'android {\n    compileOptions {\n        ' + flag + '\n    }', 1)
        else:
            raise ValueError('Android Gradle layout differs')
    dependency = 'com.android.tools:desugar_jdk_libs:2.1.4'
    if re.search(r'coreLibraryDesugaring\s*[ (][^\n]*desugar_jdk_libs', text):
        text = re.sub(r'com\.android\.tools:desugar_jdk_libs:[\d.]+', dependency, text)
    else:
        declaration = f'coreLibraryDesugaring("{dependency}")' if kotlin else f"coreLibraryDesugaring '{dependency}'"
        text += '\n\ndependencies {\n    ' + declaration + '\n}\n'
    def sdk(match):
        return match[1] + str(max(35, int(match[2])))
    text = re.sub(r'(compileSdk(?:Version)?\s*=?\s*)(\d+)', sdk, text)
    return text


def patch_swift_delegate(text):
    line = 'UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate'
    if line in text:
        return text
    setup = '\n    if #available(iOS 10.0, *) {\n      ' + line + '\n    }\n'
    pattern = r'(override\s+func\s+application\s*\([\s\S]*?didFinishLaunchingWithOptions[\s\S]*?\)\s*->\s*Bool\s*\{)'
    if re.search(pattern, text):
        text = re.sub(pattern, lambda match: match[0] + setup, text, count=1)
    else:
        pattern = r'(class\s+AppDelegate\s*:\s*FlutterAppDelegate[^\{]*\{)'
        if 'didFinishLaunchingWithOptions' in text or not re.search(pattern, text):
            raise ValueError('Custom iOS delegate requires review. No files changed.')
        method = '\n  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {' + setup + '    return super.application(application, didFinishLaunchingWithOptions: launchOptions)\n  }\n'
        text = re.sub(pattern, lambda match: match[0] + method, text, count=1)
    return add_import(text, 'import UserNotifications')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    root = Path.cwd()
    package = Path(__file__).resolve().parent
    if not (root / 'pubspec.yaml').exists():
        raise SystemExit('Run from the Flutter project root.')
    updates = []
    for relative in ['lib/core/task_rules.dart', 'lib/core/task_reminder_service.dart',
                     'lib/features/agenda_screen.dart', 'lib/features/notifications_screen.dart',
                     'scripts/test_task_rules.dart']:
        updates.append((root / relative, (package / relative).read_text(encoding='utf-8')))
    for relative, patch in [('lib/core/app_controller.dart', patch_controller),
                            ('lib/main.dart', patch_main), ('lib/app.dart', patch_shell)]:
        path = root / relative
        updates.append((path, patch(path.read_text(encoding='utf-8'))))
    manifest = root / 'android/app/src/main/AndroidManifest.xml'
    if manifest.exists():
        updates.append((manifest, patch_manifest(manifest.read_text(encoding='utf-8'))))
        gradle = root / 'android/app/build.gradle.kts'
        if not gradle.exists():
            gradle = root / 'android/app/build.gradle'
        if not gradle.exists():
            raise ValueError('Android app Gradle file missing')
        updates.append((gradle, patch_gradle(gradle.read_text(encoding='utf-8'), gradle.suffix == '.kts')))
        updates.append((root / 'android/app/src/main/res/drawable/ic_task_notification.xml',
            '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="M19,3h-1V1h-2v2H8V1H6v2H5c-1.1,0 -2,0.9 -2,2v14c0,1.1 0.9,2 2,2h14c1.1,0 2,-0.9 2,-2V5c0,-1.1 -0.9,-2 -2,-2zM19,19H5V8h14v11zM7,10h5v5H7z"/></vector>\n'))
        updates.append((root / 'android/app/src/main/res/raw/keep_task_notifications.xml',
            '<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_task_notification"/>\n'))
    delegate = root / 'ios/Runner/AppDelegate.swift'
    if delegate.exists():
        updates.append((delegate, patch_swift_delegate(delegate.read_text(encoding='utf-8'))))
    objc = root / 'ios/Runner/AppDelegate.m'
    if not delegate.exists() and objc.exists():
        text = objc.read_text(encoding='utf-8')
        line = '[UNUserNotificationCenter currentNotificationCenter].delegate = (id<UNUserNotificationCenterDelegate>) self;'
        if line not in text:
            marker = '[GeneratedPluginRegistrant registerWithRegistry:self];'
            if marker not in text:
                raise ValueError('iOS Objective-C AppDelegate layout differs. No files changed.')
            text = add_import(text, '#import <UserNotifications/UserNotifications.h>')
            text = text.replace(marker, 'if (@available(iOS 10.0, *)) {\n    ' + line + '\n  }\n  ' + marker, 1)
        updates.append((objc, text))
    updates = [(path, text) for path, text in updates if not path.exists() or path.read_text(encoding='utf-8') != text]
    print('Files to update:', len(updates))
    for path, _ in updates:
        print(path.relative_to(root))
    if not args.apply:
        print('Preview only. Add --apply to install.')
        return
    stamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    for path, text in updates:
        if path.exists():
            shutil.copy2(path, path.with_name(path.name + '.backup_tasks_' + stamp))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')
    print('APPLIED. Existing files backed up. Saved tasks and notes were not modified.')
    print('NEXT: flutter pub add flutter_local_notifications:19.5.0 timezone:^0.10.1')
    print('NEXT: flutter analyze')


if __name__ == '__main__':
    main()
