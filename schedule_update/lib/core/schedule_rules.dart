import 'models.dart';

int? scheduleMinutes(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
  if (match == null) {
    return null;
  }
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}

bool scheduleOverlaps(ClassSession a, ClassSession b) {
  if (a.id == b.id || a.day != b.day) {
    return false;
  }
  final aStart = scheduleMinutes(a.start);
  final aEnd = scheduleMinutes(a.end);
  final bStart = scheduleMinutes(b.start);
  final bEnd = scheduleMinutes(b.end);
  if (aStart == null || aEnd == null || bStart == null || bEnd == null ||
      aEnd <= aStart || bEnd <= bStart) {
    return false;
  }
  return aStart < bEnd && bStart < aEnd;
}

List<ClassSession> scheduleForDay(Iterable<ClassSession> items, int day) {
  final result = items.where((item) => item.day == day).toList();
  result.sort((a, b) {
    final start = (scheduleMinutes(a.start) ?? 1440)
        .compareTo(scheduleMinutes(b.start) ?? 1440);
    if (start != 0) {
      return start;
    }
    final end = (scheduleMinutes(a.end) ?? 1440)
        .compareTo(scheduleMinutes(b.end) ?? 1440);
    return end != 0 ? end : a.title.compareTo(b.title);
  });
  return result;
}

int scheduleDuration(Iterable<ClassSession> items) {
  var total = 0;
  for (final item in items) {
    final start = scheduleMinutes(item.start);
    final end = scheduleMinutes(item.end);
    if (start != null && end != null && end > start) {
      total += end - start;
    }
  }
  return total;
}

bool scheduleDuplicate(ClassSession candidate, Iterable<ClassSession> items) {
  String normalized(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  return items.any((item) => item.id != candidate.id && item.day == candidate.day &&
      scheduleMinutes(item.start) == scheduleMinutes(candidate.start) &&
      scheduleMinutes(item.end) == scheduleMinutes(candidate.end) &&
      normalized(item.title) == normalized(candidate.title));
}
