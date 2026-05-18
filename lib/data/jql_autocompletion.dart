class JqlAutocompletion {
  final List<String> fieldNames;
  final List<String> functionNames;
  final List<String> reservedWords;

  const JqlAutocompletion({
    required this.fieldNames,
    required this.functionNames,
    required this.reservedWords,
  });

  factory JqlAutocompletion.fromJson(Map<String, dynamic> json) {
    return JqlAutocompletion(
      fieldNames: _values(json['visibleFieldNames']),
      functionNames: _values(json['visibleFunctionNames']),
      reservedWords: _reserved(json['jqlReservedWords']),
    );
  }

  List<String> get suggestions => [
        ...fieldNames,
        ...functionNames,
        ...reservedWords,
      ];

  static List<String> _values(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map<String, dynamic> && entry['value'] is String)
          entry['value'] as String,
    ];
  }

  static List<String> _reserved(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is String) entry,
    ];
  }
}
