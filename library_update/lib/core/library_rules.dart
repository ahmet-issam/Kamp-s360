import 'models.dart';

const libraryReturnPrefix = 'library_return_';
bool isLibraryReturn(StudentTask task) => task.id.startsWith(libraryReturnPrefix);
String librarySearchKey(String value) => value.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().trim();
bool libraryReturnDuplicate(StudentTask candidate, Iterable<StudentTask> tasks) => tasks.any((task) =>
    isLibraryReturn(task) && !task.done && task.id != candidate.id &&
    librarySearchKey(task.title) == librarySearchKey(candidate.title) &&
    task.date.year == candidate.date.year && task.date.month == candidate.date.month &&
    task.date.day == candidate.date.day && task.hour == candidate.hour);
