import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira.dart';
import 'package:heimdall/data/jira_credentials.dart';
import 'package:heimdall/data/jira_ticket.dart';
import 'package:heimdall/data/mention_range.dart';
import 'package:heimdall/data/mentioned_comment.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this._handler);
  final ResponseBody Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      _handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        'content-type': ['application/json; charset=utf-8'],
      },
    );

const JiraCredentials _creds = JiraCredentials(
  baseUrl: 'https://example.atlassian.net',
  email: 'a@b.c',
  apiToken: 'token',
);

const JiraTicket _ticket = JiraTicket(
  key: 'PSG-1',
  summary: 's',
  statusName: 'In Progress',
  statusCategory: 'indeterminate',
  issueType: 'Story',
  assignee: 'Aragorn',
);

void main() {
  group('Jira.postComment', () {
    test('posts MentionedComment.adfDoc() as the body', () async {
      Object? sentBody;
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          sentBody = o.data;
          return _jsonBody({'id': '1'});
        });
      final jira = Jira(dio: dio);

      const ranges = [
        MentionRange(
          accountId: 'a1',
          displayName: 'Larry',
          start: 3,
          length: 6,
        ),
      ];
      const comment = MentionedText('cc @Larry please', ranges);
      final expectedBody = {'body': comment.adfDoc()};

      await jira.postComment(_ticket, comment, _creds);

      expect(sentBody, expectedBody);
    });

    test('plain text wrapped in PlainComment posts a plain paragraph', () async {
      Object? sentBody;
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          sentBody = o.data;
          return _jsonBody({'id': '1'});
        });
      final jira = Jira(dio: dio);

      const expectedBody = {
        'body': {
          'type': 'doc',
          'version': 1,
          'content': [
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': 'hello'},
              ],
            },
          ],
        },
      };

      await jira.postComment(_ticket, const PlainComment('hello'), _creds);

      expect(sentBody, expectedBody);
    });
  });
}
