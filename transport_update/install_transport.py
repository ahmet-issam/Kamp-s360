"""Run from the Flutter root. Changes only the bus screen and its connections."""
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
    home = root / 'lib/features/home_screen.dart'
    export = "export 'bus_screen.dart' show BusScreen;\n"
    text = extra.read_text(encoding='utf-8')
    start = text.find('class BusScreen extends ')
    end = text.find('class FavoritesScreen extends ', start)
    if start >= 0 and end > start:
        text = text[:start] + text[end:]
    elif export.strip() not in text:
        raise SystemExit('BusScreen layout differs. No files were changed.')
    if export.strip() not in text:
        text = export + text
    if 'openOfficialWebsite(' not in text and 'composeEmail(' not in text:
        text = text.replace("import '../core/official_links.dart';\n", '')
    home_text = home.read_text(encoding='utf-8')
    directive = "import 'bus_screen.dart';\n"
    if directive.strip() not in home_text:
        home_text = directive + home_text
    updates = [(extra, text), (home, home_text)]
    source = package / 'lib/features/bus_screen.dart'
    updates.append((root / 'lib/features/bus_screen.dart', source.read_text(encoding='utf-8')))
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
            shutil.copy2(path, path.with_name(path.name + '.backup_transport_' + stamp))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')
    print('APPLIED. Existing files backed up. Run flutter analyze.')


if __name__ == '__main__':
    main()
