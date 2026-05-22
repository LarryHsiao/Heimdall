import '../data/jira_ticket.dart';

const Duration kPulseWindow = Duration(seconds: 10);
const Duration _purgeSlack = Duration(milliseconds: 500);

bool ticketChanged(JiraTicket previous, JiraTicket current) =>
    previous.summary != current.summary ||
    previous.statusName != current.statusName ||
    previous.statusCategory != current.statusCategory ||
    previous.assignee != current.assignee ||
    previous.priority != current.priority ||
    previous.issueType != current.issueType ||
    previous.parentKey != current.parentKey;

double pulseAlpha({
  required DateTime at,
  required DateTime now,
  required Duration window,
}) {
  final elapsedMs = now.difference(at).inMilliseconds;
  if (elapsedMs <= 0) return 1.0;
  if (elapsedMs >= window.inMilliseconds) return 0.0;
  return 1.0 - elapsedMs / window.inMilliseconds;
}

Map<String, DateTime> nextPulses({
  required List<JiraTicket> previous,
  required List<JiraTicket> current,
  required Map<String, DateTime> existing,
  required DateTime now,
  required Duration window,
}) {
  final purgeCutoff = now.subtract(window + _purgeSlack);
  final result = <String, DateTime>{
    for (final entry in existing.entries)
      if (entry.value.isAfter(purgeCutoff)) entry.key: entry.value,
  };
  final byKey = {for (final t in previous) t.key: t};
  for (final ticket in current) {
    final prior = byKey[ticket.key];
    if (prior == null || ticketChanged(prior, ticket)) {
      result[ticket.key] = now;
    }
  }
  return result;
}
