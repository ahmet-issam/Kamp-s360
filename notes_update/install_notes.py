"""Install notes UI while preserving current meals, transport and stored notes."""
import argparse
from datetime import datetime
from pathlib import Path
import shutil


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--apply', action='store_true')
    args = ap.parse_args()
    root = Path.cwd()
    package = Path(__file__).resolve().parent
    if not (root / 'pubspec.yaml').exists():
        raise SystemExit('Run from your Flutter project root.')
    extra = root / 'lib/features/extra_screens.dart'
    original = extra.read_text(encoding='utf-8')
    text = original
    directive = "export 'notes_screen.dart' show NotesScreen, EditNoteScreen;\n"
    start = text.find('class NotesScreen extends ')
    if start >= 0:
        candidates = [text.find(marker, start) for marker in [
            'class CafeteriaScreen extends ', 'class BusScreen extends ',
            'class FavoritesScreen extends ']]
        ends = [position for position in candidates if position > start]
        if not ends or 'class _EditNoteScreenState extends ' not in text[start:min(ends)]:
            raise SystemExit('Notes layout differs. No files were changed.')
        text = text[:start] + text[min(ends):]
    elif directive.strip() not in text:
        raise SystemExit('NotesScreen was not found. No files were changed.')
    if directive.strip() not in text:
        text = directive + text
    updates = [(extra, text)]
    # Preflight every source before any project writes.
    for relative in ['lib/features/notes_screen.dart', 'lib/core/note_rules.dart',
                     'scripts/test_note_rules.dart']:
        updates.append((root / relative, (package / relative).read_text(encoding='utf-8')))
    updates = [(p, s) for p, s in updates if not p.exists() or p.read_text(encoding='utf-8') != s]
    print('Files to update:', len(updates))
    for path, _ in updates:
        print(path.relative_to(root))
    if not args.apply:
        print('Preview only. Add --apply to install.')
        return
    stamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    for path, content in updates:
        if path.exists():
            shutil.copy2(path, path.with_name(path.name + '.backup_notes_' + stamp))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')
    print('APPLIED. Existing files backed up. Stored notes were not modified.')


if __name__ == '__main__':
    main()
