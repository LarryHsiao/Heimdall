import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/filters.dart';
import '../data/jira.dart';
import '../data/jira_credentials.dart';
import '../data/jira_filter.dart';
import '../data/jira_ticket.dart';
import '../data/jira_transition.dart';
import '../data/preferences.dart';
import '../data/vault.dart';
import '../data/view_settings.dart';
import 'filter_form_page.dart';
import 'filters_page.dart';
import 'settings_page.dart';
import 'ticket_chrome.dart';
import 'ticket_detail_page.dart';

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
  String? _assigneeFilter;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  _PageState? _data;
  bool _loading = true;
  String? _loadError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _settings = await _preferences.read();
    await _doLoad();
  }

  Future<void> _refresh() async => _doLoad();

  Future<void> _doLoad() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await _load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
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

  void _patchTicketStatus(
    String key,
    String newStatus,
    String newStatusCategory,
  ) {
    final data = _data;
    if (data == null) return;
    final sections = data.sections.map((s) {
      final tickets = s.tickets.map((t) {
        if (t.key != key) return t;
        return JiraTicket(
          key: t.key,
          summary: t.summary,
          statusName: newStatus.isEmpty ? t.statusName : newStatus,
          statusCategory:
              newStatusCategory.isEmpty ? t.statusCategory : newStatusCategory,
          issueType: t.issueType,
          priority: t.priority,
          assignee: t.assignee,
          parentKey: t.parentKey,
          parentSummary: t.parentSummary,
        );
      }).toList();
      return FilterSection(
        filter: s.filter,
        tickets: tickets,
        error: s.error,
      );
    }).toList();
    setState(() {
      _data = _PageState(credentials: data.credentials, sections: sections);
    });
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

  Future<void> _openDetail(
    JiraCredentials credentials,
    JiraTicket ticket,
  ) async {
    final auth = base64Encode(
      utf8.encode('${credentials.email}:${credentials.apiToken}'),
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketDetailPage(
          initial: ticket,
          baseUrl: credentials.baseUrl,
          imageHeaders: {'Authorization': 'Basic $auth'},
          onLoad: () => _jira.issue(ticket, credentials),
          onLoadTransitions: () => _loadTransitions(ticket),
          onApplyTransition: (tr) => _applyTransition(ticket, tr),
          onLoadComments: () => _jira.comments(ticket, credentials),
          onPostComment: (text) =>
              _jira.postComment(ticket, text, credentials),
        ),
      ),
    );
  }

  Future<List<JiraTransition>> _loadTransitions(JiraTicket ticket) async {
    final cred = await _vault.read();
    if (cred == null) return const [];
    return _jira.transitions(ticket, cred);
  }

  Future<void> _applyTransition(JiraTicket ticket, JiraTransition tr) async {
    final cred = await _vault.read();
    if (cred == null) return;
    await _jira.transition(ticket, tr.id, cred);
    _patchTicketStatus(ticket.key, tr.toStatus, tr.toStatusCategory);
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

  void _onColumnWidthChange(SortColumn column, double width) {
    _writeSettings(_settings.setWidth(column, width));
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
            tooltip: 'Open ticket by key',
            onPressed: _openByKey,
            icon: const Icon(Icons.tag),
          ),
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
      body: _bodyOf(),
    );
  }

  Widget _bodyOf() {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _data == null) {
      return Center(child: Text('Error: $_loadError'));
    }
    final data = _data;
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
    final options = _assigneesOf(data.sections);
    if (!_isFilterValid(options)) {
      _assigneeFilter = null;
    }
    final filtered = _filterSections(data.sections, _assigneeFilter, _search);
    final keyId = filtered.map((s) => s.filter.id).join(',');
    return DefaultTabController(
      key: ValueKey(keyId),
      length: filtered.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: filtered
                        .map((s) => Tab(text: s.filter.name))
                        .toList(),
                  ),
                ),
                _searchField(),
                if (options.named.isNotEmpty || options.hasUnassigned)
                  _quickFilters(options),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: filtered
                  .map(
                    (s) => SingleChildScrollView(
                      child: _SectionView(
                        section: s,
                        settings: _settings,
                        onSort: _onSort,
                        onColumnWidthChange: _onColumnWidthChange,
                        onTicketTap: (t) =>
                            _openDetail(data.credentials!, t),
                        onLoadTransitions: _loadTransitions,
                        onApplyTransition: _applyTransition,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  _AssigneeOptions _assigneesOf(List<FilterSection> sections) {
    final all = sections.expand((s) => s.tickets).map((t) => t.assignee);
    final hasUnassigned = all.any((a) => a.isEmpty);
    final named = all.where((a) => a.isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _AssigneeOptions(named: named, hasUnassigned: hasUnassigned);
  }

  bool _isFilterValid(_AssigneeOptions options) {
    if (_assigneeFilter == null) return true;
    if (_assigneeFilter == '') return options.hasUnassigned;
    return options.named.contains(_assigneeFilter);
  }

  List<FilterSection> _filterSections(
    List<FilterSection> sections,
    String? assignee,
    String search,
  ) {
    final q = search.trim();
    if (assignee == null && q.isEmpty) return sections;
    return sections
        .map(
          (s) => FilterSection(
            filter: s.filter,
            tickets: s.tickets
                .where((t) =>
                    (assignee == null || t.assignee == assignee) &&
                    t.matchesSearch(q))
                .toList(),
            error: s.error,
          ),
        )
        .toList();
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
      child: SizedBox(
        width: 220,
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: 'Search…',
            border: const OutlineInputBorder(),
            suffixIcon: _search.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _openByKey() async {
    final credentials = _data?.credentials;
    if (credentials == null) return;
    final controller = TextEditingController();
    try {
      final key = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Open ticket by key'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'e.g. PSG-1234',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Open'),
            ),
          ],
        ),
      );
      if (key == null || key.isEmpty) return;
      final stub = JiraTicket(
        key: key.toUpperCase(),
        summary: '',
        statusName: '',
        statusCategory: '',
        issueType: '',
      );
      if (!mounted) return;
      await _openDetail(credentials, stub);
    } finally {
      controller.dispose();
    }
  }

  Widget _quickFilters(_AssigneeOptions options) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 18),
          const SizedBox(width: 8),
          DropdownButton<String?>(
            value: _assigneeFilter,
            hint: const Text('All assignees'),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All assignees'),
              ),
              if (options.hasUnassigned)
                const DropdownMenuItem<String?>(
                  value: '',
                  child: Text('(Unassigned)'),
                ),
              for (final a in options.named)
                DropdownMenuItem<String?>(value: a, child: Text(a)),
            ],
            onChanged: (v) => setState(() => _assigneeFilter = v),
          ),
        ],
      ),
    );
  }
}

