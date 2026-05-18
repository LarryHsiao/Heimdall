import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jira_filter.dart';
import 'package:heimdall/data/jira_ticket.dart';
import 'package:heimdall/ui/tickets_page.dart';

JiraTicket _ticket({
  required String key,
  String summary = '',
  String statusName = 'To Do',
  String statusCategory = 'new',
  String issueType = 'Task',
  String assignee = '',
}) {
  return JiraTicket(
    key: key,
    summary: summary,
    statusName: statusName,
    statusCategory: statusCategory,
    issueType: issueType,
    assignee: assignee,
  );
}

FilterSection _section({
  List<JiraTicket>? tickets,
  List<JiraTicket>? allTickets,
  String? error,
}) {
  return FilterSection(
    filter: const JiraFilter(id: '1', name: 'F', query: 'jql'),
    tickets: tickets ?? const <JiraTicket>[],
    allTickets: allTickets,
    error: error,
  );
}

void main() {
  group('FilterSection.withTicketPatched', () {
    test('patches the matching ticket in tickets', () {
      const expected = 'Done';
      final source = _section(
        tickets: [_ticket(key: 'HEI-1'), _ticket(key: 'HEI-2')],
      );

      final result = source.withTicketPatched(
        'HEI-1',
        (t) => _ticket(key: t.key, statusName: 'Done', statusCategory: 'done'),
      );

      expect(result.tickets[0].statusName, expected);
      expect(result.tickets[1].statusName, 'To Do');
    });

    test('patches the same ticket in allTickets when it has diverged', () {
      const expected = 'Done';
      final source = _section(
        tickets: [_ticket(key: 'HEI-1')],
        allTickets: [_ticket(key: 'HEI-1'), _ticket(key: 'HEI-2')],
      );

      final result = source.withTicketPatched(
        'HEI-1',
        (t) => _ticket(key: t.key, statusName: 'Done', statusCategory: 'done'),
      );

      expect(result.allTickets[0].statusName, expected);
      expect(result.allTickets[1].statusName, 'To Do');
    });

    test('leaves the section unchanged when no key matches', () {
      const expected = ['To Do', 'To Do'];
      final source = _section(
        tickets: [_ticket(key: 'HEI-1'), _ticket(key: 'HEI-2')],
      );

      final result = source.withTicketPatched(
        'HEI-99',
        (t) => _ticket(key: t.key, statusName: 'Done'),
      );

      final actual = result.tickets.map((t) => t.statusName).toList();
      expect(actual, expected);
    });

    test('preserves filter id and error metadata', () {
      const expectedFilterId = '42';
      const expectedError = 'transient';
      final source = FilterSection(
        filter: const JiraFilter(id: '42', name: 'X', query: 'jql'),
        tickets: [_ticket(key: 'HEI-1')],
        error: 'transient',
      );

      final result = source.withTicketPatched(
        'HEI-1',
        (t) => _ticket(key: t.key, statusName: 'Done'),
      );

      expect(result.filter.id, expectedFilterId);
      expect(result.error, expectedError);
    });
  });
}
