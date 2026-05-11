import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_ticket.dart';

JiraTicket _ticket({
  String key = 'PSG-1234',
  String summary = 'Pay slips',
  String assignee = 'Aragorn',
  String statusName = 'In Progress',
}) {
  return JiraTicket(
    key: key,
    summary: summary,
    statusName: statusName,
    statusCategory: 'indeterminate',
    issueType: 'Story',
    assignee: assignee,
  );
}

void main() {
  group('JiraTicket.matchesSearch', () {
    test('empty query matches every ticket', () {
      const expected = true;
      final actual = _ticket().matchesSearch('');
      expect(actual, expected);
    });

    test('whitespace-only query is treated as empty', () {
      const expected = true;
      final actual = _ticket().matchesSearch('   ');
      expect(actual, expected);
    });

    test('matches a substring of the key, case-insensitively', () {
      const expected = true;
      final actual = _ticket(key: 'PSG-1234').matchesSearch('psg');
      expect(actual, expected);
    });

    test('matches a substring of the summary', () {
      const expected = true;
      final actual = _ticket(summary: 'Pay slips').matchesSearch('slip');
      expect(actual, expected);
    });

    test('matches a substring of the assignee name', () {
      const expected = true;
      final actual = _ticket(assignee: 'Aragorn').matchesSearch('ARA');
      expect(actual, expected);
    });

    test('matches a substring of the status name', () {
      const expected = true;
      final actual =
          _ticket(statusName: 'In Progress').matchesSearch('progress');
      expect(actual, expected);
    });

    test('returns false when no field carries the query', () {
      const expected = false;
      final actual = _ticket().matchesSearch('nowhere');
      expect(actual, expected);
    });
  });
}
