import unittest
from scripts.collect_news import ArticleContent, SOURCES, date_value, official_url, parse_items


class NewsTests(unittest.TestCase):
    def test_official_urls(self):
        base = 'https://oidb.bingol.edu.tr/duyurular/'
        self.assertEqual(official_url('/duyuru/test/#top', base), 'https://oidb.bingol.edu.tr/duyuru/test')
        for link in ['https://bingol.edu.tr.example.com/a', 'javascript:alert(1)', 'https://user:pass@bingol.edu.tr/a']:
            self.assertIsNone(official_url(link, base))

    def test_turkish_dates(self):
        self.assertEqual(date_value('25 Ekim 2026'), '2026-10-25T00:00:00+03:00')
        self.assertEqual(date_value('25.10.2026'), '2026-10-25T00:00:00+03:00')
        self.assertIsNone(date_value('31.02.2026'))

    def test_university_rows_deduplicate(self):
        row = '<tr id="feed_DXDataRow0"><td><a href="/duyuru/test">Test duyurusu</a></td><td>25.10.2026</td></tr>'
        items = parse_items(row + row, SOURCES[0])
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]['title'], 'Test duyurusu')

    def test_student_cards(self):
        html = '<a href="/duyuru/test"><h3 class="media_w-heading">Test duyurusu</h3><p>25 Ekim 2026</p></a>'
        items = parse_items(html, SOURCES[1])
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]['source'], 'student_affairs')

    def test_body_and_attachment_exclude_navigation(self):
        parser = ArticleContent('https://oidb.bingol.edu.tr/duyuru/test')
        parser.feed('<nav>Navigation</nav><div class="sayfa-icerik"><p>Duyuru metni</p><script>hidden()</script><a href="/belge.pdf">Başvuru formu</a><img src="image.png"></div><footer>Footer</footer>')
        result = parser.result()
        self.assertIn('Duyuru metni', result['body'])
        for excluded in ['Navigation', 'hidden()', 'Footer']:
            self.assertNotIn(excluded, result['body'])
        self.assertEqual(result['links'], [{'url': 'https://oidb.bingol.edu.tr/belge.pdf', 'label': 'Başvuru formu'}])
        self.assertTrue(result['contains_images'])


if __name__ == '__main__':
    unittest.main()
