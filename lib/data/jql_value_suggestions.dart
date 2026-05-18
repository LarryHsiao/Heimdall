List<String> parseJqlValueSuggestions(Map<String, dynamic>? body) {
  final results = (body?['results'] as List?) ?? const [];
  return [
    for (final entry in results)
      if (entry is Map<String, dynamic> && entry['value'] is String)
        entry['value'] as String,
  ];
}
