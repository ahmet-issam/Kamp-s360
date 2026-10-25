import '../lib/core/models.dart';
import '../lib/core/schedule_rules.dart';

ClassSession course(String id, String start, String end,
    {int day = 1, String title = 'Matematik'}) => ClassSession(
  id: id, title: title, day: day, start: start, end: end,
  room: '', faculty: '', teacher: '', colorIndex: 0,
);

void check(bool result, String message) {
  if (!result) {
    throw StateError(message);
  }
}

void main() {
  final a = course('a', '09:00', '10:00');
  check(scheduleOverlaps(a, course('b', '09:30', '10:30')), 'Partial overlap');
  check(scheduleOverlaps(a, course('b', '08:00', '11:00')), 'Containing overlap');
  check(scheduleOverlaps(a, course('b', '09:00', '10:00')), 'Same interval');
  check(!scheduleOverlaps(a, course('b', '10:00', '11:00')), 'Adjacent courses');
  check(!scheduleOverlaps(a, course('b', '09:00', '10:00', day: 2)), 'Different days');
  check(!scheduleOverlaps(a, course('a', '09:00', '10:00')), 'Edit exclusion');
  check(scheduleMinutes('24:00') == null && scheduleMinutes('12:70') == null,
      'Reject invalid clock times');
  check(!scheduleOverlaps(a, course('b', 'invalid', '11:00')), 'Malformed imported time');
  final ordered = scheduleForDay([course('b', '10:00', '11:00'), a], 1);
  check(ordered.first.id == 'a', 'Chronological ordering');
  check(scheduleDuration([a, course('b', '10:00', '11:30')]) == 150, 'Minutes total');
  check(scheduleDuplicate(course('b', '9:00', '10:00', title: ' Matematik '), [a]),
      'Equivalent time and trimmed title');
  check(!scheduleDuplicate(a, [a]), 'Editing does not duplicate itself');
  print('Schedule rules: 12 checks passed.');
}
