import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

DateTime campusToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 3));
  return DateTime(now.year, now.month, now.day);
}

String mealDateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class CampusMeal {
  const CampusMeal(this.date, this.dishes);
  final DateTime date;
  final List<String> dishes;
}

class CafeteriaMenu {
  const CafeteriaMenu(this.items, this.checkedAt);
  final List<CampusMeal> items;
  final DateTime checkedAt;

  static CafeteriaMenu parse(String text) {
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (data['schema_version'] != 1 ||
        data['source_url'] != CafeteriaRepository.sourceUrl) {
      throw const FormatException('Invalid menu');
    }
    final checkedAt = DateTime.parse(data['checked_at'] as String).toUtc();
    final items = <CampusMeal>[];
    final seen = <String>{};
    for (final value in data['items'] as List) {
      final entry = value as Map<String, dynamic>;
      final key = entry['date'] as String;
      final day = DateTime.parse(key);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key) ||
          mealDateKey(day) != key || !seen.add(key)) {
        throw const FormatException('Invalid menu date');
      }
      final dishes = (entry['dishes'] as List)
          .map((value) => (value as String).trim()).toList();
      if (dishes.length < 2 || dishes.length > 8 ||
          dishes.any((value) => value.isEmpty || value.length > 300)) {
        throw const FormatException('Invalid dishes');
      }
      items.add(CampusMeal(day, List.unmodifiable(dishes)));
    }
    if (items.isEmpty || items.length > 400) {
      throw const FormatException('Empty menu');
    }
    items.sort((a, b) => a.date.compareTo(b.date));
    return CafeteriaMenu(List.unmodifiable(items), checkedAt);
  }
}

class CafeteriaRepository {
  static const sourceUrl = 'https://sks.bingol.edu.tr/yemek-listesi';
  static const _cacheKey = 'campus_official_meals_v1';
  static const _feedUrl =
      'https://raw.githubusercontent.com/ahmet-issam/Kamp-s360/main/data/meals.json';

  Future<CafeteriaMenu?> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      return raw == null ? null : CafeteriaMenu.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<CafeteriaMenu> refresh() async {
    final response = await http.get(Uri.parse(_feedUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 1000000) {
      throw const FormatException('Menu unavailable');
    }
    final raw = utf8.decode(response.bodyBytes);
    final menu = CafeteriaMenu.parse(raw);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, raw);
    } catch (_) {
      // A storage failure must not hide a successfully fetched menu.
    }
    return menu;
  }
}
