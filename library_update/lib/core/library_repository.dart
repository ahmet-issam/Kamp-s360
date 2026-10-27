import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const libraryHomeUrl = 'https://kutuphane.bingol.edu.tr/';
const libraryCatalogUrl = 'https://katalogtarama.bingol.edu.tr/yordam/';
const libraryHoursUrl = '${libraryHomeUrl}hakkimizda/calisma-saatleri/';
const libraryFaqUrl = '${libraryHomeUrl}hakkimizda/sss/';

bool isLibraryUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty &&
      !uri.hasPort && const {'kutuphane.bingol.edu.tr', 'katalogtarama.bingol.edu.tr'}.contains(uri.host);
}

class LibraryArticle {
  const LibraryArticle(this.title, this.url, this.body, this.publishedAt);
  final String title, url, body;
  final DateTime? publishedAt;
}

class LibraryFeed {
  const LibraryFeed({required this.news, required this.hours, required this.newsCheckedAt,
    required this.hoursCheckedAt, required this.newsStale, required this.hoursStale});
  final List<LibraryArticle> news;
  final String hours;
  final DateTime? newsCheckedAt, hoursCheckedAt;
  final bool newsStale, hoursStale;

  static LibraryFeed parse(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['schema_version'] != 1 || data['source_url'] != libraryHomeUrl) {
      throw const FormatException('Invalid library feed');
    }
    final sections = data['sections'] as Map<String, dynamic>;
    final news = sections['news'] as Map<String, dynamic>;
    final hours = sections['hours'] as Map<String, dynamic>;
    if (news['url'] != libraryHomeUrl || hours['url'] != libraryHoursUrl) {
      throw const FormatException('Invalid source');
    }
    final items = <LibraryArticle>[];
    final seen = <String>{};
    for (final item in news['data'] as List) {
      final row = item as Map<String, dynamic>;
      final title = row['title'] as String;
      final url = row['url'] as String;
      final body = row['body'] as String? ?? '';
      if (!isLibraryUrl(url) || title.isEmpty || title.length > 600 || body.length > 1600) {
        throw const FormatException('Invalid article');
      }
      if (seen.add(url)) {
        items.add(LibraryArticle(title, url, body, DateTime.tryParse(row['published_at'] as String? ?? '')));
      }
    }
    final text = hours['data'] as String;
    if (items.length > 60 || text.length > 3000) {
      throw const FormatException('Library feed too large');
    }
    DateTime? stamp(Map<String, dynamic> section) => DateTime.tryParse(section['checked_at'] as String? ?? '');
    bool stale(Map<String, dynamic> section) {
      final checked = stamp(section);
      return section['status'] != 'ok' || checked == null ||
          DateTime.now().toUtc().difference(checked.toUtc()) > const Duration(days: 2);
    }
    return LibraryFeed(news: List.unmodifiable(items), hours: text,
      newsCheckedAt: stamp(news), hoursCheckedAt: stamp(hours),
      newsStale: stale(news), hoursStale: stale(hours));
  }
}

class LibraryRepository {
  static const _key = 'campus_library_feed_v1';
  static const _url = 'https://raw.githubusercontent.com/ahmet-issam/Kamp-s360/main/data/library.json';
  Future<LibraryFeed?> cached() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      return raw == null ? null : LibraryFeed.parse(raw);
    } catch (_) { return null; }
  }
  Future<LibraryFeed> refresh() async {
    final response = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.length > 250000) {
      throw const FormatException('Library feed unavailable');
    }
    final raw = utf8.decode(response.bodyBytes);
    final feed = LibraryFeed.parse(raw);
    try { await (await SharedPreferences.getInstance()).setString(_key, raw); } catch (_) { /* Keep fetched data visible. */ }
    return feed;
  }
}

class LibraryResource {
  const LibraryResource(this.title, this.description, this.url);
  final String title, description, url;
}
const libraryResources = [
  LibraryResource('EKUAL veri tabanları', 'Makale, e-kitap ve bilimsel araştırma kaynakları. Erişim koşulları kaynağa göre değişir.', '${libraryHomeUrl}veri-tabanlari/ekual-veri-tabanlari/'),
  LibraryResource('Abone veri tabanları', 'Üniversitenin abonelikle sunduğu elektronik kaynaklar.', '${libraryHomeUrl}veri-tabanlari/abone-veri-tabanlari/'),
  LibraryResource('Deneme erişimli veri tabanları', 'Süreli denemeler. Son tarih ve üyelik koşullarını kaynak sayfasından kontrol edin.', '${libraryHomeUrl}veri-tabanlari/deneme-erisimli-veri-tabanlari/'),
  LibraryResource('Açık erişimli veri tabanları', 'Kütüphanenin yayımladığı açık erişim kaynak rehberi.', '${libraryHomeUrl}veri-tabanlari/acik-erisimli-veri-tabanlari/'),
  LibraryResource('Kampüs dışı erişim', 'VPN, vekil sunucu ve YETKİM üzerinden erişim açıklamaları. Kurum hesabı gerekebilir.', '${libraryHomeUrl}kampus-disi-erisim/veri-tabanlarina-kampus-disi-erisim-vpn-ayarlari/'),
];
