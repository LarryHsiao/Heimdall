import 'dart:async';

import 'package:flutter/material.dart';

import '../data/filters.dart';
import '../data/jira.dart';
import '../data/jira_filter.dart';
import '../data/jql_autocompletion.dart';
import '../data/jql_context.dart';
import '../data/vault.dart';

class FilterFormPage extends StatefulWidget {
  final JiraFilter? existing;

  const FilterFormPage({super.key, this.existing});

  @override
  State<FilterFormPage> createState() => _FilterFormPageState();
}

class _FilterFormPageState extends State<FilterFormPage> {
  static const int _maxSuggestions = 10;
  static const Duration _valueDebounce = Duration(milliseconds: 300);
  static const JqlAutocompletion _emptyAutocompletion = JqlAutocompletion(
    fieldNames: [],
    functionNames: [],
    reservedWords: [],
  );

  final Filters _filters = Filters();
  final Vault _vault = Vault();
  final Jira _jira = Jira();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _queryController;
  bool _saving = false;
  JqlAutocompletion _autocompletion = _emptyAutocompletion;
  final Map<String, List<String>> _valueCache = {};
  Timer? _valueTimer;
  String? _inflightValueKey;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _queryController =
        TextEditingController(text: widget.existing?.query ?? '');
    _queryController.addListener(_onQueryChanged);
    _loadAutocompletion();
  }

  @override
  void dispose() {
    _valueTimer?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _nameController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadAutocompletion() async {
    try {
      final credentials = await _vault.read();
      if (credentials == null) return;
      final loaded = await _jira.jqlAutocomplete(credentials);
      if (!mounted) return;
      setState(() => _autocompletion = loaded);
    } catch (_) {
      // Quiet failure — autocomplete is a nicety, not a requirement.
    }
  }

  void _onQueryChanged() {
    final selection = _queryController.selection;
    if (!selection.isValid || selection.start != selection.end) {
      _valueTimer?.cancel();
      return;
    }
    final ctx = jqlContextAt(_queryController.text, selection.start);
    if (!ctx.isValueContext) {
      _valueTimer?.cancel();
      return;
    }
    _valueTimer?.cancel();
    _valueTimer = Timer(
      _valueDebounce,
      () => _fetchValueSuggestions(ctx.fieldName, ctx.partial),
    );
  }

  Future<void> _fetchValueSuggestions(String field, String partial) async {
    final key = _cacheKey(field, partial);
    if (_valueCache.containsKey(key)) return;
    final credentials = await _vault.read();
    if (credentials == null) return;
    _inflightValueKey = key;
    try {
      final results =
          await _jira.jqlValueSuggestions(credentials, field, partial);
      if (!mounted) return;
      setState(() {
        _valueCache[key] = results;
      });
    } catch (_) {
      // Quiet failure.
    } finally {
      if (_inflightValueKey == key) {
        _inflightValueKey = null;
      }
    }
  }

  String _cacheKey(String field, String partial) => '$field|$partial';

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final filter = JiraFilter(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      query: _queryController.text.trim(),
    );
    if (widget.existing == null) {
      await _filters.add(filter);
    } else {
      await _filters.update(filter);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  void _insertSuggestion(String suggestion, String partial) {
    final selection = _queryController.selection;
    if (!selection.isValid) return;
    final cursor = selection.start;
    final text = _queryController.text;
    final prefix = text.substring(0, cursor - partial.length);
    final suffix = text.substring(cursor);
    final newCursor = (prefix + suggestion).length;
    _queryController.value = TextEditingValue(
      text: '$prefix$suggestion$suffix',
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  List<String> _fieldMatchesFor(String partial) {
    if (partial.isEmpty) return const [];
    final lower = partial.toLowerCase();
    return _autocompletion.suggestions
        .where((s) {
          final v = s.toLowerCase();
          return v.startsWith(lower) && v != lower;
        })
        .take(_maxSuggestions)
        .toList();
  }

  List<String> _valueMatchesFor(String field, String partial) {
    final cached = _valueCache[_cacheKey(field, partial)];
    if (cached == null) return const [];
    final lower = partial.toLowerCase();
    return cached
        .where((s) => s.toLowerCase() != lower)
        .take(_maxSuggestions)
        .toList();
  }

  Widget _suggestions() {
    return ListenableBuilder(
      listenable: _queryController,
      builder: (context, _) {
        final selection = _queryController.selection;
        if (!selection.isValid || selection.start != selection.end) {
          return const SizedBox.shrink();
        }
        final ctx = jqlContextAt(_queryController.text, selection.start);
        final matches = ctx.isValueContext
            ? _valueMatchesFor(ctx.fieldName, ctx.partial)
            : _fieldMatchesFor(ctx.partial);
        if (matches.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in matches)
                ActionChip(
                  label: Text(m),
                  onPressed: () => _insertSuggestion(m, ctx.partial),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit filter' : 'Add filter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _queryController,
                decoration: const InputDecoration(
                  labelText: 'Filter ID or JQL',
                  hintText:
                      '10363  or  assignee = currentUser() AND resolution = Unresolved',
                ),
                maxLines: 3,
                validator: _required,
              ),
              _suggestions(),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
