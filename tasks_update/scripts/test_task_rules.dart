// ignore_for_file: avoid_relative_lib_imports, avoid_print
import '../lib/core/models.dart';
import '../lib/core/task_rules.dart';

int checks = 0;
void check(bool condition, String name) {
  if (!condition) { throw StateError(name); }
  checks++;
}
StudentTask task(String id, {int day = 25, String hour = '09:00',
  bool done = false, bool exam = true, String title = 'Vize'}) => StudentTask(
    id: id, title: title, course: 'Matematik', date: DateTime(2026, 10, day),
    hour: hour, room: 'A101', isExam: exam, done: done, description: 'Türev',
  );
void main() {
  final now = DateTime.utc(2026, 10, 25, 6, 30);
  final late = task('a');
  final upcoming = task('b', hour: '10:00');
  check(taskDeadline(late) == DateTime.utc(2026, 10, 25, 6), 'Turkey UTC offset');
  check(taskIsOverdue(late, now), 'Same-day past hour is overdue');
  check(!taskIsOverdue(upcoming, now), 'Later hour is upcoming');
  check(!taskIsOverdue(task('c', done: true), now), 'Done is not overdue');
  check(taskDeadline(task('x', hour: '24:00')) == null, 'Reject invalid hour');
  check(taskDeadline(task('x', hour: '09:70')) == null, 'Reject invalid minute');
  check(taskDeadline(task('x', hour: 'bad')) == null, 'Reject malformed time');
  final notices = buildTaskNotices([upcoming, late, task('c', done: true)], now);
  check(notices.length == 2, 'Exclude completed tasks');
  check(notices.first.title.startsWith('Süresi geçen'), 'Overdue notice');
  check(notices.last.title.startsWith('Bugünkü'), 'Today notice');
  check(taskIdFromNotice(notices.first.id) == 'a', 'Task deep link roundtrip');
  check(taskIdFromNotice('task_v2_invalid') == null, 'Malformed notice ID');
  check(taskNoticeKey(task('b', hour: '11:00'), now) != taskNoticeKey(upcoming, now), 'Edited time becomes unread');
  check(taskNoticeKey(upcoming, now) != taskNoticeKey(upcoming, now.add(const Duration(hours: 2))), 'Overdue phase becomes unread');
  check(buildTaskNotices([task('x', day: 26)], DateTime.utc(2026, 10, 25, 22)).first.title.startsWith('Bugünkü'), 'Turkish midnight boundary');
  check(buildTaskNotices([task('x', day: 33)], now).isEmpty, 'Beyond seven-day window excluded');
  check(buildTaskNotices([task('x', day: 32, hour: '23:59')], now).length == 1, 'Seven-day end included');
  final ordered = [task('a', hour: '11:00'), upcoming]..sort(compareTasks);
  check(ordered.first.id == 'b', 'Date plus hour ordering');
  check(taskMatches(late, 'türev'), 'Search description');
  check(duplicateTask(task('other'), [late]), 'Prevent duplicates');
  check(!duplicateTask(late, [late]), 'Edit excludes itself');
  check(!duplicateTask(task('other', exam: false), [late]), 'Exam and homework distinct');
  final tomorrow = task('future', day: 27);
  final planned = planTaskReminders([tomorrow], now);
  check(planned.length == 3, 'Three planned reminders');
  check(planned.first.leadMinutes == 1440 && planned.last.leadMinutes == 0, 'Reminder order');
  check(planTaskReminders([late, task('c', done: true)], now).isEmpty, 'No late or completed reminders');
  check(planTaskReminders([tomorrow], now, limit: 2).length == 2, 'OS queue cap');
  check(StudentTask.fromMap(tomorrow.toMap()).hour == tomorrow.hour, 'Existing data schema roundtrip');
  print('Task rules: $checks checks passed.');
}
