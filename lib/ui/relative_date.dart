String relativeDate(String? raw, {DateTime? now}) {
  if (raw == null || raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return _isoDate(raw);
  final clock = now ?? DateTime.now();
  final diff = clock.difference(parsed);
  if (diff.isNegative) return _isoDate(raw);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  final days = _calendarDaysAgo(clock, parsed);
  if (days == 1) return 'yesterday';
  if (days < 7) return '${days}d ago';
  return _isoDate(raw);
}

int _calendarDaysAgo(DateTime now, DateTime then) {
  final n = now.toLocal();
  final t = then.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final that = DateTime(t.year, t.month, t.day);
  return today.difference(that).inDays;
}

String _isoDate(String raw) {
  final t = raw.indexOf('T');
  return t > 0 ? raw.substring(0, t) : raw;
}
