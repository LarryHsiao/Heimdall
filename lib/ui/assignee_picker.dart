import 'dart:async';

import 'package:flutter/material.dart';

import '../data/jira_user.dart';

class AssigneeChoice {
  final JiraUser? user;

  const AssigneeChoice(this.user);

  bool get isUnassigned => user == null;
}

Future<AssigneeChoice?> showAssigneePicker(
  BuildContext context, {
  required String ticketKey,
  required String currentAssignee,
  required Future<List<JiraUser>> Function(String query) onLoad,
}) {
  return showDialog<AssigneeChoice>(
    context: context,
    builder: (_) => AssigneePickerDialog(
      ticketKey: ticketKey,
      currentAssignee: currentAssignee,
      onLoad: onLoad,
    ),
  );
}

class AssigneePickerDialog extends StatefulWidget {
  final String ticketKey;
  final String currentAssignee;
  final Future<List<JiraUser>> Function(String query) onLoad;

  const AssigneePickerDialog({
    super.key,
    required this.ticketKey,
    required this.currentAssignee,
    required this.onLoad,
  });

  @override
  State<AssigneePickerDialog> createState() => _AssigneePickerDialogState();
}

class _AssigneePickerDialogState extends State<AssigneePickerDialog> {
  static const Duration _debounceWindow = Duration(milliseconds: 250);

  List<JiraUser>? _users;
  String? _error;
  bool _loading = true;
  String _query = '';
  int _fetchToken = 0;
  Timer? _debounce;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(_debounceWindow, () => _load(value));
  }

  Future<void> _load(String query) async {
    final token = ++_fetchToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.onLoad(query);
      if (!mounted || token != _fetchToken) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _fetchToken) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const Divider(height: 1),
            _searchField(),
            const Divider(height: 1),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Change assignee', style: theme.textTheme.titleMedium),
                if (widget.ticketKey.isNotEmpty)
                  Text(
                    widget.ticketKey,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.search, size: 18),
          hintText: 'Search by name or email',
          border: OutlineInputBorder(),
        ),
        onChanged: _onQueryChanged,
      ),
    );
  }

  Widget _body() {
    if (_users == null && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _errorBody();
    }
    final users = _users ?? const <JiraUser>[];
    return Column(
      children: [
        SizedBox(
          height: 2,
          child: _loading ? const LinearProgressIndicator() : null,
        ),
        Expanded(
          child: ListView(
            children: [
              _unassignedTile(),
              const Divider(height: 1),
              if (users.isEmpty) _emptyTile() else
                for (final u in users) _userTile(u),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Error: $_error'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _load(_query),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _unassignedTile() {
    final selected = widget.currentAssignee.isEmpty;
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: const Text('(Unassigned)'),
      selected: selected,
      onTap: () =>
          Navigator.of(context).pop(const AssigneeChoice(null)),
    );
  }

  Widget _userTile(JiraUser u) {
    final selected = u.displayName == widget.currentAssignee;
    final email = u.emailAddress;
    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(u.displayName.isEmpty ? u.accountId : u.displayName),
      subtitle: email.isEmpty ? null : Text(email),
      selected: selected,
      onTap: () => Navigator.of(context).pop(AssigneeChoice(u)),
    );
  }

  Widget _emptyTile() {
    final theme = Theme.of(context);
    final message =
        _query.trim().isEmpty ? 'No assignable users.' : 'No matches.';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: TextStyle(
          color: theme.colorScheme.outline,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
