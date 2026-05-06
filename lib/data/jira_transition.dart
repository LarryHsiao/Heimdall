class JiraTransition {
  final String id;
  final String name;
  final String toStatus;
  final String toStatusCategory;

  const JiraTransition({
    required this.id,
    required this.name,
    this.toStatus = '',
    this.toStatusCategory = '',
  });
}
