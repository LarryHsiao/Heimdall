import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/adf.dart';
import '../data/jira_issue.dart';
import '../data/jira_ticket.dart';
import '../data/jira_transition.dart';
import 'ticket_chrome.dart';

class TicketDetailPage extends StatefulWidget {
  final JiraTicket initial;
  final String baseUrl;
  final Future<JiraIssue> Function() onLoad;
  final Future<List<JiraTransition>> Function() onLoadTransitions;
  final Future<void> Function(JiraTransition) onApplyTransition;

  const TicketDetailPage({
    super.key,
    required this.initial,
    required this.baseUrl,
    required this.onLoad,
    required this.onLoadTransitions,
    required this.onApplyTransition,
  });

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  JiraIssue? _issue;
  bool _loading = true;
  String? _error;

  late JiraTicket _ticket;

  @override
  void initState() {
    super.initState();
    _ticket = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final issue = await widget.onLoad();
      if (!mounted) return;
      setState(() {
        _issue = issue;
        _ticket = issue.ticket;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _openInBrowser() async {
    final base = widget.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/browse/${_ticket.key}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ticket.key),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_new),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _issue == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _issue == null) {
      return Center(child: Text('Error: $_error'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          const SizedBox(height: 16),
          _metaBar(context),
          const SizedBox(height: 16),
          _people(context),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _description(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 12),
          child: Tooltip(
            message: _ticket.issueType,
            child: Icon(_ticket.typeIcon, size: 24),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_ticket.key, style: theme.textTheme.bodySmall),
              Text(
                _ticket.summary,
                style: theme.textTheme.headlineSmall,
              ),
              if (_ticket.parentKey.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '↳ ${_ticket.parentKey} · ${_ticket.parentSummary}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaBar(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _statusPill(theme),
        _chip(theme, _ticket.issueType),
        if (_ticket.priority.isNotEmpty)
          _chip(
            theme,
            _ticket.priority,
            icon: _ticket.priorityIcon,
            iconColor: _ticket.priorityColor,
          ),
      ],
    );
  }

  Widget _statusPill(ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _onStatusTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _ticket.statusName.isEmpty ? '—' : _ticket.statusName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    ThemeData theme,
    String label, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
    );
  }

  Widget _people(BuildContext context) {
    final theme = Theme.of(context);
    final issue = _issue;
    final reporter = issue?.reporter ?? '';
    final created = _date(issue?.created);
    final updated = _date(issue?.updated);
    final assignee = _ticket.assignee.isEmpty ? '—' : _ticket.assignee;
    return DefaultTextStyle.merge(
      style: theme.textTheme.bodyMedium ?? const TextStyle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(theme, 'Assignee', assignee),
          if (reporter.isNotEmpty) _kv(theme, 'Reporter', reporter),
          if (created.isNotEmpty || updated.isNotEmpty)
            _kv(
              theme,
              'Dates',
              [
                if (created.isNotEmpty) 'Created $created',
                if (updated.isNotEmpty) 'Updated $updated',
              ].join(' · '),
            ),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              key,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _date(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final t = raw.indexOf('T');
    return t > 0 ? raw.substring(0, t) : raw;
  }

  Widget _description(BuildContext context) {
    final theme = Theme.of(context);
    final markdown = AdfMarkdown(_issue?.description).text();
    if (markdown.isEmpty) {
      return Text(
        'No description.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return MarkdownBody(
      data: markdown,
      selectable: true,
      onTapLink: (_, href, _) {
        if (href == null || href.isEmpty) return;
        launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
      },
    );
  }

  Future<void> _onStatusTap() async {
    final messenger = ScaffoldMessenger.of(context);
    List<JiraTransition> transitions;
    try {
      transitions = await widget.onLoadTransitions();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Load failed: $e')));
      return;
    }
    if (!mounted) return;
    if (transitions.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No transitions available.')),
      );
      return;
    }
    final sorted = [...transitions]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selectedId = await showMenu<String>(
      context: context,
      position: _menuPosition(context),
      items: sorted
          .map((tr) => PopupMenuItem<String>(
                value: tr.id,
                child: Text(tr.name),
              ))
          .toList(),
    );
    if (selectedId == null) return;
    final selected = transitions.firstWhere((tr) => tr.id == selectedId);
    try {
      await widget.onApplyTransition(selected);
      if (!mounted) return;
      setState(() {
        _ticket = JiraTicket(
          key: _ticket.key,
          summary: _ticket.summary,
          statusName: selected.toStatus.isEmpty
              ? _ticket.statusName
              : selected.toStatus,
          statusCategory: selected.toStatusCategory.isEmpty
              ? _ticket.statusCategory
              : selected.toStatusCategory,
          issueType: _ticket.issueType,
          priority: _ticket.priority,
          assignee: _ticket.assignee,
          parentKey: _ticket.parentKey,
          parentSummary: _ticket.parentSummary,
        );
      });
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Transition failed: $e')),
      );
    }
  }

  RelativeRect _menuPosition(BuildContext context) {
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return const RelativeRect.fromLTRB(0, 0, 0, 0);
    }
    final size = overlay.size;
    return RelativeRect.fromLTRB(48, 120, size.width - 240, 0);
  }
}
