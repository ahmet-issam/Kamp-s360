# Weekly schedule update

Preserves the existing `ClassSession` schema and `AppController` save/sync flow. Adds time overlap detection (with an option to keep a conflict), duplicate prevention, chronological weekly sorting, total scheduled minutes, Today navigation, visible conflicts and deletion undo. Adjacent classes do not overlap. Editing excludes the course's own ID. Malformed imported clock values do not crash the editor.

Place this update folder outside the Flutter project. From the project root run:

```powershell
python PATH_TO_UPDATE/install_schedule.py --apply
dart format lib/features/schedule_screen.dart lib/core/schedule_rules.dart scripts/test_schedule_rules.dart
dart scripts/test_schedule_rules.dart
flutter analyze
```

The installer backs up files before replacing them. It does not replace the controller, model, stored courses or database schema. No new dependencies are required.

GitHub CI checks Dart syntax and 12 rule cases against a snapshot of the original ClassSession model. It does not compile the full Flutter application because this repository does not contain that application. Run the supplied test script in the real app to validate against its actual model and run Flutter analyze there. Verify add/edit/delete/undo, sync after reopening, and conflict confirmation in the app.
