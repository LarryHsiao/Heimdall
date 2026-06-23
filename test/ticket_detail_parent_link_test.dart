import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_comment.dart';
import 'package:heimdall/data/jira_issue.dart';
import 'package:heimdall/data/jira_ticket.dart';
import 'package:heimdall/data/jira_transition.dart';
import 'package:heimdall/data/jira_user.dart';
import 'package:heimdall/ui/ticket_detail_page.dart';

const _child = JiraTicket(
  key: 'HEI-9',
  summary: 'Child ticket',
  statusName: 'To Do',
  statusCategory: 'new',
  issueType: 'Task',
  parentKey: 'HEI-1',
  parentSummary: 'Parent ticket',
);

Widget _page({void Function(JiraTicket, {bool replace})? onOpenTicket}) {
  return MaterialApp(
    home: TicketDetailPage(
      initial: _child,
      baseUrl: 'https://example.atlassian.net',
      onLoad: () async => const JiraIssue(ticket: _child),
      onLoadTransitions: () async => const <JiraTransition>[],
      onApplyTransition: (_) async {},
      onLoadComments: () async => const <JiraComment>[],
      onPostComment: (_) async => const JiraComment(id: 'c1'),
      onSearchUsers: (_) async => const <JiraUser>[],
      onOpenTicket: onOpenTicket,
    ),
  );
}

void main() {
  testWidgets(
    'tapping parent link fires onOpenTicket with parent key and replace:true',
    (tester) async {
      String? capturedKey;
      bool? capturedReplace;

      await tester.pumpWidget(
        _page(
          onOpenTicket: (t, {replace = false}) {
            capturedKey = t.key;
            capturedReplace = replace;
          },
        ),
      );
      await tester.pumpAndSettle();

      final expected = 'HEI-1';
      await tester.tap(find.text('↳ HEI-1 · Parent ticket'));
      await tester.pump();

      expect(capturedKey, expected);
      expect(capturedReplace, isTrue);
    },
  );

  testWidgets(
    'without onOpenTicket the parent line is plain text with no GestureDetector',
    (tester) async {
      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();

      // The parent text is present.
      expect(find.text('↳ HEI-1 · Parent ticket'), findsOneWidget);

      // No GestureDetector wraps it.
      final parentTextFinder = find.text('↳ HEI-1 · Parent ticket');
      final gestureAncestor = find.ancestor(
        of: parentTextFinder,
        matching: find.byType(GestureDetector),
      );
      expect(gestureAncestor, findsNothing);
    },
  );
}
