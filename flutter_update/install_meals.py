"""Install from the Flutter project root. Preview by default; --apply writes backups."""
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
        raise SystemExit('Run this script from your Flutter project root.')
    extra = root / 'lib/features/extra_screens.dart'
    text = extra.read_text(encoding='utf-8')
    directive = "export 'cafeteria_screen.dart' show CafeteriaScreen;\n"
    start = text.find('class CafeteriaScreen extends ')
    end = text.find('class BusScreen extends ', start)
    if start >= 0 and end > start:
        text = text[:start] + text[end:]
    elif directive.strip() not in text:
        raise SystemExit('CafeteriaScreen layout differs. No files were changed.')
    if directive.strip() not in text:
        text = directive + text
    updates = [(extra, text)]
    for source in (package / 'lib').rglob('*.dart'):
        updates.append((root / source.relative_to(package), source.read_text(encoding='utf-8')))
    updates = [(p, s) for p, s in updates if not p.exists() or p.read_text(encoding='utf-8') != s]
    print('Files to update:', len(updates))
    for dest, _ in updates:
        print(dest.relative_to(root))
    if not args.apply:
        print('Preview only. Add --apply to install.')
        return
    stamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    for dest, content in updates:
        if dest.exists():
            shutil.copy2(dest, dest.with_name(dest.name + '.backup_meals_' + stamp))
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding='utf-8')
    print('APPLIED. Backups created for changed existing files.')
    print('NEXT: flutter pub add http')
    print('NEXT: dart format lib/core/cafeteria_repository.dart lib/features/cafeteria_screen.dart')
    print('NEXT: flutter analyze')


if __name__ == '__main__':
    main()
