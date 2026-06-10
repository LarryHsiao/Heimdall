import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/filters.dart';
import '../data/jira.dart';
import '../data/jira_credentials.dart';
import '../data/jira_filter.dart';
import '../data/jira_ticket.dart';
import '../data/vault.dart';
import 'status_chip.dart';

const String epicTypeName = 'Epic';

class AddTicketPage extends StatefulWidget {
  const AddTicketPage({super.key});

  @override
  State<AddTicketPage> createState() => _AddTicketPageState();
}

class _AddTicketPageState extends State<AddTicketPage> {
  static final RegExp _keyPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*-\d+$');
  static const double _previewKeyColumnWidth = 88;
  static const Duration _previewDebounce = Duration(milliseconds: 500);

  final Filters _filters = Filters();
  final Vault _vault = Vault();
  final Jira _jira = Jira();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController;
  late final TextEditingController _nameController;
  bool _includeChildren = false;
  bool _saving = false;
  Timer? _previewTimer;
  int _previewSeq = 0;
  bool _previewLoading = false;
  String? _previewError;
  List<JiraTicket> _previewTickets = const [];
  String? _previewQuery;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
    _nameController = TextEditingController();
    _keyController.addListener(_schedulePreview);
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _keyController.removeListener(_schedulePreview);
    _keyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _validKey => _keyPattern.hasMatch(_keyController.text.trim());

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(_previewDebounce, _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    final key = _keyController.text.trim();
    if (!_keyPattern.hasMatch(key)) {
      if (!mounted) return;
      setState(() {
        _previewLoading = false;
        _previewError = null;
        _previewTickets = const [];
        _previewQuery = null;
      });
      return;
    }
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
        _previewQuery = key;
      });
      return;
    }
    try {
      final jql = await _composedJql(key, credentials);
      if (!mounted || seq != _previewSeq) return;
      final filter = JiraFilter(id: '_preview', name: '_preview', query: jql);
      final tickets = await _jira.tickets(filter, credentials);
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _previewLoading = false;
        _previewTickets = tickets;
        _previewQuery = key;
      });
    } catch (e) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        _previewLoading = false;
        _previewError = _previewMessage(e);
        _previewTickets = const [];
        _previewQuery = key;
      });
    }
  }

  Future<String> _composedJql(String key, JiraCredentials credentials) async {
    final self = 'issuekey = $key';
    if (!_includeChildren) {
      return self;
    }
    final isEpic = await _isEpic(key, credentials);
    return '$self OR (${childrenJql(key, isEpic: isEpic)})';
  }

  Future<bool> _isEpic(String key, JiraCredentials credentials) async {
    final probe = JiraFilter(id: '_probe', name: '_probe', query: 'issuekey = $key');
    final tickets = await _jira.tickets(probe, credentials);
    if (tickets.isEmpty) return false;
    return tickets.first.issueType == epicTypeName;
  }

  String _previewMessage(Object error) {
    final raw = error.toString();
    return raw.length > 240 ? '${raw.substring(0, 240)}…' : raw;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_validKey) return;
    setState(() => _saving = true);
    final key = _keyController.text.trim();
    final credentials = await _vault.read();
    if (credentials == null) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _previewError = 'No credentials configured — open Settings to add one.';
      });
      return;
    }
    final jql = await _composedJql(key, credentials);
    final filter = JiraFilter(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      query: jql,
    );
    await _filters.add(filter);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String? _validateKey(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Required';
    }
    if (!_keyPattern.hasMatch(trimmed)) {
      return 'Enter a valid ticket key, e.g. HEI-6';
    }
    return null;
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
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
        'Type a ticket key above to see what will be added.',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add ticket')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _keyController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Ticket key',
                  hintText: 'HEI-6',
                ),
                validator: _validateKey,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Include direct children'),
                value: _includeChildren,
                onChanged: (v) {
                  setState(() => _includeChildren = v ?? false);
                  _schedulePreview();
                },
              ),
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: _keyController,
                builder: (context, _) => FilledButton(
                  onPressed: (_saving || !_validKey) ? null : _save,
                  child: const Text('Save'),
                ),
              ),
              _preview(),
            ],
          ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
