import 'jira_filter.dart';

/// Composes a query that adds a single issue to an existing filter's JQL:
/// `(<filter.jql>) OR issuekey = KEY`, or bare `issuekey = KEY` when the
/// filter's resolved JQL is empty. Composes from the resolved [JiraFilter.jql],
/// never the raw stored query.
class JqlWithIssue {
  const JqlWithIssue(this._filter, this._key);

  final JiraFilter _filter;
  final String _key;

  String value() {
    final jql = _filter.jql;
    if (jql.isEmpty) {
      return 'issuekey = $_key';
    }
    return '($jql) OR issuekey = $_key';
  }
}
