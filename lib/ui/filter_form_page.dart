import 'package:flutter/material.dart';

import '../data/filters.dart';
import '../data/jira_filter.dart';

class FilterFormPage extends StatefulWidget {
  final JiraFilter? existing;

  const FilterFormPage({super.key, this.existing});

  @override
  State<FilterFormPage> createState() => _FilterFormPageState();
}

class _FilterFormPageState extends State<FilterFormPage> {
  final Filters _filters = Filters();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _queryController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _queryController =
        TextEditingController(text: widget.existing?.query ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _queryController.dispose();
    super.dispose();
  }

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
