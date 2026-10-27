"""Install library hub with preflight checks. No saved data is changed."""
import argparse
from datetime import datetime
from pathlib import Path
import re
import shutil

FILES = ['lib/core/library_repository.dart', 'lib/core/library_rules.dart', 'lib/features/library_screen.dart', 'scripts/test_library_rules.dart']

def patch_home(text):
    directive = "import 'library_screen.dart';"
    if directive not in text:
        text = directive + '\n' + text
    if 'const LibraryScreen()' not in text:
        # Restrict the replacement to the library shortcut, preserve other places.
        pattern = r"(_Shortcut\(\s*'Kütüphane'\s*,\s*Icons\.local_library_outlined\s*,\s*\(\)\s*=>\s*openScreen\(\s*context\s*,\s*)PlaceDetailScreen\(\s*place:\s*campusPlaces\[1\]\s*\)"
        text, count = re.subn(pattern, lambda m: m[1] + 'const LibraryScreen()', text)
        if count != 1:
            raise ValueError('Library shortcut layout differs in home_screen.dart. No files changed.')
    # The old library shortcut may have been the last use of demo_data.dart.
    if not re.search(r'\b(campusPlaces|academicians|facultyDepartments|faculties)\b', text):
        text = re.sub(r"^import ['\"]\.\./data/demo_data\.dart['\"];\s*\n", '', text, flags=re.M)
    return text

def patch_rules(text):
    old = "final kind = task.isExam ? 'Sınav' : 'Ödev';"
    new = "final kind = task.id.startsWith('library_return_') ? 'Kitap iadesi' : task.isExam ? 'Sınav' : 'Ödev';"
    # Whitespace independent so dart format doesn't break preflight.
    pattern = r"final kind\s*=\s*task\.isExam\s*\?\s*'Sınav'\s*:\s*'Ödev';"
    if "task.id.startsWith('library_return_')" not in text:
        text, count = re.subn(pattern, new, text)
        if count != 1:
            raise ValueError('Task notice layout differs. No files changed.')
    return text

def patch_service(text):
    old = "${task.isExam ? 'Sınav' : 'Ödev'}"
    new = "${task.id.startsWith('library_return_') ? 'Kitap iadesi' : task.isExam ? 'Sınav' : 'Ödev'}"
    if new not in text:
        if old not in text:
            raise ValueError('Task reminder layout differs. No files changed.')
        text = text.replace(old, new, 1)
    return text

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    root = Path.cwd()
    package = Path(__file__).resolve().parent
    if not (root / 'pubspec.yaml').exists():
        raise ValueError('Run from the Flutter project root.')
    updates = {}
    for name in FILES:
        updates[name] = (package / name).read_text(encoding='utf-8')
    for name, patcher in [('lib/features/home_screen.dart', patch_home),
                          ('lib/core/task_rules.dart', patch_rules),
                          ('lib/core/task_reminder_service.dart', patch_service)]:
        path = root / name
        if not path.exists():
            raise ValueError(f'Required file missing: {name}. Install the tasks update first.')
        updates[name] = patcher(path.read_text(encoding='utf-8'))
    controller = (root / 'lib/core/app_controller.dart').read_text(encoding='utf-8')
    for method in ['addTask', 'updateTask', 'removeTask', 'setTaskDone']:
        if not re.search(r'\b' + method + r'\s*\(', controller):
            raise ValueError(f'Required controller method missing: {method}')
    changed = {name: data for name, data in updates.items()
               if not (root / name).exists() or (root / name).read_text(encoding='utf-8') != data}
    print('Files to update:', len(changed))
    for name in changed:
        print(name)
    if not args.apply:
        print('Preview only. Use --apply to install.')
        return
    backup = root / 'backups' / ('library_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    # Complete preflight above before writing any project file.
    for name in changed:
        target = root / name
        if target.exists():
            saved = backup / name
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, saved)
    written = []
    try:
        for name, data in changed.items():
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(data, encoding='utf-8')
            written.append(name)
    except Exception:
        for name in reversed(written):
            saved = backup / name
            if saved.exists():
                shutil.copy2(saved, root / name)
            else:
                (root / name).unlink(missing_ok=True)
        raise
    print('APPLIED. Backups:', backup)
    print('Saved tasks, notes, accounts and release signing were not changed.')
    print('NEXT: dart format lib/features/library_screen.dart lib/core/library_repository.dart lib/core/library_rules.dart lib/features/home_screen.dart lib/core/task_rules.dart lib/core/task_reminder_service.dart scripts/test_library_rules.dart')
    print('NEXT: dart scripts/test_library_rules.dart')
    print('NEXT: flutter analyze')

if __name__ == '__main__':
    main()
