"""Install schedule improvements without changing saved courses or the controller."""
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
    paths = ['lib/features/schedule_screen.dart', 'lib/core/schedule_rules.dart',
             'scripts/test_schedule_rules.dart']
    updates = []
    # Read every input before changing any project file.
    for relative in paths:
        content = (package / relative).read_text(encoding='utf-8')
        target = root / relative
        if not target.exists() or target.read_text(encoding='utf-8') != content:
            updates.append((target, content))
    print('Files to update:', len(updates))
    for target, _ in updates:
        print(target.relative_to(root))
    if not args.apply:
        print('Preview only. Add --apply to install.')
        return
    stamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    for target, content in updates:
        if target.exists():
            shutil.copy2(target, target.with_name(target.name + '.backup_schedule_' + stamp))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding='utf-8')
    print('APPLIED. Existing files backed up. Saved courses were not modified.')


if __name__ == '__main__':
    main()
