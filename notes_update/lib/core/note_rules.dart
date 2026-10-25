String normalizeNoteSearch(String value) => value
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

bool noteMatches(String title, String body, String query) {
  final needle = normalizeNoteSearch(query);
  return needle.isEmpty ||
      normalizeNoteSearch(title).contains(needle) ||
      normalizeNoteSearch(body).contains(needle);
}

String noteTopic(String entered, Iterable<String> existing) {
  final cleaned = entered.trim().replaceAll(RegExp(r'\s+'), ' ');
  final normalized = normalizeNoteSearch(cleaned);
  for (final title in existing) {
    if (normalizeNoteSearch(title) == normalized) {
      return title;
    }
  }
  return cleaned;
}
