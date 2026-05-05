import 'dart:convert';

import 'package:dio/dio.dart';

import 'jira_credentials.dart';
import 'jira_filter.dart';
import 'jira_ticket.dart';

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
        'fields': 'summary,status',
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
    return JiraTicket(
      key: (issue['key'] as String?) ?? '',
      summary: (fields['summary'] as String?) ?? '',
      statusName: (status['name'] as String?) ?? '',
      statusCategory: (category['name'] as String?) ?? '',
    );
  }
}
