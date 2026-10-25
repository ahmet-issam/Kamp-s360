import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'app_controller.dart';
import 'cloud_sync.dart';
import 'task_rules.dart';

class TaskReminderService extends ChangeNotifier with WidgetsBindingObserver {
  TaskReminderService._();
  static final instance = TaskReminderService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  final openedTaskId = ValueNotifier<String?>(null);
  AppController? _app;
  Timer? _timer;
  Future<void> _queue = Future<void>.value();
  Future<void>? _initialization;
  String? _fingerprint;
  int _generation = 0;
  bool _ready = false;
  bool _foreground = true;
  bool? permissionGranted;
  bool scheduling = false;
  int scheduledCount = 0;
  String? error;
  static const _idBase = 1261821952;
  static const _limit = 60;
  static const _prefix = 'campus360_task_v1:';
  bool get supported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  void start(AppController app) {
    if (_app == app) {
      return;
    }
    _app?.removeListener(_onChange);
    _timer?.cancel();
    _app = app;
    app.addListener(_onChange);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_foreground) {
        app.refreshTaskNotices();
      }
    });
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    if (!supported) {
      return;
    }
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_task_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false, requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ), onDidReceiveNotificationResponse: (response) => _openPayload(response.payload));
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _openPayload(launch?.notificationResponse?.payload);
      }
      _ready = true;
      await _checkPermission();
      _onChange();
    } catch (_) {
      error = 'Telefon hatırlatmaları başlatılamadı.';
      notifyListeners();
    }
  }

  void _openPayload(String? payload) {
    if (payload?.startsWith(_prefix) == true) {
      openedTaskId.value = payload!.substring(_prefix.length);
    }
  }

  Future<void> _checkPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      permissionGranted = await _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final options = await _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
      permissionGranted = options?.isEnabled;
    }
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    await _initialization;
    if (!_ready) {
      return false;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      } else {
        await _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
      }
      await _checkPermission();
      _fingerprint = null;
      _onChange();
      await _queue;
      return permissionGranted == true;
    } catch (_) {
      error = 'Bildirim izni alınamadı. Telefon ayarlarını kontrol edin.';
      notifyListeners();
      return false;
    }
  }

  void _onChange() {
    final app = _app;
    if (app == null || !_ready) {
      return;
    }
    final signature = jsonEncode([
      app.signedIn, app.notificationsEnabled, CloudSync.userId,
      app.tasks.map((task) => task.toMap()).toList(),
    ]);
    if (_fingerprint == signature) {
      return;
    }
    _fingerprint = signature;
    final request = ++_generation;
    final reminders = app.signedIn && app.notificationsEnabled
        ? planTaskReminders(List.of(app.tasks), DateTime.now(), limit: _limit)
        : <PlannedTaskReminder>[];
    _queue = _queue.then((_) => _reconcile(reminders, request));
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'campus360_tasks_v1', 'Sınav ve ödev hatırlatmaları',
      channelDescription: 'Kişisel sınav ve ödev teslim tarihleri',
      importance: Importance.high, priority: Priority.high,
      icon: 'ic_task_notification',
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
  );

  Future<void> _reconcile(List<PlannedTaskReminder> reminders, int request) async {
    if (request != _generation) {
      return;
    }
    scheduling = true;
    notifyListeners();
    try {
      // A private range: do not cancel notifications belonging to other features.
      for (var i = 0; i < _limit; i++) {
        await _plugin.cancel(_idBase + i);
      }
      scheduledCount = 0;
      for (var i = 0; i < reminders.length; i++) {
        if (request != _generation) {
          break;
        }
        final reminder = reminders[i];
        if (!reminder.at.isAfter(DateTime.now().toUtc())) {
          continue;
        }
        final task = reminder.task;
        final title = reminder.leadMinutes == 0 ? 'Görev zamanı'
            : reminder.leadMinutes == 60 ? '1 saat kaldı' : '1 gün kaldı';
        await _plugin.zonedSchedule(
          _idBase + i, '${task.isExam ? 'Sınav' : 'Ödev'} · $title',
          '${task.title} · ${task.course} · ${task.hour}',
          tz.TZDateTime.from(reminder.at, tz.getLocation('Europe/Istanbul')),
          _details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '$_prefix${task.id}',
        );
        scheduledCount++;
      }
      error = null;
    } catch (_) {
      error = 'Telefon hatırlatmaları planlanamadı. İzinleri ve telefon ayarlarını kontrol edin.';
      _fingerprint = null;
    } finally {
      scheduling = false;
      notifyListeners();
    }
  }

  Future<bool> testNotification() async {
    if (!await requestPermission()) {
      return false;
    }
    try {
      await _plugin.show(_idBase + 99, 'Kampüs360',
          'Deneme bildirimi. Sınav ve ödev hatırlatmaları etkin.', _details);
      return true;
    } catch (_) {
      error = 'Deneme bildirimi gösterilemedi.';
      notifyListeners();
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _app?.refreshTaskNotices();
      if (_ready) {
        unawaited(_checkPermission().then((_) {
          _fingerprint = null;
          _onChange();
        }).catchError((Object _) {}));
      }
    }
  }
}
