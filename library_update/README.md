# Kampüs360 library update

Adds a Turkish library hub with public announcements and source excerpts, published hours, searchable resource categories, borrowing guidance, contact/map links, and manually entered return reminders.

Return records use existing StudentTask storage and sync, with IDs prefixed `library_return_`. They also appear in the agenda's homework/task list. Existing reminder permission, profile preference, cancellation and account isolation apply. No new credentials or backend schema are required. Returning a book must be confirmed in the actual university system; checking the box only completes the personal reminder.

Catalogue search and account/renewal actions open the official Yordam service externally. No Yordam API or single sign-on integration is claimed. Electronic resources open official source directories; access rights depend on the university and provider.

Run installer from the Flutter project's root, with the package outside the project:

```powershell
python PATH\install_library.py --apply
dart format lib/features/library_screen.dart lib/core/library_repository.dart lib/core/library_rules.dart lib/features/home_screen.dart lib/core/task_rules.dart lib/core/task_reminder_service.dart scripts/test_library_rules.dart
dart scripts/test_library_rules.dart
flutter analyze
```

Requires the previously installed tasks update and existing http, shared_preferences and url_launcher dependencies. No changes to Android signing or package ID. Full restart required after installing.

Public feed: data/library.json. The Python collector refreshes public sources every six hours using GitHub Actions. Each section keeps its last successful timestamp and data on partial failure; all-source failure leaves the old file unchanged. The app caches the feed and marks data older than two days as potentially stale. It never derives an unverified live open/closed status.

Sources: https://kutuphane.bingol.edu.tr/, https://kutuphane.bingol.edu.tr/hakkimizda/calisma-saatleri/, https://kutuphane.bingol.edu.tr/hakkimizda/sss/. Curated guide checked 27 October 2026. Native catalogue, library account and resource provider services remain separate from Kampüs360.

Validation: Python collector/installer tests, pure Dart return/reminder tests, and real Flutter analysis/widget tests using explicit controller fixtures in CI. Fixtures do not replace testing account persistence and the installed app on a phone.
