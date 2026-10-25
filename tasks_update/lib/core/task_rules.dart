import 'dart:convert';
import 'models.dart';

DateTime? taskDeadline(StudentTask task) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(task.hour);
  if (match == null) {
    return null;
  }
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) {
    return null;
  }
  // University appointments use Turkish wall time, independent of device zone.
  return DateTime.utc(task.date.year, task.date.month, task.date.day, hour, minute)
      .subtract(const Duration(hours: 3));
}

DateTime taskTurkeyNow(DateTime now) => now.toUtc().add(const Duration(hours: 3));

bool taskIsOverdue(StudentTask task, DateTime now) {
  final deadline = taskDeadline(task);
  return !task.done && deadline != null && deadline.isBefore(now.toUtc());
}

int compareTasks(StudentTask a, StudentTask b) {
  if (a.done != b.done) {
    return a.done ? 1 : -1;
  }
  final result = (taskDeadline(a) ?? DateTime.utc(9999))
      .compareTo(taskDeadline(b) ?? DateTime.utc(9999));
  return result == 0 ? a.title.compareTo(b.title) : result;
}

String _taskPhase(StudentTask task, DateTime now) {
  if (taskIsOverdue(task, now)) {
    return 'late';
  }
  final today = taskTurkeyNow(now);
  return task.date.year == today.year && task.date.month == today.month &&
      task.date.day == today.day ? 'today' : 'soon';
}

String taskNoticeKey(StudentTask task, DateTime now) => 'task_v2_${base64Url.encode(
  utf8.encode(jsonEncode([task.id, taskDeadline(task)?.toIso8601String(),
    task.title, task.course, task.room, task.isExam, _taskPhase(task, now)])),
)}';

String? taskIdFromNotice(String noticeId) {
  if (!noticeId.startsWith('task_v2_')) {
    return null;
  }
  try {
    final value = jsonDecode(utf8.decode(base64Url.decode(noticeId.substring(8)))) as List;
    return value.isNotEmpty && value.first is String ? value.first as String : null;
  } catch (_) {
    return null;
  }
}

List<CampusNotice> buildTaskNotices(List<StudentTask> tasks, DateTime now) {
  final today = taskTurkeyNow(now);
  final horizon = DateTime.utc(today.year, today.month, today.day + 8)
      .subtract(const Duration(hours: 3));
  final selected = tasks.where((task) {
    final deadline = taskDeadline(task);
    return !task.done && deadline != null && deadline.isBefore(horizon);
  }).toList()..sort(compareTasks);
  return selected.map((task) {
    final phase = _taskPhase(task, now);
    final kind = task.isExam ? 'Sınav' : 'Ödev';
    final title = phase == 'late' ? 'Süresi geçen $kind'
        : phase == 'today' ? 'Bugünkü $kind' : 'Yaklaşan $kind';
    return CampusNotice(
      id: taskNoticeKey(task, now), title: title,
      body: '${task.title} · ${task.course}\n'
          '${task.date.day}.${task.date.month}.${task.date.year} · ${task.hour}'
          '${task.room.isEmpty ? '' : '\n${task.room}'}',
      category: 'Dersler', createdAt: taskDeadline(task)!,
    );
  }).toList();
}

bool taskMatches(StudentTask task, String query) {
  String clean(String value) => value.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();
  final needle = clean(query);
  return needle.isEmpty || [task.title, task.course, task.description, task.room]
      .any((value) => clean(value).contains(needle));
}

bool duplicateTask(StudentTask candidate, Iterable<StudentTask> tasks) => tasks.any(
  (task) => task.id != candidate.id && task.isExam == candidate.isExam &&
      task.title.trim().toLowerCase() == candidate.title.trim().toLowerCase() &&
      task.course.trim().toLowerCase() == candidate.course.trim().toLowerCase() &&
      taskDeadline(task) == taskDeadline(candidate),
);

class PlannedTaskReminder {
  const PlannedTaskReminder(this.task, this.at, this.leadMinutes);
  final StudentTask task;
  final DateTime at;
  final int leadMinutes;
}

List<PlannedTaskReminder> planTaskReminders(List<StudentTask> tasks, DateTime now,
    {int limit = 60}) {
  final reminders = <PlannedTaskReminder>[];
  for (final task in tasks) {
    final due = taskDeadline(task);
    if (task.done || due == null || !due.isAfter(now.toUtc())) {
      continue;
    }
    for (final lead in [1440, 60, 0]) {
      final at = due.subtract(Duration(minutes: lead));
      if (at.isAfter(now.toUtc())) {
        reminders.add(PlannedTaskReminder(task, at, lead));
      }
    }
  }
  reminders.sort((a, b) {
    final result = a.at.compareTo(b.at);
    return result == 0 ? a.task.id.compareTo(b.task.id) : result;
  });
  return reminders.take(limit < 0 ? 0 : limit).toList();
}
