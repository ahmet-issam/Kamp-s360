"""Compile feature files against Flutter/plugin APIs with explicit app-interface fixtures.
These fixtures are not the production controller and do not test persistence/auth.
"""
from pathlib import Path
import shutil
import sys

source = Path(__file__).resolve().parents[1]
root = Path(sys.argv[1] if len(sys.argv) > 1 else 'task_flutter_check').resolve()
root.mkdir(parents=True, exist_ok=True)
shutil.copytree(source / 'lib', root / 'lib', dirs_exist_ok=True)
shutil.copytree(source / 'scripts', root / 'scripts', dirs_exist_ok=True)
shutil.copy2(source / 'test_support/models.dart', root / 'lib/core/models.dart')
files = {
'pubspec.yaml': '''name: task_flutter_check
publish_to: none
environment:
  sdk: '>=3.10.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  flutter_local_notifications: 19.5.0
  timezone: ^0.10.1
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
''',
'analysis_options.yaml': 'include: package:flutter_lints/flutter.yaml\n',
'lib/core/app_controller.dart': '''import 'package:flutter/material.dart';
import 'models.dart';
import 'task_rules.dart';
class AppController extends ChangeNotifier {
  bool signedIn = true;
  bool notificationsEnabled = true;
  List<StudentTask> tasks = [];
  Set<String> readNoticeIds = {};
  List<CampusNotice> get notices => notificationsEnabled ? buildTaskNotices(tasks, DateTime.now()) : [];
  void refreshTaskNotices() { notifyListeners(); }
  void setNotifications(bool value) { notificationsEnabled = value; notifyListeners(); }
  void readNotice(String id) { readNoticeIds.add(id); notifyListeners(); }
  void readAllNotices() { readNoticeIds.addAll(notices.map((notice) => notice.id)); notifyListeners(); }
  void addTask(StudentTask task) { tasks.add(task); notifyListeners(); }
  void removeTask(String id) { tasks.removeWhere((task) => task.id == id); notifyListeners(); }
  void updateTask(StudentTask task) { tasks = tasks.map((value) => value.id == task.id ? task : value).toList(); notifyListeners(); }
  void setTaskDone(String id, bool done) { tasks = tasks.map((task) => task.id == id ? task.copyWith(done: done) : task).toList(); notifyListeners(); }
}
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);
  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
''',
'lib/core/cloud_sync.dart': 'class CloudSync { static String? get userId => null; }\n',
'lib/core/campus_backend.dart': '''class StudentSupportTicket {
  const StudentSupportTicket({required this.id, required this.subject, this.adminReply, this.repliedAt});
  final String id, subject;
  final String? adminReply;
  final DateTime? repliedAt;
}
''',
'lib/core/support_notification_store.dart': '''import 'package:flutter/foundation.dart';
import 'campus_backend.dart';
class SupportNotificationStore extends ChangeNotifier {
  static final instance = SupportNotificationStore();
  List<StudentSupportTicket> replies = [];
  bool loading = false;
  String? error;
  int get unreadCount => replies.length;
  bool isRead(StudentSupportTicket ticket) => false;
  void markRead(StudentSupportTicket ticket) { notifyListeners(); }
  void markAllRead() { notifyListeners(); }
  Future<void> refresh({bool showLoading = true}) async {}
}
''',
'lib/core/theme.dart': '''import 'package:flutter/material.dart';
class CampusVisuals {
  static CampusVisuals of(BuildContext context) => CampusVisuals();
  Color get muted => Colors.grey;
  Color accent(int index) => Colors.blue;
}
''',
'lib/core/widgets/shared.dart': '''import 'package:flutter/material.dart';
String dateTr(DateTime value) => '${value.day}.${value.month}.${value.year}';
void openScreen(BuildContext context, Widget screen) { Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => screen)); }
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child}); final Widget child;
  @override Widget build(BuildContext context) => Card(child: child);
}
class ScreenHeading extends StatelessWidget {
  const ScreenHeading({super.key, required this.title, required this.subtitle, this.art = true});
  final String title, subtitle; final bool art;
  @override Widget build(BuildContext context) => Text(title);
}
class ColorIcon extends StatelessWidget {
  const ColorIcon(this.icon, {super.key, this.index = 0, this.size = 48});
  final IconData icon; final int index; final double size;
  @override Widget build(BuildContext context) => Icon(icon, size: size);
}
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color}); final String label; final Color color;
  @override Widget build(BuildContext context) => Text(label);
}
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.label, {super.key}); final String label;
  @override Widget build(BuildContext context) => Text(label);
}
''',
'lib/features/campus_news_screen.dart': '''import 'package:flutter/material.dart';
class CampusNewsScreen extends StatelessWidget {
  const CampusNewsScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold();
}
''',
'lib/features/support_screen.dart': '''import 'package:flutter/material.dart';
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold();
}
''',
}
for relative, content in files.items():
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')
print(root)
