class JiraTicket {
  final String key;
  final String summary;
  final String statusName;
  final String statusCategory;

  const JiraTicket({
    required this.key,
    required this.summary,
    required this.statusName,
    required this.statusCategory,
  });
}
