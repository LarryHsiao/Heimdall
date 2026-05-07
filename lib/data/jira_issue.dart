import 'jira_ticket.dart';

class JiraIssue {
  final JiraTicket ticket;
  final String reporter;
  final String created;
  final String updated;
  final Map<String, dynamic>? description;

  const JiraIssue({
    required this.ticket,
    this.reporter = '',
    this.created = '',
    this.updated = '',
    this.description,
  });
}
