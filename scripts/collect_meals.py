"""Collect the official monthly menu without replacing data on failures."""
import argparse
from datetime import date, datetime, timezone
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.request import Request, urlopen

SOURCE = 'https://sks.bingol.edu.tr/yemek-listesi'


class MenuParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag == 'tr':
            self.row = []
        elif tag in ('td', 'th') and self.row is not None:
            self.cell = []
        elif tag in ('br', 'p') and self.cell is not None:
            self.cell.append(' ')

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            self.row.append(' '.join(''.join(self.cell).split()))
            self.cell = None
        elif tag == 'tr' and self.row is not None:
            self.rows.append(self.row)
            self.row = None
            self.cell = None


def parse_menu(html):
    parser = MenuParser()
    parser.feed(html)
    items = {}
    for row in parser.rows:
        if not row or not re.fullmatch(r'\d{1,2}\.\d{1,2}\.20\d{2}', row[0]):
            continue
        day = datetime.strptime(row[0], '%d.%m.%Y').date().isoformat()
        dishes = [v for v in row[1:] if v]
        if len(dishes) < 2 or len(dishes) > 8 or any(len(v) > 300 for v in dishes):
            raise ValueError('Incomplete menu row: ' + day)
        entry = {'date': day, 'dishes': dishes}
        if day in items and items[day] != entry:
            raise ValueError('Conflicting menu rows: ' + day)
        items[day] = entry
    if not items:
        raise ValueError('No dated menu rows. Existing menu was not changed.')
    return sorted(items.values(), key=lambda item: item['date'])


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, default=Path('data/meals.json'))
    ap.add_argument('--input', type=Path, help='Parse a saved HTML file for verification')
    args = ap.parse_args()
    if args.input:
        html = args.input.read_text(encoding='utf-8')
    else:
        req = Request(SOURCE, headers={'User-Agent': 'Mozilla/5.0', 'Accept': 'text/html'})
        with urlopen(req, timeout=30) as response:
            if response.url.rstrip('/') != SOURCE or 'text/html' not in response.headers.get('Content-Type', ''):
                raise ValueError('Unexpected menu response')
            raw = response.read(3_000_001)
            if len(raw) > 3_000_000:
                raise ValueError('Menu response too large')
            html = raw.decode(response.headers.get_content_charset() or 'utf-8')
    items = parse_menu(html)
    payload = {'schema_version': 1, 'source_url': SOURCE,
               'checked_at': datetime.now(timezone.utc).isoformat(), 'items': items}
    # Commit unchanged menus once per UTC day, preserving a recent verification time.
    if args.output.exists():
        previous = json.loads(args.output.read_text(encoding='utf-8'))
        if previous.get('items') == items and previous.get('checked_at', '')[:10] == date.today().isoformat():
            print('Menu unchanged; already checked today.')
            return
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix('.tmp')
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(args.output)
    print(f'MENU READY: {len(items)} days, {items[0]["date"]} to {items[-1]["date"]}')


if __name__ == '__main__':
    main()
