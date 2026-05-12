import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_filter.dart';
import 'package:heimdall/data/jira_ticket.dart';
import 'package:heimdall/data/jira_transition.dart';
import 'package:heimdall/data/jira_user.dart';
import 'package:heimdall/data/view_settings.dart';
import 'package:heimdall/ui/tickets_page.dart';

JiraTicket _ticket({
  required String key,
  String summary = '',
  String parentKey = '',
  String assignee = '',
  String statusName = 'To Do',
  String issueType = 'Story',
}) {
  return JiraTicket(
    key: key,
    summary: summary.isEmpty ? 'Summary of $key' : summary,
    statusName: statusName,
    statusCategory: 'new',
    issueType: issueType,
    assignee: assignee,
    parentKey: parentKey,
  );
}

const _filter = JiraFilter(id: 'f1', name: 'Test', query: '');

Future<void> _pump(
  WidgetTester tester,
  FilterSection section, {
  required ViewMode mode,
  ValueChanged<JiraTicket>? onTicketTap,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final settings = ViewSettings(mode: mode);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SectionView(
            section: section,
            settings: settings,
            onSort: (_, _) {},
            onColumnWidthChange: (_, _) {},
            onTicketTap: onTicketTap ?? (_) {},
            onLoadTransitions: (_) async => const <JiraTransition>[],
            onApplyTransition: (_, _) async {},
            onLoadAssignableUsers: (_, _) async => const <JiraUser>[],
            onApplyAssignee: (_, _) async {},
          ),
        ),
      ),
    ),
  );
}

Finder _indicatorFor(String parentKey) =>
    find.byKey(ValueKey('hidden-children-$parentKey'));

void main() {
  group('hidden sub-tasks indicator', () {
    for (final mode in ViewMode.values) {
      group('mode=${mode.name}', () {
        testWidgets(
          'shows indicator when some sub-tasks are filtered out',
          (tester) async {
            final parent = _ticket(key: 'HEI-1');
            final visibleChild =
                _ticket(key: 'HEI-2', parentKey: 'HEI-1');
            final hiddenChild = _ticket(
              key: 'HEI-3',
              parentKey: 'HEI-1',
              summary: 'Hidden child',
              assignee: 'Aragorn',
              statusName: 'In Progress',
            );
            final section = FilterSection(
              filter: _filter,
              tickets: [parent, visibleChild],
              allTickets: [parent, visibleChild, hiddenChild],
            );

            const expected = 1;
            await _pump(tester, section, mode: mode);

            expect(_indicatorFor('HEI-1'), findsExactly(expected));
          },
        );

        testWidgets(
          'omits indicator when all sub-tasks pass the filter',
          (tester) async {
            final parent = _ticket(key: 'HEI-1');
            final child = _ticket(key: 'HEI-2', parentKey: 'HEI-1');
            final section = FilterSection(
              filter: _filter,
              tickets: [parent, child],
              allTickets: [parent, child],
            );

            const expected = 0;
            await _pump(tester, section, mode: mode);

            expect(_indicatorFor('HEI-1'), findsExactly(expected));
          },
        );

        testWidgets(
          'omits indicator when parent has no sub-tasks',
          (tester) async {
            final lone = _ticket(key: 'HEI-9');
            final section = FilterSection(
              filter: _filter,
              tickets: [lone],
              allTickets: [lone],
            );

            const expected = 0;
            await _pump(tester, section, mode: mode);

            expect(_indicatorFor('HEI-9'), findsExactly(expected));
          },
        );

        testWidgets(
          'leaves orphan sub-task path untouched',
          (tester) async {
            final orphan = _ticket(key: 'HEI-7', parentKey: 'HEI-PARENT');
            final section = FilterSection(
              filter: _filter,
              tickets: [orphan],
              allTickets: [orphan],
            );

            const expected = 0;
            await _pump(tester, section, mode: mode);

            expect(_indicatorFor('HEI-7'), findsExactly(expected));
            expect(_indicatorFor('HEI-PARENT'), findsExactly(expected));
            expect(find.text('HEI-7'), findsOneWidget);
          },
        );

        testWidgets(
          'tapping the indicator inlines the hidden sub-tasks dimmed; '
          'tapping a hidden row routes; tapping again collapses',
          (tester) async {
            final parent = _ticket(key: 'HEI-1');
            final visibleChild =
                _ticket(key: 'HEI-2', parentKey: 'HEI-1');
            final hiddenA = _ticket(
              key: 'HEI-3',
              parentKey: 'HEI-1',
              summary: 'Hidden A',
              assignee: 'Aragorn',
              statusName: 'In Progress',
            );
            final hiddenB = _ticket(
              key: 'HEI-4',
              parentKey: 'HEI-1',
              summary: 'Hidden B',
              statusName: 'Done',
            );
            JiraTicket? tapped;
            final section = FilterSection(
              filter: _filter,
              tickets: [parent, visibleChild],
              allTickets: [parent, visibleChild, hiddenA, hiddenB],
            );

            await _pump(
              tester,
              section,
              mode: mode,
              onTicketTap: (t) => tapped = t,
            );

            const collapsedHidden = 0;
            const collapsedIcon = 1;
            expect(find.text('HEI-3'), findsExactly(collapsedHidden));
            expect(find.text('HEI-4'), findsExactly(collapsedHidden));
            expect(
              find.byIcon(Icons.unfold_more),
              findsExactly(collapsedIcon),
            );

            await tester.tap(_indicatorFor('HEI-1'));
            await tester.pumpAndSettle();

            const expandedHiddenRow = 1;
            expect(find.text('HEI-3'), findsExactly(expandedHiddenRow));
            expect(find.text('Hidden A'), findsExactly(expandedHiddenRow));
            expect(find.text('Aragorn'), findsExactly(expandedHiddenRow));
            expect(find.text('HEI-4'), findsExactly(expandedHiddenRow));
            expect(find.text('Hidden B'), findsExactly(expandedHiddenRow));
            expect(
              find.byIcon(Icons.unfold_less),
              findsExactly(collapsedIcon),
            );

            final dimmedHidden = find.ancestor(
              of: find.text('HEI-3'),
              matching: find.byWidgetPredicate(
                (w) => w is Opacity && w.opacity == 0.55,
              ),
            );
            expect(dimmedHidden, findsExactly(expandedHiddenRow));

            final dimmedVisible = find.ancestor(
              of: find.text('HEI-2'),
              matching: find.byWidgetPredicate(
                (w) => w is Opacity && w.opacity == 0.55,
              ),
            );
            expect(dimmedVisible, findsExactly(collapsedHidden));

            await tester.tap(find.text('HEI-3'));
            await tester.pumpAndSettle();

            final JiraTicket expectedTapped = hiddenA;
            expect(tapped, expectedTapped);

            await tester.tap(_indicatorFor('HEI-1'));
            await tester.pumpAndSettle();

            expect(find.text('HEI-3'), findsExactly(collapsedHidden));
            expect(find.text('HEI-4'), findsExactly(collapsedHidden));
            expect(
              find.byIcon(Icons.unfold_more),
              findsExactly(collapsedIcon),
            );
          },
        );
      });
    }
  });
}
