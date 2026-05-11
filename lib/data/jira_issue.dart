import 'jira_attachment.dart';
import 'jira_issue_link.dart';
import 'jira_ticket.dart';

class JiraIssue {
  final JiraTicket ticket;
  final String reporter;
  final String created;
  final String updated;
  final Map<String, dynamic>? description;
  final List<JiraAttachment> attachments;
  final List<String> inlineImageUrls;
  final List<JiraTicket> subtasks;
  final List<JiraIssueLink> links;

  const JiraIssue({
    required this.ticket,
    this.reporter = '',
    this.created = '',
    this.updated = '',
    this.description,
    this.attachments = const [],
    this.inlineImageUrls = const [],
    this.subtasks = const [],
    this.links = const [],
  });
}
