import 'dart:convert';
class StudentTask {
  const StudentTask({
    required this.id,
    required this.title,
    required this.course,
    required this.date,
    required this.hour,
    required this.room,
    required this.isExam,
    this.description = '',
    this.done = false,
  });

  final String id, title, course, hour, room;
  final String description;
  final DateTime date;
  final bool isExam, done;

  StudentTask copyWith({bool? done, String? description}) => StudentTask(
    id: id,
    title: title,
    course: course,
    date: date,
    hour: hour,
    room: room,
    description: description ?? this.description,
    isExam: isExam,
    done: done ?? this.done,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'course': course,
    'date': date.toIso8601String(),
    'hour': hour,
    'room': room,
    'description': description,
    'isExam': isExam,
    'done': done,
  };

  factory StudentTask.fromMap(Map<String, dynamic> map) => StudentTask(
    id: map['id'] as String,
    title: map['title'] as String,
    course: map['course'] as String,
    date: DateTime.parse(map['date'] as String),
    hour: map['hour'] as String,
    room: map['room'] as String? ?? '',
    // Existing tasks and backups don't contain description.
    description: map['description'] as String? ?? '',
    isExam: map['isExam'] as bool,
    done: map['done'] as bool? ?? false,
  );

  static String encodeList(List<StudentTask> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList());

  static List<StudentTask> decodeList(String raw) =>
      (jsonDecode(raw) as List<dynamic>)
          .map((e) => StudentTask.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
}

class CampusNotice {
  const CampusNotice({required this.id, required this.title, required this.body, required this.category, required this.createdAt});
  final String id, title, body, category;
  final DateTime createdAt;
}
