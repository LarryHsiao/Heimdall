String lastTokenAt(String text, int cursor) {
  if (text.isEmpty || cursor <= 0) return '';
  final stops = RegExp(r'[\s=<>~!(),]');
  var i = cursor - 1;
  while (i >= 0 && !stops.hasMatch(text[i])) {
    i--;
  }
  return text.substring(i + 1, cursor);
}
