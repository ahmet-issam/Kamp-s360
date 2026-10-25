import unittest
from scripts.collect_meals import parse_menu


class MealTests(unittest.TestCase):
    def test_rows_entities_blank_days_and_order(self):
        html = '<table><tr><td>02.11.2026</td><td><p>Çorba</p></td><td>Et &amp; pilav</td></tr><tr><td>&nbsp;</td><td></td></tr><tr><td>01.11.2026</td><td>A</td><td>B</td></tr></table>'
        items = parse_menu(html)
        self.assertEqual([v['date'] for v in items], ['2026-11-01', '2026-11-02'])
        self.assertEqual(items[1]['dishes'], ['Çorba', 'Et & pilav'])

    def test_empty_page_fails(self):
        with self.assertRaises(ValueError):
            parse_menu('<p>Maintenance</p>')

    def test_invalid_date_fails(self):
        with self.assertRaises(ValueError):
            parse_menu('<tr><td>31.02.2026</td><td>A</td><td>B</td></tr>')

    def test_incomplete_row_fails(self):
        with self.assertRaises(ValueError):
            parse_menu('<tr><td>01.11.2026</td><td>A</td></tr>')

    def test_conflicting_duplicates_fail(self):
        with self.assertRaises(ValueError):
            parse_menu('<tr><td>01.11.2026</td><td>A</td><td>B</td></tr><tr><td>01.11.2026</td><td>C</td><td>D</td></tr>')
