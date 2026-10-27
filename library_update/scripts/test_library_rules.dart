// ignore_for_file: avoid_relative_lib_imports, avoid_print
import '../lib/core/library_rules.dart';
import '../lib/core/models.dart';
import '../lib/core/task_rules.dart';
void main() {
  var checks = 0;
  void check(bool value, String message) { if (!value) { throw StateError(message); } checks++; }
  StudentTask book(String id, {String title = 'İŞLETME', bool done = false, String hour = '16:00'}) => StudentTask(
    id: id, title: title, course: 'Kütüphane · Kitap iadesi', date: DateTime(2030, 5, 10),
    hour: hour, room: 'Kütüphane', isExam: false, done: done);
  final a = book('library_return_a');
  check(isLibraryReturn(a), 'Library record marker');
  check(!isLibraryReturn(book('ordinary')), 'Ordinary tasks excluded');
  check(librarySearchKey(' İŞLETME ') == 'işletme', 'Turkish case and whitespace');
  check(libraryReturnDuplicate(book('library_return_b', title: ' işletme '), [a]), 'Duplicate return');
  check(!libraryReturnDuplicate(a, [a]), 'Edit exclusion');
  check(!libraryReturnDuplicate(book('library_return_b'), [book('library_return_a', done: true)]), 'Returned books may be borrowed again');
  check(!libraryReturnDuplicate(book('library_return_b', hour: '17:00'), [a]), 'Different deadline');
  check(buildTaskNotices([a], DateTime.utc(2030, 5, 10)).single.title.contains('Kitap iadesi'), 'Library notice label');
  check(planTaskReminders([a], DateTime.utc(2030, 5, 8)).length == 3, 'Existing reminder plan used');
  check(planTaskReminders([book('library_return_a', done: true)], DateTime.utc(2030, 5, 8)).isEmpty, 'Returned books not scheduled');
  check(StudentTask.decodeList(StudentTask.encodeList([a])).single.id == a.id, 'Existing cloud schema round trip');
  print('Library rules: $checks checks passed.');
}
