import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_flutter_check/core/library_repository.dart';
import 'package:task_flutter_check/core/app_controller.dart';
import 'package:task_flutter_check/features/library_screen.dart';

void main() {
  Map<String, Object?> feed() => {
    'schema_version': 1, 'source_url': libraryHomeUrl,
    'sections': {
      'hours': {'url': libraryHoursUrl, 'status': 'ok', 'checked_at': DateTime.now().toUtc().toIso8601String(), 'data': 'HAFTA İÇİ 08.00 / 21.00'},
      'news': {'url': libraryHomeUrl, 'status': 'ok', 'checked_at': DateTime.now().toUtc().toIso8601String(), 'data': [
        {'title': 'Duyuru', 'url': '${libraryHomeUrl}duyurular/test/', 'body': 'Açıklama', 'published_at': '2026-10-27T00:00:00+03:00'}
      ]},
    },
  };
  test('Source parser accepts real schema and rejects hostile article URLs', () {
    final parsed = LibraryFeed.parse(jsonEncode(feed()));
    expect(parsed.news.single.title, 'Duyuru');
    expect(parsed.hoursStale, false);
    expect(isLibraryUrl('https://kutuphane.bingol.edu.tr.evil.com/'), false);
    expect(isLibraryUrl('javascript:alert(1)'), false);
    expect(isLibraryUrl('https://user@kutuphane.bingol.edu.tr/'), false);
    final bad = jsonDecode(jsonEncode(feed())) as Map<String, dynamic>;
    bad['sections']['news']['data'][0]['url'] = 'https://evil.com/';
    expect(() => LibraryFeed.parse(jsonEncode(bad)), throwsFormatException);
  });
  test('Old successful source remains visibly stale', () {
    final old = jsonDecode(jsonEncode(feed())) as Map<String, dynamic>;
    old['sections']['hours']['checked_at'] = '2000-01-01T00:00:00Z';
    expect(LibraryFeed.parse(jsonEncode(old)).hoursStale, true);
  });
  testWidgets('Return form validates, creates account task, and completion removes pending state', (tester) async {
    final app = AppController();
    await tester.pumpWidget(AppScope(controller: app, child: const MaterialApp(home: Scaffold(body: LibraryReturnsView()))));
    await tester.tap(find.text('İade hatırlatması ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('Kitap adını yazın.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Algoritmalar');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(app.tasks.single.title, 'Algoritmalar');
    expect(app.tasks.single.id.startsWith('library_return_'), true);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(app.tasks.single.done, true);
    expect(find.textContaining('İade edildi'), findsOneWidget);
  });
}
