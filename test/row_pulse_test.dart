import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_filter.dart';
import 'package:heimdall/data/jira_ticket.dart';
import 'package:heimdall/data/jira_transition.dart';
import 'package:heimdall/data/jira_user.dart';
import 'package:heimdall/data/view_settings.dart';
import 'package:heimdall/ui/row_pulse.dart';
import 'package:heimdall/ui/tickets_page.dart';

JiraTicket _ticket({
  required String key,
  String summary = 's',
  String statusName = 'To Do',
  String statusCategory = 'new',
  String issueType = 'Task',
  String priority = '',
  String assignee = '',
  String parentKey = '',
}) {
  return JiraTicket(
    key: key,
    summary: summary,
    statusName: statusName,
    statusCategory: statusCategory,
    issueType: issueType,
    priority: priority,
    assignee: assignee,
    parentKey: parentKey,
  );
}

void main() {
  group('ticketChanged', () {
    test('returns false when watched fields are identical', () {
      final a = _ticket(key: 'HEI-1');
      final b = _ticket(key: 'HEI-1');
      final expected = false;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when summary differs', () {
      final a = _ticket(key: 'HEI-1', summary: 'old');
      final b = _ticket(key: 'HEI-1', summary: 'new');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when statusName differs', () {
      final a = _ticket(key: 'HEI-1', statusName: 'To Do');
      final b = _ticket(key: 'HEI-1', statusName: 'Done');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when assignee differs', () {
      final a = _ticket(key: 'HEI-1', assignee: 'Alice');
      final b = _ticket(key: 'HEI-1', assignee: 'Bob');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when priority differs', () {
      final a = _ticket(key: 'HEI-1', priority: 'Low');
      final b = _ticket(key: 'HEI-1', priority: 'High');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when issueType differs', () {
      final a = _ticket(key: 'HEI-1', issueType: 'Task');
      final b = _ticket(key: 'HEI-1', issueType: 'Bug');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when parentKey differs', () {
      final a = _ticket(key: 'HEI-1', parentKey: '');
      final b = _ticket(key: 'HEI-1', parentKey: 'HEI-99');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });

    test('returns true when statusCategory differs', () {
      final a = _ticket(key: 'HEI-1', statusCategory: 'new');
      final b = _ticket(key: 'HEI-1', statusCategory: 'done');
      final expected = true;
      expect(ticketChanged(a, b), expected);
    });
  });

  group('pulseAlpha', () {
    final window = const Duration(seconds: 2);

    test('returns 1.0 at t=0', () {
      final at = DateTime(2026, 5, 22, 12, 0, 0);
      final now = at;
      final expected = 1.0;
      expect(pulseAlpha(at: at, now: now, window: window), expected);
    });

    test('returns ~0.5 at half-window', () {
      final at = DateTime(2026, 5, 22, 12, 0, 0);
      final now = at.add(const Duration(seconds: 1));
      final expected = 0.5;
      expect(pulseAlpha(at: at, now: now, window: window), closeTo(expected, 0.01));
    });

    test('returns 0.0 at the window edge', () {
      final at = DateTime(2026, 5, 22, 12, 0, 0);
      final now = at.add(const Duration(seconds: 2));
      final expected = 0.0;
      expect(pulseAlpha(at: at, now: now, window: window), expected);
    });

    test('returns 0.0 past the window edge', () {
      final at = DateTime(2026, 5, 22, 12, 0, 0);
      final now = at.add(const Duration(seconds: 10));
      final expected = 0.0;
      expect(pulseAlpha(at: at, now: now, window: window), expected);
    });

    test('clamps at 1.0 for a future timestamp', () {
      final at = DateTime(2026, 5, 22, 12, 0, 5);
      final now = DateTime(2026, 5, 22, 12, 0, 0);
      final expected = 1.0;
      expect(pulseAlpha(at: at, now: now, window: window), expected);
    });
  });

  group('nextPulses', () {
    final now = DateTime(2026, 5, 22, 12, 0, 0);
    final window = const Duration(seconds: 2);

    test('adds a pulse for a newly-arrived ticket', () {
      final previous = <JiraTicket>[];
      final current = [_ticket(key: 'HEI-1')];
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: const <String, DateTime>{},
        now: now,
        window: window,
      );
      final expected = {'HEI-1': now};
      expect(result, expected);
    });

    test('adds a pulse for a changed ticket', () {
      final previous = [_ticket(key: 'HEI-1', statusName: 'To Do')];
      final current = [_ticket(key: 'HEI-1', statusName: 'Done')];
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: const <String, DateTime>{},
        now: now,
        window: window,
      );
      final expected = {'HEI-1': now};
      expect(result, expected);
    });

    test('does not add a pulse for an unchanged ticket', () {
      final previous = [_ticket(key: 'HEI-1')];
      final current = [_ticket(key: 'HEI-1')];
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: const <String, DateTime>{},
        now: now,
        window: window,
      );
      final expected = <String, DateTime>{};
      expect(result, expected);
    });

    test('preserves a live (non-stale) existing entry', () {
      final previous = [_ticket(key: 'HEI-1')];
      final current = [_ticket(key: 'HEI-1')];
      final existing = {'HEI-1': now.subtract(const Duration(seconds: 1))};
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: existing,
        now: now,
        window: window,
      );
      expect(result, existing);
    });

    test('purges entries older than window + 500 ms slack', () {
      final previous = [_ticket(key: 'HEI-1')];
      final current = [_ticket(key: 'HEI-1')];
      final existing = {
        'HEI-1': now.subtract(const Duration(seconds: 3)),
      };
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: existing,
        now: now,
        window: window,
      );
      final expected = <String, DateTime>{};
      expect(result, expected);
    });

    test('overwrites a stale entry with a fresh change', () {
      final previous = [_ticket(key: 'HEI-1', statusName: 'To Do')];
      final current = [_ticket(key: 'HEI-1', statusName: 'Done')];
      final existing = {
        'HEI-1': now.subtract(const Duration(seconds: 5)),
      };
      final result = nextPulses(
        previous: previous,
        current: current,
        existing: existing,
        now: now,
        window: window,
      );
      final expected = {'HEI-1': now};
      expect(result, expected);
    });
  });

  group('SectionView pulse rendering', () {
    Future<void> pumpSection(
      WidgetTester tester, {
      required List<JiraTicket> tickets,
      required Map<String, DateTime> pulses,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionView(
              section: FilterSection(
                filter:
                    const JiraFilter(id: 'f1', name: 'F', query: 'jql'),
                tickets: tickets,
              ),
              settings: const ViewSettings(),
              pulses: pulses,
              onSort: (_, _) {},
              onColumnWidthChange: (_, _) {},
              onTicketTap: (_) {},
              onLoadTransitions: (_) async => const <JiraTransition>[],
              onApplyTransition: (_, _) async {},
              onLoadAssignableUsers: (_, _) async => const <JiraUser>[],
              onApplyAssignee: (_, _) async {},
            ),
          ),
        ),
      );
    }

    TableRow rowForKey(WidgetTester tester, String key) {
      final table = tester.widget<Table>(find.byType(Table));
      return table.children.firstWhere(
        (row) => row.children.any(
          (cell) => find.descendant(
            of: find.byWidget(cell),
            matching: find.text(key),
          ).evaluate().isNotEmpty,
        ),
      );
    }

    testWidgets('tints a row whose key has a fresh pulse', (tester) async {
      final now = DateTime.now();
      final tickets = [_ticket(key: 'HEI-1'), _ticket(key: 'HEI-2')];
      await pumpSection(
        tester,
        tickets: tickets,
        pulses: {'HEI-1': now},
      );

      final row = rowForKey(tester, 'HEI-1');
      final color = (row.decoration as BoxDecoration?)?.color;
      expect(color, isNotNull);
      expect(color!.a, greaterThan(0.0));
    });

    testWidgets('drops the tint past the fade window', (tester) async {
      final now = DateTime.now();
      final tickets = [_ticket(key: 'HEI-1')];
      await pumpSection(
        tester,
        tickets: tickets,
        pulses: {'HEI-1': now.subtract(const Duration(seconds: 3))},
      );

      final row = rowForKey(tester, 'HEI-1');
      final color = (row.decoration as BoxDecoration?)?.color;
      expect(color, isNull);
    });

    testWidgets('renders no pulse when the map is empty', (tester) async {
      final tickets = [_ticket(key: 'HEI-1')];
      await pumpSection(
        tester,
        tickets: tickets,
        pulses: const <String, DateTime>{},
      );

      final row = rowForKey(tester, 'HEI-1');
      final color = (row.decoration as BoxDecoration?)?.color;
      expect(color, isNull);
    });
  });
}
