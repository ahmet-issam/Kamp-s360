// ignore_for_file: avoid_relative_lib_imports, avoid_print
import '../lib/core/note_rules.dart';

void check(bool result, String name) {
  if (!result) {
    throw StateError(name);
  }
}

void main() {
  check(noteMatches('Matematik', 'Türev konusu', 'matematik'), 'Title search');
  check(noteMatches('Matematik', 'Türev konusu', 'türev'), 'Body search');
  check(!noteMatches('Matematik', 'Türev konusu', 'fizik'), 'No match');
  check(noteMatches('Fizik', '', '  '), 'Empty search');
  check(noteMatches('İLETİŞİM', '', 'iletişim'), 'Turkish dotted I');
  check(noteMatches('ISINMA', '', 'ısınma'), 'Turkish dotless I');
  check(noteTopic('  Matematik  ', ['Matematik']) == 'Matematik', 'Existing topic');
  check(noteTopic('VERİ   YAPILARI', ['Veri Yapıları']) == 'Veri Yapıları', 'Canonical topic without overwrite');
  check(noteTopic('  Yeni   konu ', ['Matematik']) == 'Yeni konu', 'New topic spacing');
  print('Note rules: 9 checks passed.');
}
