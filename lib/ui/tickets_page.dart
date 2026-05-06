import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/filters.dart';
import '../data/jira.dart';
import '../data/jira_credentials.dart';
import '../data/jira_filter.dart';
import '../data/jira_ticket.dart';
import '../data/preferences.dart';
import '../data/vault.dart';
import '../data/view_settings.dart';
import 'filter_form_page.dart';
import 'filters_page.dart';
import 'settings_page.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  final Vault _vault = Vault();
  final Filters _filters = Filters();
  final Preferences _preferences = Preferences();
  final Jira _jira = Jira();

  ViewSettings _settings = const ViewSettings();
  late Future<_PageState> _state;

  @override
  void initState() {
    super.initState();
    _state = _bootstrap();
  }

  Future<_PageState> _bootstrap() async {
    _settings = await _preferences.read();
    return _load();
  }

  void _refresh() {
    setState(() {
      _state = _load();
    });
  }

  Future<_PageState> _load() async {
    final credentials = await _vault.read();
    final filters = await _filters.read();
    if (credentials == null || filters.isEmpty) {
      return _PageState(credentials: credentials, sections: const []);
    }
    final sections = <FilterSection>[];
    for (final filter in filters) {
      sections.add(await _section(filter, credentials));
    }
    return _PageState(credentials: credentials, sections: sections);
  }

  Future<FilterSection> _section(
    JiraFilter filter,
    JiraCredentials credentials,
  ) async {
    try {
      final tickets = await _jira.tickets(filter, credentials);
      return FilterSection(filter: filter, tickets: tickets);
    } catch (e) {
      return FilterSection(
        filter: filter,
        tickets: const [],
        error: '$e',
      );
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    _refresh();
  }

  Future<void> _openFilters() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FiltersPage()),
    );
    _refresh();
  }

  Future<void> _addFilter() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FilterFormPage()),
    );
    if (result == true) {
      _refresh();
    }
  }

  Future<void> _openTicket(
    JiraCredentials credentials,
    JiraTicket ticket,
  ) async {
    final base = credentials.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/browse/${ticket.key}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _toggleMode() {
    final next = _settings.mode == ViewMode.grouped
        ? ViewMode.flat
        : ViewMode.grouped;
    _writeSettings(_settings.copyWith(mode: next));
  }

  void _onSort(SortColumn column, bool ascending) {
    _writeSettings(_settings.copyWith(column: column, ascending: ascending));
  }

  void _writeSettings(ViewSettings next) {
    setState(() {
      _settings = next;
    });
    _preferences.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _settings.mode == ViewMode.grouped;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heimdall'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: grouped ? 'Switch to flat' : 'Switch to grouped',
            onPressed: _toggleMode,
            icon: Icon(
              grouped ? Icons.account_tree_outlined : Icons.view_list_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: _openFilters,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: FutureBuilder<_PageState>(
        future: _state,
        builder: (_, snapshot) => _bodyOf(snapshot),
      ),
    );
  }

  Widget _bodyOf(AsyncSnapshot<_PageState> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    final data = snapshot.data;
    if (data == null) {
      return const SizedBox.shrink();
    }
    if (data.credentials == null) {
      return _Empty(
        message: 'No credentials configured.',
        actionLabel: 'Open settings',
        onAction: _openSettings,
      );
    }
    if (data.sections.isEmpty) {
      return _Empty(
        message: 'No filters yet.',
        actionLabel: 'Add filter',
        onAction: _addFilter,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView.builder(
        itemCount: data.sections.length,
        itemBuilder: (_, i) => _SectionView(
          section: data.sections[i],
          settings: _settings,
          onSort: _onSort,
          onTicketTap: (t) => _openTicket(data.credentials!, t),
        ),
      ),
    );
  }
}

class _PageState {
  final JiraCredentials? credentials;
  final List<FilterSection> sections;

  const _PageState({required this.credentials, required this.sections});
}

class FilterSection {
  final JiraFilter filter;
  final List<JiraTicket> tickets;
  final String? error;

  const FilterSection({
    required this.filter,
    required this.tickets,
    this.error,
  });
}

class _Row {
  final JiraTicket ticket;
  final bool indented;
  final bool parentCaption;
  final bool parentInList;

  const _Row({
    required this.ticket,
    required this.indented,
    required this.parentCaption,
    required this.parentInList,
  });
}

class _Empty extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _Empty({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _SectionView extends StatefulWidget {
  final FilterSection section;
  final ViewSettings settings;
  final void Function(SortColumn column, bool ascending) onSort;
  final ValueChanged<JiraTicket> onTicketTap;

  const _SectionView({
    required this.section,
    required this.settings,
    required this.onSort,
    required this.onTicketTap,
  });

  @override
  State<_SectionView> createState() => _SectionViewState();
}

class _SectionViewState extends State<_SectionView> {
  String? _hoveredKey;

  FilterSection get section => widget.section;
  ViewSettings get settings => widget.settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            section.filter.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ..._content(context),
        const Divider(height: 24),
      ],
    );
  }

  List<Widget> _content(BuildContext context) {
    if (section.error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            section.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ];
    }
    if (section.tickets.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('No tickets.'),
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _table(context),
      ),
    ];
  }

  Widget _table(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _arrange(section.tickets);
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: FlexColumnWidth(),
        3: IntrinsicColumnWidth(),
        4: IntrinsicColumnWidth(),
        5: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(width: 0.5, color: theme.dividerColor),
      ),
      children: [
        _headerRow(theme),
        ...rows.map((r) => _bodyRow(r, theme)),
      ],
    );
  }

  TableRow _headerRow(ThemeData theme) {
    return TableRow(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
      children: [
        _headerCell('Type', SortColumn.type),
        _headerCell('Key', SortColumn.key),
        _headerCell('Summary', SortColumn.summary),
        _headerCell('Pri', SortColumn.priority),
        _headerCell('Assignee', SortColumn.assignee),
        _headerCell('Status', SortColumn.status),
      ],
    );
  }

  Widget _headerCell(String label, SortColumn column) {
    final active = settings.column == column;
    return InkWell(
      onTap: () =>
          widget.onSort(column, active ? !settings.ascending : true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Opacity(
              opacity: active ? 1 : 0,
              child: Icon(
                settings.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Row> _arrange(List<JiraTicket> tickets) {
    final keys = tickets.map((t) => t.key).toSet();
    if (settings.mode == ViewMode.flat) {
      return _sorted(tickets)
          .map(
            (t) => _Row(
              ticket: t,
              indented: false,
              parentCaption: t.parentKey.isNotEmpty,
              parentInList: keys.contains(t.parentKey),
            ),
          )
          .toList();
    }
    return _grouped(tickets, keys);
  }

  List<_Row> _grouped(List<JiraTicket> tickets, Set<String> keys) {
    final tops = <JiraTicket>[];
    final children = <String, List<JiraTicket>>{};
    for (final t in tickets) {
      if (t.parentKey.isNotEmpty && keys.contains(t.parentKey)) {
        children.putIfAbsent(t.parentKey, () => []).add(t);
      } else {
        tops.add(t);
      }
    }
    final rows = <_Row>[];
    for (final t in _sorted(tops)) {
      final orphan = t.parentKey.isNotEmpty;
      rows.add(_Row(
        ticket: t,
        indented: false,
        parentCaption: orphan,
        parentInList: false,
      ));
      for (final c in _sorted(children[t.key] ?? const <JiraTicket>[])) {
        rows.add(_Row(
          ticket: c,
          indented: true,
          parentCaption: false,
          parentInList: true,
        ));
      }
    }
    return rows;
  }

  List<JiraTicket> _sorted(List<JiraTicket> tickets) {
    if (settings.column == SortColumn.none) return tickets;
    final list = [...tickets];
    list.sort((a, b) {
      final cmp = _compare(a, b, settings.column);
      return settings.ascending ? cmp : -cmp;
    });
    return list;
  }

  int _compare(JiraTicket a, JiraTicket b, SortColumn col) {
    switch (col) {
      case SortColumn.type:
        return a.issueType.compareTo(b.issueType);
      case SortColumn.key:
        return _keyCompare(a.key, b.key);
      case SortColumn.summary:
        return a.summary.toLowerCase().compareTo(b.summary.toLowerCase());
      case SortColumn.priority:
        return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
      case SortColumn.assignee:
        return _emptyLast(a.assignee).compareTo(_emptyLast(b.assignee));
      case SortColumn.status:
        return _statusRank(a.statusCategory)
            .compareTo(_statusRank(b.statusCategory));
      case SortColumn.none:
        return 0;
    }
  }

  int _keyCompare(String a, String b) {
    final ai = a.indexOf('-');
    final bi = b.indexOf('-');
    if (ai < 0 || bi < 0) return a.compareTo(b);
    final pcmp = a.substring(0, ai).compareTo(b.substring(0, bi));
    if (pcmp != 0) return pcmp;
    final an = int.tryParse(a.substring(ai + 1)) ?? 0;
    final bn = int.tryParse(b.substring(bi + 1)) ?? 0;
    return an.compareTo(bn);
  }

  int _priorityRank(String p) {
    switch (p.toLowerCase()) {
      case 'highest':
        return 0;
      case 'high':
        return 1;
      case 'medium':
        return 2;
      case 'low':
        return 3;
      case 'lowest':
        return 4;
      default:
        return 5;
    }
  }

  int _statusRank(String c) {
    switch (c.toLowerCase()) {
      case 'to do':
      case 'new':
        return 0;
      case 'in progress':
      case 'indeterminate':
        return 1;
      case 'done':
      case 'complete':
        return 2;
      default:
        return 3;
    }
  }

  String _emptyLast(String s) => s.isEmpty ? '\u{FFFF}' : s.toLowerCase();

  TableRow _bodyRow(_Row row, ThemeData theme) {
    final t = row.ticket;
    final hovered = _hoveredKey == t.key;
    return TableRow(
      decoration: BoxDecoration(
        color: hovered ? theme.colorScheme.surfaceContainerHigh : null,
      ),
      children: [
        _bodyCell(t, _typeCell(row)),
        _bodyCell(t, Text(t.key)),
        _bodyCell(t, _summaryCell(t, row.parentCaption, theme)),
        _bodyCell(t, Text(t.priority.isEmpty ? '—' : t.priority)),
        _bodyCell(t, Text(t.assignee.isEmpty ? '—' : t.assignee)),
        _bodyCell(t, Chip(label: Text(t.statusName))),
      ],
    );
  }

  Widget _bodyCell(JiraTicket t, Widget child) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredKey = t.key),
        onExit: (_) => setState(() {
          if (_hoveredKey == t.key) _hoveredKey = null;
        }),
        child: GestureDetector(
          onTap: () => widget.onTicketTap(t),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _typeCell(_Row row) {
    final t = row.ticket;
    final orphanSub = _isSubtask(t.issueType) && !row.parentInList;
    final icon = orphanSub ? Icons.check_box_outlined : _iconOf(t.issueType);
    return Padding(
      padding: EdgeInsets.only(left: row.indented ? 24 : 0),
      child: Tooltip(
        message: t.issueType,
        child: Icon(icon, size: 18),
      ),
    );
  }

  bool _isSubtask(String type) {
    final t = type.toLowerCase();
    return t == 'sub-task' || t == 'subtask';
  }

  Widget _summaryCell(JiraTicket t, bool showCaption, ThemeData theme) {
    final summary = Text(
      t.summary,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
    if (!showCaption) return summary;
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        summary,
        Text(
          '↳ ${t.parentKey} · ${t.parentSummary}',
          style: caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  IconData _iconOf(String type) {
    switch (type.toLowerCase()) {
      case 'bug':
        return Icons.bug_report_outlined;
      case 'story':
        return Icons.bookmark_outline;
      case 'task':
        return Icons.check_box_outlined;
      case 'epic':
        return Icons.flag_outlined;
      case 'sub-task':
      case 'subtask':
        return Icons.subdirectory_arrow_right;
      default:
        return Icons.circle_outlined;
    }
  }
}
