import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira.dart';

void main() {
  group('parseIssueLink', () {
    test('outwardIssue produces an outward link with the outward label', () {
      final raw = {
        'id': '10100',
        'type': {
          'name': 'Blocks',
          'inward': 'is blocked by',
          'outward': 'blocks',
        },
        'outwardIssue': {
          'key': 'ABC-2',
          'fields': {
            'summary': 'Pay slips',
            'status': {
              'name': 'To Do',
              'statusCategory': {'name': 'new'},
            },
            'issuetype': {'name': 'Story'},
            'priority': {'name': 'High'},
          },
        },
      };

      final actual = parseIssueLink(raw);

      expect(actual, isNotNull);
      expect(actual!.typeName, 'Blocks');
      expect(actual.label, 'blocks');
      expect(actual.isOutward, isTrue);
      expect(actual.ticket.key, 'ABC-2');
      expect(actual.ticket.summary, 'Pay slips');
      expect(actual.ticket.statusName, 'To Do');
      expect(actual.ticket.issueType, 'Story');
      expect(actual.ticket.priority, 'High');
    });

    test('inwardIssue produces an inward link with the inward label', () {
      final raw = {
        'type': {
          'name': 'Blocks',
          'inward': 'is blocked by',
          'outward': 'blocks',
        },
        'inwardIssue': {
          'key': 'DEF-9',
          'fields': {
            'summary': 'Tax tables',
            'status': {
              'name': 'Done',
              'statusCategory': {'name': 'done'},
            },
            'issuetype': {'name': 'Task'},
          },
        },
      };

      final actual = parseIssueLink(raw);

      expect(actual, isNotNull);
      expect(actual!.label, 'is blocked by');
      expect(actual.isOutward, isFalse);
      expect(actual.ticket.key, 'DEF-9');
      expect(actual.ticket.statusName, 'Done');
    });

    test('returns null when neither inwardIssue nor outwardIssue is present',
        () {
      final raw = {
        'type': {'name': 'Relates', 'inward': 'relates to', 'outward': 'relates to'},
      };

      final actual = parseIssueLink(raw);

      expect(actual, isNull);
    });

    test('falls back to empty strings when type fields are missing', () {
      final raw = {
        'type': <String, dynamic>{},
        'outwardIssue': {
          'key': 'X-1',
          'fields': <String, dynamic>{},
        },
      };

      final actual = parseIssueLink(raw);

      expect(actual, isNotNull);
      expect(actual!.typeName, '');
      expect(actual.label, '');
      expect(actual.ticket.key, 'X-1');
    });
  });
}
