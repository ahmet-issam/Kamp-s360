#!/usr/bin/env python3
"""Collect public library information, retaining last successful sections on failure."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from html import unescape
import json
from pathlib import Path
import re
from urllib.request import Request, urlopen
from urllib.parse import urljoin, urlsplit
from collect_news import ArticleContent, date_value, href, plain

HOME = 'https://kutuphane.bingol.edu.tr/'
HOURS = HOME + 'hakkimizda/calisma-saatleri/'

def safe_url(url):
    u = urlsplit(url)
    return (u.scheme == 'https' and u.hostname == 'kutuphane.bingol.edu.tr'
            and not u.username and not u.password and u.port is None)

def fetch(url):
    if not safe_url(url):
        raise ValueError('Untrusted library URL')
    request = Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Accept': 'text/html'})
    with urlopen(request, timeout=20) as response:
        if not safe_url(response.url) or response.status != 200:
            raise ValueError('Unexpected library response')
        if 'text/html' not in response.headers.get('Content-Type', '').lower():
            raise ValueError('Expected HTML')
        raw = response.read(3_000_001)
        if len(raw) > 3_000_000:
            raise ValueError('Library page too large')
        return raw.decode(response.headers.get_content_charset() or 'utf-8', errors='replace')

def body(html, url):
    parser = ArticleContent(url)
    parser.feed(html)
    text = '\n'.join(' '.join(line.split()) for line in ''.join(parser.parts).splitlines() if line.strip())
    if len(text) < 30:
        raise ValueError('Library content layout changed')
    return text

def parse_news(html):
    items = {}
    for attrs, content in re.findall(r'<a\b([^>]*)>([\s\S]*?)</a>', html, re.I):
        link = href(attrs)
        if not link:
            continue
        url = urljoin(HOME, unescape(link))
        if not safe_url(url) or not urlsplit(url).path.startswith('/duyurular/'):
            continue
        title = re.search(r'<(?:div|h[234])\b[^>]*class=["\'][^"\']*media_w-heading[^"\']*["\'][^>]*>([\s\S]*?)</(?:div|h[234])>', content, re.I)
        if not title:
            continue
        date = re.search(r'<p\b[^>]*>([\s\S]*?)</p>', content, re.I)
        label = plain(title[1])
        if 4 <= len(label) <= 600:
            items.setdefault(url, {'title': label, 'url': url, 'published_at': date_value(date[1] if date else ''), 'body': ''})
    if not items:
        raise ValueError('No library announcements')
    return list(items.values())[:20]

def enrich(item):
    try:
        parser = ArticleContent(item['url'])
        parser.feed(fetch(item['url']))
        return dict(item, body=parser.result()['body'])
    except Exception:
        return item

def parse_hours(html):
    text = body(html, HOURS)
    # Do not derive "open now": exam periods, holidays and linked older notices
    # can differ. Display the source's published schedule with provenance.
    if not re.search(r'\b\d{2}[.:]\d{2}\b', text) or 'HAFTA' not in text.upper():
        raise ValueError('No published schedule')
    if len(text) > 3000:
        raise ValueError('Unexpected schedule size')
    return text

def build(previous, fetcher=fetch, now=None):
    result = {'schema_version': 1, 'source_url': HOME, 'sections': dict(previous.get('sections', {}))}
    checked = now or datetime.now(timezone.utc).isoformat()
    succeeded = 0
    for name, url, parser in [('hours', HOURS, parse_hours), ('news', HOME, parse_news)]:
        try:
            data = parser(fetcher(url))
            if name == 'news' and fetcher is fetch:
                with ThreadPoolExecutor(max_workers=4) as pool:
                    data = list(pool.map(enrich, data))
            result['sections'][name] = {'url': url, 'checked_at': checked, 'status': 'ok', 'data': data}
            succeeded += 1
        except Exception as error:
            retained = dict(result['sections'].get(name, {'url': url, 'checked_at': None, 'data': [] if name == 'news' else ''}))
            retained.update(status='stale' if retained.get('checked_at') else 'unavailable', error=type(error).__name__)
            result['sections'][name] = retained
    return result, succeeded

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('data/library.json'))
    args = parser.parse_args()
    old = json.loads(args.output.read_text(encoding='utf-8')) if args.output.exists() else {}
    result, count = build(old)
    if count == 0:
        raise SystemExit('No successful source. Existing file retained.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix('.tmp')
    temporary.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(args.output)
    print('Library sections refreshed:', count)
    print('Announcements:', len(result['sections']['news']['data']))

if __name__ == '__main__':
    main()
