import 'package:flutter_test/flutter_test.dart';

import 'package:heimdall/data/jira_filter.dart';

JiraFilter _filter(String query) =>
    JiraFilter(id: 'id', name: 'name', query: query);

void main() {
  group('JiraFilter.jql', () {
    test('a bare ticket key composes an issuekey clause', () {
      const expected = 'issuekey = HEI-6';
      expect(_filter('HEI-6').jql, expected);
    });

    test('a bare number composes a filter clause ordered by Rank', () {
      const expected = 'filter = 10363 ORDER BY Rank';
      expect(_filter('10363').jql, expected);
    });

    test('raw JQL passes through untouched', () {
      const expected = 'project = HEI AND resolution = Unresolved';
      expect(_filter('project = HEI AND resolution = Unresolved').jql, expected);
    });

    test('an empty query composes an empty string', () {
      const expected = '';
      expect(_filter('   ').jql, expected);
    });
  });

  group('childrenJql', () {
    test('an epic key resolves children via the Epic Link', () {
      const expected = '"Epic Link" = HEI-6';
      expect(childrenJql('HEI-6', isEpic: true), expected);
    });

    test('a non-epic key resolves children via parent', () {
      const expected = 'parent = HEI-6';
      expect(childrenJql('HEI-6', isEpic: false), expected);
    });
  });
}
