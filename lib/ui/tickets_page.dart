import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/filters.dart';
import '../data/jira.dart';
import '../data/jira_credentials.dart';
import '../data/jira_filter.dart';
import '../data/jira_ticket.dart';
import '../data/vault.dart';
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
  final Jira _jira = Jira();

  late Future<_PageState> _state;

  @override
  void initState() {
    super.initState();
    _state = _load();
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

  @override
  Widget build(BuildContext context) {
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

class _SectionView extends StatelessWidget {
  final FilterSection section;
  final ValueChanged<JiraTicket> onTicketTap;

  const _SectionView({required this.section, required this.onTicketTap});

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
    return section.tickets
        .map(
          (t) => ListTile(
            dense: true,
            title: Text('${t.key} · ${t.summary}'),
            trailing: Chip(label: Text(t.statusName)),
            onTap: () => onTicketTap(t),
          ),
        )
        .toList();
  }
}
