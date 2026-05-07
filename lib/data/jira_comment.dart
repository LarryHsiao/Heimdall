class JiraComment {
  final String id;
  final String author;
  final String created;
  final String updated;
  final Map<String, dynamic>? body;

  const JiraComment({
    required this.id,
    this.author = '',
    this.created = '',
    this.updated = '',
    this.body,
  });
}
