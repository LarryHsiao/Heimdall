import 'jira_ticket.dart';

class JiraIssueLink {
  final String typeName;
  final String label;
  final bool isOutward;
  final JiraTicket ticket;

  const JiraIssueLink({
    required this.typeName,
    required this.label,
    required this.isOutward,
    required this.ticket,
  });
}
