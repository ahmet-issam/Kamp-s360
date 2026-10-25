// Snapshot of the existing app model for standalone rule tests only.
class ClassSession {
  const ClassSession({required this.id, required this.title, required this.day, required this.start, required this.end, required this.room, required this.faculty, required this.teacher, required this.colorIndex});
  final String id, title, start, end, room, faculty, teacher;
  final int day, colorIndex;
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'day': day, 'start': start, 'end': end, 'room': room, 'faculty': faculty, 'teacher': teacher, 'colorIndex': colorIndex};
  factory ClassSession.fromMap(Map<String, dynamic> data) => ClassSession(
      id: data['id'] as String, title: data['title'] as String,
      day: (data['day'] as num).toInt().clamp(1, 7).toInt(), start: data['start'] as String,
      end: data['end'] as String, room: data['room'] as String? ?? '',
      faculty: data['faculty'] as String? ?? '', teacher: data['teacher'] as String? ?? '',
      colorIndex: ((data['colorIndex'] as num?)?.toInt() ?? 0).clamp(0, 4).toInt());

}

