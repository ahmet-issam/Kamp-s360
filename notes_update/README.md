# Notes update

Preserves the existing notes map keyed by course/topic and the AppController.setNote save/sync behavior. Adds title/body search, note filters, non-empty topic validation, Turkish topic matching, editor character count, save/discard/stay on navigation, delete confirmation and undo. A topic entered with equivalent Turkish case/spacing opens its existing note instead of replacing it. Saved notes updated while editing require explicit overwrite confirmation. Delete/undo also avoid overwriting a note updated during their interaction.

Normal in-app navigation is protected. Browser reload, process termination and device shutdown are not covered by the navigation dialog. There is no new autosave or draft store. Cloud persistence uses the existing app synchronization and must be verified in the real app.

Keep this update folder outside the Flutter project. From the Flutter project root run install_notes.py --apply, format the new files, run scripts/test_note_rules.dart and flutter analyze. The installer backs up existing files, exports the new notes screen through extra_screens.dart, and preserves the existing meals and transport exports. It does not modify saved notes, the controller or database schema. No new dependencies.

GitHub checks screen syntax and nine pure Dart rule cases. Full Flutter analysis and UI save/back/delete/undo/reopen/sync checks must run in the actual app project.
