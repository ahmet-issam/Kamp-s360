import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flutter_check/core/app_controller.dart';
import 'package:task_flutter_check/core/models.dart';
import 'package:task_flutter_check/core/task_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native reconcile cancels completed/deleted/disabled/logout and retries errors', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final scheduled = <int, Map<dynamic, dynamic>>{};
    var failSchedule = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'initialize':
        case 'areNotificationsEnabled':
        case 'requestNotificationsPermission':
          return true;
        case 'getNotificationAppLaunchDetails':
          return {'notificationLaunchedApp': false};
        case 'cancel':
          scheduled.remove((call.arguments as Map)['id']);
          return null;
        case 'zonedSchedule':
          if (failSchedule) {
            throw PlatformException(code: 'test_failure');
          }
          final values = call.arguments as Map;
          scheduled[values['id'] as int] = values;
          return null;
      }
      return null;
    });
    final service = TaskReminderService.instance;
    final app = AppController();
    final future = DateTime.now().toUtc().add(const Duration(days: 3, hours: 3));
    StudentTask task(String id) => StudentTask(
      id: id, title: 'Final', course: 'Java', date: DateTime(future.year, future.month, future.day),
      hour: '12:00', room: '', isExam: true,
    );
    try {
      app.tasks = [task('first')];
      service.start(app);
      expect(await service.requestPermission(), isTrue);
      expect(scheduled.length, 3);
      app.setTaskDone('first', true);
      await service.requestPermission();
      expect(scheduled, isEmpty);
      app.setTaskDone('first', false);
      app.removeTask('first');
      app.addTask(task('latest'));
      await service.requestPermission();
      expect(scheduled.length, 3);
      expect(scheduled.values.every((entry) => entry['payload'] == 'campus360_task_v1:latest'), isTrue);
      app.setNotifications(false);
      await service.requestPermission();
      expect(scheduled, isEmpty);
      app.setNotifications(true);
      await service.requestPermission();
      expect(scheduled.length, 3);
      app.signedIn = false;
      app.refreshTaskNotices();
      await service.requestPermission();
      expect(scheduled, isEmpty);
      app.signedIn = true;
      failSchedule = true;
      app.refreshTaskNotices();
      await service.requestPermission();
      expect(service.error, isNotNull);
      failSchedule = false;
      await service.requestPermission();
      expect(service.error, isNull);
      expect(scheduled.length, 3);
      app.removeTask('latest');
      await service.requestPermission();
      expect(scheduled, isEmpty);
    } finally {
      await service.stop();
      app.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
