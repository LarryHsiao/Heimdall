import 'dart:async';

import 'package:flutter/material.dart';

import '../data/filters.dart';
import '../data/jira.dart';
import '../data/jira_filter.dart';
import '../data/jira_ticket.dart';
import '../data/jql_autocompletion.dart';
import '../data/jql_context.dart';
import '../data/vault.dart';
import 'status_chip.dart';

class FilterFormPage extends StatefulWidget {
  final JiraFilter? existing;

  const FilterFormPage({super.key, this.existing});

  @override
  State<FilterFormPage> createState() => _FilterFormPageState();
}

class _FilterFormPageState extends State<FilterFormPage> {
  static const int _maxSuggestions = 10;
  static const double _previewKeyColumnWidth = 88;
  static const Duration _valueDebounce = Duration(milliseconds: 300);
  static const Duration _previewDebounce = Duration(milliseconds: 500);
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
  Timer? _previewTimer;
  // Preview lacks a per-query cache, so concurrent fetches must be ordered
  // by sequence rather than the per-key single-flight used by value suggestions.
  int _previewSeq = 0;
  bool _previewLoading = false;
  String? _previewError;
  List<JiraTicket> _previewTickets = const [];
  String? _previewQuery;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _queryController =
        TextEditingController(text: widget.existing?.query ?? '');
    _queryController.addListener(_onQueryChanged);
    _loadAutocompletion();
    if (_queryController.text.trim().isNotEmpty) {
      _schedulePreview();
    }
  }

  @override
  void dispose() {
    _valueTimer?.cancel();
    _previewTimer?.cancel();
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
    _schedulePreview();
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

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(_previewDebounce, _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    final trimmed = _queryController.text.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _previewError = null;
        _previewTickets = const [];
        _previewQuery = null;
      });
      return;
    }
    if (trimmed == _previewQuery && _previewError == null) return;
    final seq = ++_previewSeq;
    setState(() {
      _previewLoading = true;
      _previewError = null;
    });
    final credentials = await _vault.read();
    if (!mounted || seq != _previewSeq) return;
    if (credentials == null) {
      setState(() {
        _previewLoading = false;
        _previewError = 'No credentials configured — open Settings to add one.';
        _previewTickets = const [];
        _previewQuery = trimmed;
      });
      return;
    }
    final filter = JiraFilter(id: '_preview', name: '_preview', query: trimmed);
    try {
      final tickets = await _jira.tickets(filter, credentials);
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _previewLoading = false;
        _previewTickets = tickets;
        _previewQuery = trimmed;
      });
    } catch (e) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _previewLoading = false;
        _previewError = _previewMessage(e);
        _previewTickets = const [];
        _previewQuery = trimmed;
      });
    }
  }

  String _previewMessage(Object error) {
    final raw = error.toString();
    return raw.length > 240 ? '${raw.substring(0, 240)}…' : raw;
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

  Widget _preview() {
    final theme = Theme.of(context);
    final header = Row(
      children: [
        Text('Preview', style: theme.textTheme.titleSmall),
        const Spacer(),
        if (_previewLoading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_previewError == null && _previewQuery != null)
          Text(
            '${_previewTickets.length} ticket'
            '${_previewTickets.length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        header,
        const SizedBox(height: 8),
        _previewBody(theme),
      ],
    );
  }

  Widget _previewBody(ThemeData theme) {
    if (_previewError != null) {
      return Text(
        _previewError!,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      );
    }
    if (_previewQuery == null) {
      return Text(
        'Type a filter ID or JQL above to see matching tickets.',
        style: theme.textTheme.bodySmall,
      );
    }
    if (_previewLoading && _previewTickets.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_previewTickets.isEmpty) {
      return Text('No matches.', style: theme.textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in _previewTickets) _previewRow(t),
      ],
    );
  }

  Widget _previewRow(JiraTicket ticket) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: _previewKeyColumnWidth,
            child: Text(
              ticket.key,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(status: ticket.statusName),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ticket.summary,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit filter' : 'Add filter')),
      body: SingleChildScrollView(
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
              _preview(),
            ],
          ),
        ),
      ),
    );
  }
}
