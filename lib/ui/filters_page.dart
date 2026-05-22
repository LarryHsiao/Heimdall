import 'package:flutter/material.dart';

import '../data/filters.dart';
import '../data/jira_filter.dart';
import 'filter_form_page.dart';

class FiltersPage extends StatefulWidget {
  const FiltersPage({super.key});

  @override
  State<FiltersPage> createState() => _FiltersPageState();
}

class _FiltersPageState extends State<FiltersPage> {
  final Filters _filters = Filters();
  late Future<List<JiraFilter>> _list;

  @override
  void initState() {
    super.initState();
    _list = _filters.read();
  }

  void _refresh() {
    setState(() {
      _list = _filters.read();
    });
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FilterFormPage()),
    );
    if (result == true) {
      _refresh();
    }
  }

  Future<void> _edit(JiraFilter filter) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FilterFormPage(existing: filter),
      ),
    );
    if (result == true) {
      _refresh();
    }
  }

  Future<void> _delete(JiraFilter filter) async {
    await _filters.remove(filter.id);
    _refresh();
  }

  Future<void> _confirmDelete(JiraFilter filter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _deleteDialog(ctx, filter),
    );
    if (confirmed == true) {
      await _delete(filter);
    }
  }

  Widget _deleteDialog(BuildContext ctx, JiraFilter filter) {
    final scheme = Theme.of(ctx).colorScheme;
    return AlertDialog(
      title: const Text('Delete filter?'),
      content: Text('"${filter.name}" will be removed.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Filters')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<JiraFilter>>(
        future: _list,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final filters = snapshot.data ?? const <JiraFilter>[];
          if (filters.isEmpty) {
            return const Center(child: Text('No filters yet.'));
          }
          return ListView.builder(
            itemCount: filters.length,
            itemBuilder: (_, i) => _row(filters[i]),
          );
        },
      ),
    );
  }

  Widget _row(JiraFilter filter) {
    return ListTile(
      title: Text(filter.name),
      subtitle: Text(filter.query),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmDelete(filter),
      ),
      onTap: () => _edit(filter),
    );
  }
}
