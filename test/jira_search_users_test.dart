import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira.dart';
import 'package:heimdall/data/jira_credentials.dart';

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

void main() {
  group('Jira.searchUsers', () {
    test('empty query returns empty list without hitting the network',
        () async {
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((_) {
          calls += 1;
          return _jsonBody(const []);
        });
      final jira = Jira(dio: dio);

      const expected = <Object>[];
      final actual = await jira.searchUsers('', _creds);

      expect(actual, expected);
      expect(calls, 0);
    });

    test('whitespace-only query short-circuits too', () async {
      var calls = 0;
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((_) {
          calls += 1;
          return _jsonBody(const []);
        });
      final jira = Jira(dio: dio);

      final actual = await jira.searchUsers('   ', _creds);

      expect(actual, isEmpty);
      expect(calls, 0);
    });

    test('parses an array of users on success', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          expect(o.path, endsWith('/rest/api/3/user/search'));
          expect(o.queryParameters['query'], 'gala');
          expect(o.queryParameters['maxResults'], 20);
          return _jsonBody([
            {
              'accountId': '5b10a2844c20165700ede21g',
              'displayName': 'Galadriel',
              'emailAddress': 'g@lothlorien.example',
            },
          ]);
        });
      final jira = Jira(dio: dio);

      const expectedAccountId = '5b10a2844c20165700ede21g';
      const expectedDisplayName = 'Galadriel';
      final actual = await jira.searchUsers('gala', _creds);

      expect(actual.length, 1);
      expect(actual.first.accountId, expectedAccountId);
      expect(actual.first.displayName, expectedDisplayName);
    });

    test('tolerates malformed entries by skipping them', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((_) {
          return _jsonBody([
            {'accountId': 'a1', 'displayName': 'Aragorn'},
            'not-a-map',
            {'accountId': 'a2', 'displayName': 'Arwen'},
          ]);
        });
      final jira = Jira(dio: dio);

      final expected = ['a1', 'a2'];
      final actual = await jira.searchUsers('a', _creds);

      expect(actual.map((u) => u.accountId).toList(), expected);
    });

    test('trims trailing slashes from the base URL', () async {
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter((o) {
          expect(o.path,
              'https://example.atlassian.net/rest/api/3/user/search');
          return _jsonBody(const []);
        });
      final jira = Jira(dio: dio);
      const creds = JiraCredentials(
        baseUrl: 'https://example.atlassian.net///',
        email: 'a@b.c',
        apiToken: 'token',
      );

      await jira.searchUsers('x', creds);
    });
  });
}
