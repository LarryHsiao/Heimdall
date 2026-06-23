import 'jira_filter.dart';

/// Matches a trailing `ORDER BY ...` clause, which JQL permits only at the very
/// end of a query — never nested inside a parenthesised sub-clause.
final _orderByTail = RegExp(r'\s+ORDER\s+BY\s+.*$', caseSensitive: false);

/// Composes a query that adds a single issue to an existing filter's JQL:
/// `(<where>) OR issuekey = KEY`, or bare `issuekey = KEY` when the filter's
/// resolved JQL is empty. Any trailing `ORDER BY` clause on the filter's JQL is
/// lifted to the tail of the whole query, so the result stays valid JQL.
/// Composes from the resolved [JiraFilter.jql], never the raw stored query.
class JqlWithIssue {
  const JqlWithIssue(this._filter, this._key);

  final JiraFilter _filter;
  final String _key;

  String value() {
    final jql = _filter.jql;
    if (jql.isEmpty) {
      return 'issuekey = $_key';
    }
    final order = _orderByTail.firstMatch(jql);
    if (order == null) {
      return '($jql) OR issuekey = $_key';
    }
    final where = jql.substring(0, order.start);
    return '($where) OR issuekey = $_key ${order.group(0)!.trim()}';
  }
}
