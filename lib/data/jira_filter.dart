class JiraFilter {
  final String id;
  final String name;
  final String query;

  const JiraFilter({
    required this.id,
    required this.name,
    required this.query,
  });

  String get jql {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'filter = $trimmed';
    }
    if (RegExp(r'^[A-Za-z][A-Za-z0-9_]*-\d+$').hasMatch(trimmed)) {
      return 'issuekey = $trimmed';
    }
    return trimmed;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'query': query,
      };

  factory JiraFilter.fromJson(Map<String, dynamic> json) => JiraFilter(
        id: json['id'] as String,
        name: json['name'] as String,
        query: json['query'] as String,
      );
}

String childrenJql(String key, {required bool isEpic}) =>
    isEpic ? '"Epic Link" = $key' : 'parent = $key';
