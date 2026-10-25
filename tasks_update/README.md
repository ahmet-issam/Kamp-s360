# Tasks, agenda and reminder update

## Behavior

- Exam/homework creation and editing, search across title/course/description/location, pending/overdue/completed/all filters and date filtering.
- Deadlines combine the stored date and clock time in Europe/Istanbul (UTC+3). Sorting compares the entire deadline. Same-day passed times are overdue.
- Duplicate title/course/type/deadline entries are rejected. Past appointments require confirmation. Completion removes the personal in-app reminder. Delete offers undo.
- In-app reminders include unfinished overdue tasks and tasks through the end of seven days ahead. IDs include due time, visible task fields and today/overdue phase, so changed appointments become unread again. Reminder opening reaches the corresponding task editor. Read/all-read and unread filtering retain existing persistence. Support replies remain a separate source and their existing account-scoped store is preserved.
- While running in the foreground, the notification list and bell recompute each minute and on resume. This is not push delivery from a server.
- Android/iOS local reminders at one day, one hour and deadline, with the nearest 60 scheduled triggers retained. Completed/deleted tasks, disabled reminders and logout cancel the private task-notification ID range. Reconcile operations are serialized and generation-checked to prevent older snapshots overwriting newer ones. Reopening/resuming replenishes the bounded native queue. Devices with more than 60 upcoming triggers need to reopen the app to replenish it.
- Native permission request and an immediate test notification are available in Bildirimler. Notification taps open the current user's matching task, including cold start.
- Browser/desktop builds show reminders inside the app. They do not send background system notifications. Android uses inexactAllowWhileIdle, so delivery time may be delayed by Android power scheduling. iOS delivery depends on granted permissions. Remote changes made on another device only change native reminders on this device after this device syncs/runs again.

## Install

Keep this folder outside the project. From the Flutter root:

```powershell
python PATH_TO_UPDATE/install_tasks.py --apply
flutter pub add flutter_local_notifications:19.5.0 timezone:^0.10.1
dart format lib/core/task_rules.dart lib/core/task_reminder_service.dart lib/features/agenda_screen.dart lib/features/notifications_screen.dart lib/core/app_controller.dart lib/app.dart lib/main.dart scripts/test_task_rules.dart
dart scripts/test_task_rules.dart
flutter analyze
```

The installer preflights and backs up changed files. It patches only specific controller/main/shell sections, preserves the existing saved schema, and installs receivers, permission, icon and resource retention for Android. It enables core-library desugaring with 2.1.4, and ensures a literal compileSdk is at least 35. A Flutter-provided compileSdk is retained. The native plugin requires Android Gradle Plugin 8.6+; modern Flutter projects normally meet this, and existing Gradle versions are otherwise preserved. iOS Swift AppDelegate receives the documented notification-center delegate setup. Objective-C AppDelegate projects require adapting that setup separately. No new database tables or secrets are required.

Plugin/API reference: https://pub.dev/packages/flutter_local_notifications/versions/19.5.0

## Verification and limits

CI runs pure deadline/read-key/reminder planning tests against the existing model snapshot. It also analyzes the feature files using Flutter and the actual notification plugin APIs, with explicitly named fixtures for the original app interfaces. Those fixtures do not test the real controller's authentication or persistence and are never installed into the app.

Installer tests cover repeat installation, controller/main/shell hooks, Android XML and both Gradle formats. The real project must pass flutter analyze and an Android build. Physical Android/iOS permission, scheduled delivery while closed, tapping, reboot and cancellation tests remain device tests. Neither static analysis nor a browser test establishes native delivery.

After installing, verify adding an exam/homework, editing its deadline, marking it done/undone, deleting/undo, filtering and reading reminders. Then on a phone enable notification permission and use Deneme bildirimi. Finally test a future task in the background and cancellation after completion/deletion/logout.
