import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_comment.dart';
import 'package:heimdall/data/jira_issue.dart';
import 'package:heimdall/data/jira_ticket.dart';
import 'package:heimdall/data/jira_transition.dart';
import 'package:heimdall/data/jira_user.dart';
import 'package:heimdall/data/refresh_interval.dart';
import 'package:heimdall/ui/ticket_detail_page.dart';

void main() {
  testWidgets('the interval poll reloads the whole issue, every 60s',
      (tester) async {
    const ticket = JiraTicket(
      key: 'HEI-7',
      summary: 'Watch the bridge',
      statusName: 'To Do',
      statusCategory: 'new',
      issueType: 'Task',
    );
    var loadCount = 0;
    final page = MaterialApp(
      home: TicketDetailPage(
        initial: ticket,
        baseUrl: 'https://example.atlassian.net',
        onLoad: () async {
          loadCount++;
          return const JiraIssue(ticket: ticket);
        },
        onLoadTransitions: () async => const <JiraTransition>[],
        onApplyTransition: (_) async {},
        onLoadComments: () async => const <JiraComment>[],
        onPostComment: (_) async => const JiraComment(id: 'c1'),
        onSearchUsers: (_) async => const <JiraUser>[],
      ),
    );

    await tester.pumpWidget(page);
    await tester.pumpAndSettle();
    const afterFirstLoad = 1;
    expect(loadCount, afterFirstLoad);

    // Before the interval elapses, the issue is not reloaded.
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(loadCount, afterFirstLoad);

    // Once 60s passes, the poll reloads the issue itself — not just comments.
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    const afterPoll = 2;
    expect(loadCount, afterPoll);

    // Dispose the page so the periodic timer is cancelled before the test ends.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keeps polling while the window is unfocused but visible',
      (tester) async {
    const ticket = JiraTicket(
      key: 'HEI-7',
      summary: 'Watch the bridge',
      statusName: 'To Do',
      statusCategory: 'new',
      issueType: 'Task',
    );
    var loadCount = 0;
    final page = MaterialApp(
      home: TicketDetailPage(
        initial: ticket,
        baseUrl: 'https://example.atlassian.net',
        onLoad: () async {
          loadCount++;
          return const JiraIssue(ticket: ticket);
        },
        onLoadTransitions: () async => const <JiraTransition>[],
        onApplyTransition: (_) async {},
        onLoadComments: () async => const <JiraComment>[],
        onPostComment: (_) async => const JiraComment(id: 'c1'),
        onSearchUsers: (_) async => const <JiraUser>[],
      ),
    );

    await tester.pumpWidget(page);
    await tester.pumpAndSettle();
    const afterFirstLoad = 1;
    expect(loadCount, afterFirstLoad);

    // The user clicks away to the browser: the window is inactive but visible.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    // The poll should still fire — a watched window stays current when unfocused.
    await tester.pump(const Duration(seconds: 65));
    await tester.pump();
    const afterPoll = 2;
    expect(loadCount, afterPoll);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pauses polling while the window is hidden', (tester) async {
    const ticket = JiraTicket(
      key: 'HEI-7',
      summary: 'Watch the bridge',
      statusName: 'To Do',
      statusCategory: 'new',
      issueType: 'Task',
    );
    var loadCount = 0;
    final page = MaterialApp(
      home: TicketDetailPage(
        initial: ticket,
        baseUrl: 'https://example.atlassian.net',
        onLoad: () async {
          loadCount++;
          return const JiraIssue(ticket: ticket);
        },
        onLoadTransitions: () async => const <JiraTransition>[],
        onApplyTransition: (_) async {},
        onLoadComments: () async => const <JiraComment>[],
        onPostComment: (_) async => const JiraComment(id: 'c1'),
        onSearchUsers: (_) async => const <JiraUser>[],
      ),
    );

    await tester.pumpWidget(page);
    await tester.pumpAndSettle();
    const afterFirstLoad = 1;
    expect(loadCount, afterFirstLoad);

    // Window hidden (minimized / backgrounded): polling pauses to spare cost.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    await tester.pump(const Duration(seconds: 65));
    await tester.pump();
    expect(loadCount, afterFirstLoad);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('off interval runs no poll timer', (tester) async {
    const ticket = JiraTicket(
      key: 'HEI-7',
      summary: 'Watch the bridge',
      statusName: 'To Do',
      statusCategory: 'new',
      issueType: 'Task',
    );
    var loadCount = 0;
    final page = MaterialApp(
      home: TicketDetailPage(
        initial: ticket,
        baseUrl: 'https://example.atlassian.net',
        refreshInterval: RefreshInterval.off,
        onLoad: () async {
          loadCount++;
          return const JiraIssue(ticket: ticket);
        },
        onLoadTransitions: () async => const <JiraTransition>[],
        onApplyTransition: (_) async {},
        onLoadComments: () async => const <JiraComment>[],
        onPostComment: (_) async => const JiraComment(id: 'c1'),
        onSearchUsers: (_) async => const <JiraUser>[],
      ),
    );

    await tester.pumpWidget(page);
    await tester.pumpAndSettle();
    const afterFirstLoad = 1;
    expect(loadCount, afterFirstLoad);

    // No timer is armed, so time passing never reloads the issue.
    await tester.pump(const Duration(seconds: 120));
    await tester.pump();
    expect(loadCount, afterFirstLoad);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a custom interval drives the poll cadence', (tester) async {
    const ticket = JiraTicket(
      key: 'HEI-7',
      summary: 'Watch the bridge',
      statusName: 'To Do',
      statusCategory: 'new',
      issueType: 'Task',
    );
    var loadCount = 0;
    final page = MaterialApp(
      home: TicketDetailPage(
        initial: ticket,
        baseUrl: 'https://example.atlassian.net',
        refreshInterval: RefreshInterval.tenSeconds,
        onLoad: () async {
          loadCount++;
          return const JiraIssue(ticket: ticket);
        },
        onLoadTransitions: () async => const <JiraTransition>[],
        onApplyTransition: (_) async {},
        onLoadComments: () async => const <JiraComment>[],
        onPostComment: (_) async => const JiraComment(id: 'c1'),
        onSearchUsers: (_) async => const <JiraUser>[],
      ),
    );

    await tester.pumpWidget(page);
    await tester.pumpAndSettle();
    const afterFirstLoad = 1;
    expect(loadCount, afterFirstLoad);

    // The 60s default would not have fired yet; the 10s cadence does.
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    const afterPoll = 2;
    expect(loadCount, afterPoll);

    await tester.pumpWidget(const SizedBox());
  });
}
