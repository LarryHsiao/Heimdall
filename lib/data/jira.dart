import 'dart:convert';

import 'package:dio/dio.dart';

import 'jira_credentials.dart';
import 'jira_filter.dart';
import 'jira_issue.dart';
import 'jira_ticket.dart';
import 'jira_transition.dart';

class Jira {
  final Dio _dio;

  Jira({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<JiraTicket>> tickets(
    JiraFilter filter,
    JiraCredentials credentials,
  ) async {
    final base = credentials.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final auth = base64Encode(
      utf8.encode('${credentials.email}:${credentials.apiToken}'),
    );
    final response = await _dio.get<Map<String, dynamic>>(
      '$base/rest/api/3/search/jql',
      queryParameters: {
        'jql': filter.jql,
        'fields': 'summary,status,issuetype,parent,priority,assignee',
        'maxResults': 50,
      },
      options: Options(headers: {'Authorization': 'Basic $auth'}),
    );
    return _parse(response.data);
  }

  List<JiraTicket> _parse(Map<String, dynamic>? body) {
    if (body == null) {
      return const [];
    }
    final issues = body['issues'];
    if (issues is! List) {
      return const [];
    }
    return issues.map(_ticketOf).toList();
  }

  JiraTicket _ticketOf(dynamic issue) {
    final fields = (issue['fields'] as Map<String, dynamic>?) ?? const {};
    final status = (fields['status'] as Map<String, dynamic>?) ?? const {};
    final category =
        (status['statusCategory'] as Map<String, dynamic>?) ?? const {};
    final type = (fields['issuetype'] as Map<String, dynamic>?) ?? const {};
    final parent = (fields['parent'] as Map<String, dynamic>?) ?? const {};
    final parentFields =
        (parent['fields'] as Map<String, dynamic>?) ?? const {};
    final priority =
        (fields['priority'] as Map<String, dynamic>?) ?? const {};
    final assignee =
        (fields['assignee'] as Map<String, dynamic>?) ?? const {};
    return JiraTicket(
      key: (issue['key'] as String?) ?? '',
      summary: (fields['summary'] as String?) ?? '',
      statusName: (status['name'] as String?) ?? '',
      statusCategory: (category['name'] as String?) ?? '',
      issueType: (type['name'] as String?) ?? '',
      priority: (priority['name'] as String?) ?? '',
      assignee: (assignee['displayName'] as String?) ?? '',
      parentKey: (parent['key'] as String?) ?? '',
      parentSummary: (parentFields['summary'] as String?) ?? '',
    );
  }

  Future<JiraIssue> issue(
    JiraTicket ticket,
    JiraCredentials credentials,
  ) async {
    final base = credentials.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final auth = base64Encode(
      utf8.encode('${credentials.email}:${credentials.apiToken}'),
    );
    final response = await _dio.get<Map<String, dynamic>>(
      '$base/rest/api/3/issue/${ticket.key}',
      queryParameters: {
        'fields': 'summary,status,issuetype,parent,priority,assignee,'
            'reporter,description,created,updated',
      },
      options: Options(headers: {'Authorization': 'Basic $auth'}),
    );
    return _issueOf(response.data);
  }

  JiraIssue _issueOf(Map<String, dynamic>? body) {
    if (body == null) {
      return const JiraIssue(
        ticket: JiraTicket(
          key: '',
          summary: '',
          statusName: '',
          statusCategory: '',
          issueType: '',
        ),
      );
    }
    final fields = (body['fields'] as Map<String, dynamic>?) ?? const {};
    final reporter =
        (fields['reporter'] as Map<String, dynamic>?) ?? const {};
    return JiraIssue(
      ticket: _ticketOf(body),
      reporter: (reporter['displayName'] as String?) ?? '',
      created: (fields['created'] as String?) ?? '',
      updated: (fields['updated'] as String?) ?? '',
      description: fields['description'] as Map<String, dynamic>?,
    );
  }

  Future<List<JiraTransition>> transitions(
    JiraTicket ticket,
    JiraCredentials credentials,
  ) async {
    final base = credentials.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final auth = base64Encode(
      utf8.encode('${credentials.email}:${credentials.apiToken}'),
    );
    final response = await _dio.get<Map<String, dynamic>>(
      '$base/rest/api/3/issue/${ticket.key}/transitions',
      options: Options(headers: {'Authorization': 'Basic $auth'}),
    );
    final list = (response.data?['transitions'] as List?) ?? const [];
    return list.map(_transitionOf).toList();
  }

  JiraTransition _transitionOf(dynamic raw) {
    final to = (raw['to'] as Map<String, dynamic>?) ?? const {};
    final cat = (to['statusCategory'] as Map<String, dynamic>?) ?? const {};
    return JiraTransition(
      id: (raw['id'] as String?) ?? '',
      name: (raw['name'] as String?) ?? '',
      toStatus: (to['name'] as String?) ?? '',
      toStatusCategory: (cat['name'] as String?) ?? '',
    );
  }

  Future<void> transition(
    JiraTicket ticket,
    String transitionId,
    JiraCredentials credentials,
  ) async {
    final base = credentials.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final auth = base64Encode(
      utf8.encode('${credentials.email}:${credentials.apiToken}'),
    );
    await _dio.post<dynamic>(
      '$base/rest/api/3/issue/${ticket.key}/transitions',
      data: {
        'transition': {'id': transitionId},
      },
      options: Options(headers: {'Authorization': 'Basic $auth'}),
    );
  }
}
