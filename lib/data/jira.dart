import 'dart:convert';

import 'package:dio/dio.dart';

import 'jira_attachment.dart';
import 'jira_comment.dart';
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
            'reporter,description,created,updated,attachment',
        'expand': 'renderedFields',
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
    final attachments = (fields['attachment'] as List?) ?? const [];
    final rendered =
        (body['renderedFields'] as Map<String, dynamic>?) ?? const {};
    final renderedDescription = (rendered['description'] as String?) ?? '';
    return JiraIssue(
      ticket: _ticketOf(body),
      reporter: (reporter['displayName'] as String?) ?? '',
      created: (fields['created'] as String?) ?? '',
      updated: (fields['updated'] as String?) ?? '',
      description: fields['description'] as Map<String, dynamic>?,
      attachments: [
        for (final a in attachments)
          if (a is Map<String, dynamic>) JiraAttachment.fromJson(a),
      ],
      inlineImageUrls: inlineImagesFromHtml(renderedDescription),
    );
  }

  Future<List<JiraComment>> comments(
    JiraTicket ticket,
    JiraCredentials credentials,
  ) async {
    final base = credentials.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final auth = base64Encode(
      utf8.encode('${credentials.email}:${credentials.apiToken}'),
    );
    final response = await _dio.get<Map<String, dynamic>>(
      '$base/rest/api/3/issue/${ticket.key}/comment',
      options: Options(headers: {'Authorization': 'Basic $auth'}),
    );
    final list = (response.data?['comments'] as List?) ?? const [];
    return list.map(_commentOf).toList();
  }

  Future<JiraComment> postComment(
    JiraTicket ticket,
    String text,
    JiraCredentials credentials,
  ) async {
    final base = credentials.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final auth = base64Encode(
      utf8.encode('${credentials.email}:${credentials.apiToken}'),
    );
    final response = await _dio.post<Map<String, dynamic>>(
      '$base/rest/api/3/issue/${ticket.key}/comment',
      data: {'body': _adfFromPlain(text)},
      options: Options(headers: {'Authorization': 'Basic $auth'}),
    );
    return _commentOf(response.data ?? const <String, dynamic>{});
  }

  JiraComment _commentOf(dynamic raw) {
    final map = (raw as Map<String, dynamic>?) ?? const {};
    final author = (map['author'] as Map<String, dynamic>?) ?? const {};
    return JiraComment(
      id: (map['id'] as String?) ?? '',
      author: (author['displayName'] as String?) ?? '',
      created: (map['created'] as String?) ?? '',
      updated: (map['updated'] as String?) ?? '',
      body: map['body'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> _adfFromPlain(String text) {
    final lines = text.split('\n');
    final paragraphs = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.isEmpty) {
        paragraphs.add({'type': 'paragraph'});
      } else {
        paragraphs.add({
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': line}
          ],
        });
      }
    }
    return {
      'type': 'doc',
      'version': 1,
      'content': paragraphs,
    };
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

final RegExp _imgSrc = RegExp(
  r'''<img\b[^>]*\ssrc=(?:"([^"]*)"|'([^']*)')''',
  caseSensitive: false,
);

List<String> inlineImagesFromHtml(String html) {
  if (html.isEmpty) return const [];
  final urls = <String>[];
  for (final m in _imgSrc.allMatches(html)) {
    final raw = m.group(1) ?? m.group(2) ?? '';
    if (raw.isEmpty) continue;
    urls.add(_decodeEntities(raw));
  }
  return urls;
}

String _decodeEntities(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');
