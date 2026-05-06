class JiraTicket {
  final String key;
  final String summary;
  final String statusName;
  final String statusCategory;
  final String issueType;
  final String priority;
  final String assignee;
  final String parentKey;
  final String parentSummary;

  const JiraTicket({
    required this.key,
    required this.summary,
    required this.statusName,
    required this.statusCategory,
    required this.issueType,
    this.priority = '',
    this.assignee = '',
    this.parentKey = '',
    this.parentSummary = '',
  });
}