class _AssigneeOptions {
  final List<String> named;
  final bool hasUnassigned;

  const _AssigneeOptions({required this.named, required this.hasUnassigned});
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
  final void Function(SortColumn column, double width) onColumnWidthChange;
  final ValueChanged<JiraTicket> onTicketTap;
  final Future<List<JiraTransition>> Function(JiraTicket) onLoadTransitions;
  final Future<void> Function(JiraTicket, JiraTransition) onApplyTransition;

  const _SectionView({
    required this.section,
    required this.settings,
    required this.onSort,
    required this.onColumnWidthChange,
    required this.onTicketTap,
    required this.onLoadTransitions,
    required this.onApplyTransition,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _content(context),
      ),
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
      columnWidths: {
        0: FixedColumnWidth(settings.widthOf(SortColumn.type)),
        1: FixedColumnWidth(settings.widthOf(SortColumn.key)),
        2: const FlexColumnWidth(),
        3: FixedColumnWidth(settings.widthOf(SortColumn.priority)),
        4: FixedColumnWidth(settings.widthOf(SortColumn.assignee)),
        5: FixedColumnWidth(settings.widthOf(SortColumn.status)),
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
        _headerCell(theme, 'Type', SortColumn.type, resizable: true),
        _headerCell(theme, 'Key', SortColumn.key, resizable: true),
        _headerCell(theme, 'Summary', SortColumn.summary, resizable: false),
        _headerCell(theme, 'Pri', SortColumn.priority, resizable: true),
        _headerCell(theme, 'Assignee', SortColumn.assignee, resizable: true),
        _headerCell(theme, 'Status', SortColumn.status, resizable: true),
      ],
    );
  }

  Widget _headerCell(
    ThemeData theme,
    String label,
    SortColumn column, {
    required bool resizable,
  }) {
    return Row(
      children: [
        Expanded(child: _headerLabel(label, column)),
        if (resizable) _resizeHandle(theme, column),
      ],
    );
  }

  Widget _headerLabel(String label, SortColumn column) {
    final active = settings.column == column;
    return InkWell(
      onTap: () =>
          widget.onSort(column, active ? !settings.ascending : true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            const SizedBox(width: 2),
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

  Widget _resizeHandle(ThemeData theme, SortColumn column) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          final next =
              (settings.widthOf(column) + details.delta.dx).clamp(40.0, 400.0);
          widget.onColumnWidthChange(column, next);
        },
        child: SizedBox(
          width: 12,
          child: Center(
            child: Container(
              width: 2,
              height: 20,
              color: theme.colorScheme.outlineVariant,
            ),
          ),
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
        _bodyCell(t, _priorityCell(t)),
        _bodyCell(t, Text(t.assignee.isEmpty ? '—' : t.assignee)),
        _bodyCell(
          t,
          Text(t.statusName, overflow: TextOverflow.ellipsis),
          onTapWithContext: (ctx) => _onStatusTap(ctx, t),
        ),
      ],
    );
  }

  Widget _bodyCell(
    JiraTicket t,
    Widget child, {
    void Function(BuildContext)? onTapWithContext,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hoveredKey = t.key),
        onExit: (_) => setState(() {
          if (_hoveredKey == t.key) _hoveredKey = null;
        }),
        child: Builder(
          builder: (cellCtx) => GestureDetector(
            onTap: () => onTapWithContext != null
                ? onTapWithContext(cellCtx)
                : widget.onTicketTap(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onStatusTap(BuildContext context, JiraTicket t) async {
    final messenger = ScaffoldMessenger.of(context);
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    List<JiraTransition> transitions;
    try {
      transitions = await widget.onLoadTransitions(t);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Load failed: $e')));
      return;
    }
    if (!context.mounted) return;
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
      position: position,
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
      await widget.onApplyTransition(t, selected);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Transition failed: $e')),
      );
    }
  }

  Widget _typeCell(_Row row) {
    final t = row.ticket;
    final orphanSub = t.isSubtask && !row.parentInList;
    final icon = orphanSub ? Icons.check_box_outlined : t.typeIcon;
    return Padding(
      padding: EdgeInsets.only(left: row.indented ? 24 : 0),
      child: Tooltip(
        message: t.issueType,
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _priorityCell(JiraTicket t) {
    if (t.priority.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: t.priority,
      child: Icon(
        t.priorityIcon,
        color: t.priorityColor,
        size: 18,
      ),
    );
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

}
