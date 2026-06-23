import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_filter.dart';
import 'package:heimdall/data/jql_with_issue.dart';

void main() {
  group('JqlWithIssue', () {
    test('composes from a JQL filter', () {
      const filter = JiraFilter(id: '1', name: 'Mine', query: 'project = HEI');
      final expected = '(project = HEI) OR issuekey = HEI-8';
      final actual = const JqlWithIssue(filter, 'HEI-8').value();
      expect(actual, expected);
    });

    test('composes a bare-ID filter, lifting ORDER BY to the tail', () {
      const filter = JiraFilter(id: '1', name: 'Mine', query: '10363');
      final expected = '(filter = 10363) OR issuekey = HEI-8 ORDER BY Rank';
      final actual = const JqlWithIssue(filter, 'HEI-8').value();
      expect(actual, expected);
    });

    test('lifts a raw query\'s own ORDER BY clause to the tail', () {
      const filter = JiraFilter(
        id: '1',
        name: 'Mine',
        query: 'project = HEI ORDER BY created',
      );
      final expected = '(project = HEI) OR issuekey = HEI-8 ORDER BY created';
      final actual = const JqlWithIssue(filter, 'HEI-8').value();
      expect(actual, expected);
    });

    test('yields bare issuekey for an empty query', () {
      const filter = JiraFilter(id: '1', name: 'Mine', query: '');
      final expected = 'issuekey = HEI-8';
      final actual = const JqlWithIssue(filter, 'HEI-8').value();
      expect(actual, expected);
    });
  });
}
