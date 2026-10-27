import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from collect_library import build, parse_news, parse_hours, safe_url, HOME
from importlib.util import spec_from_file_location, module_from_spec
spec = spec_from_file_location('install_library', Path(__file__).resolve().parents[1] / 'library_update/install_library.py')
installer = module_from_spec(spec)
spec.loader.exec_module(installer)

HOURS = '<div class="sade"><p>EĞİTİM DÖNEMİ</p><table><tr><td>HAFTA İÇİ</td><td>08.00 / 21.00</td></tr></table></div>'
NEWS = '<a href="/duyurular/ornek/"><div class="media_w-heading">Örnek duyuru</div><p>27 Ekim 2026 Salı</p></a>'
class LibraryTests(unittest.TestCase):
    def test_source_validation(self):
        self.assertTrue(safe_url(HOME))
        for value in ['http://kutuphane.bingol.edu.tr/', 'https://kutuphane.bingol.edu.tr.evil.com/', 'https://evil.com/', 'https://user@kutuphane.bingol.edu.tr/']:
            self.assertFalse(safe_url(value))
    def test_news_dates_and_dedup(self):
        items = parse_news(NEWS + NEWS)
        self.assertEqual(len(items), 1)
        self.assertTrue(items[0]['published_at'].startswith('2026-10-27'))
    def test_no_navigation_as_news(self):
        with self.assertRaises(ValueError): parse_news('<a href="/duyurular/">Tüm duyurular</a>')
    def test_hours_scope(self):
        self.assertIn('08.00 / 21.00', parse_hours(HOURS))
        with self.assertRaises(ValueError): parse_hours('<p>Menu 08:00</p>')
    def test_partial_retains_previous_success_timestamp(self):
        old = {'sections': {'news': {'url': HOME, 'checked_at': '2026-01-01T00:00:00Z', 'data': [{'title': 'old'}], 'status': 'ok'}}}
        def fetch(url):
            if url == HOME: raise OSError('down')
            return HOURS
        feed, count = build(old, fetch, '2026-10-27T12:00:00Z')
        self.assertEqual(count, 1)
        self.assertEqual(feed['sections']['news']['checked_at'], '2026-01-01T00:00:00Z')
        self.assertEqual(feed['sections']['news']['status'], 'stale')
        self.assertEqual(feed['sections']['hours']['status'], 'ok')
    def test_installer_idempotence(self):
        home = "import '../data/demo_data.dart';\n_Shortcut('Kütüphane', Icons.local_library_outlined, () => openScreen(context, PlaceDetailScreen(place: campusPlaces[1]))),"
        result = installer.patch_home(home)
        self.assertIn('const LibraryScreen()', result)
        self.assertNotIn('demo_data.dart', result)
        self.assertEqual(installer.patch_home(result), result)
        source = "final kind = task.isExam ? 'Sınav' : 'Ödev';"
        self.assertEqual(installer.patch_rules(installer.patch_rules(source)), installer.patch_rules(source))
        service = "'${task.isExam ? 'Sınav' : 'Ödev'} · $title'"
        self.assertEqual(installer.patch_service(installer.patch_service(service)), installer.patch_service(service))
    def test_unknown_layout_stops(self):
        with self.assertRaises(ValueError): installer.patch_home('different home')

if __name__ == '__main__': unittest.main()
