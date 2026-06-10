import 'package:flutter/material.dart';

import '../data/appearance.dart';
import '../data/jira_credentials.dart';
import '../data/refresh_interval.dart';
import '../data/refresh_timer.dart';
import '../data/vault.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Vault _vault = Vault();
  final _formKey = GlobalKey<FormState>();
  final _baseUrlController = TextEditingController();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final existing = await _vault.read();
    if (existing != null) {
      _baseUrlController.text = existing.baseUrl;
      _emailController.text = existing.email;
      _tokenController.text = existing.apiToken;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final credentials = JiraCredentials(
      baseUrl: _baseUrlController.text.trim(),
      email: _emailController.text.trim(),
      apiToken: _tokenController.text.trim(),
    );
    await _vault.save(credentials);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _appearanceRow() {
    final appearance = AppearanceScope.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('System'),
              icon: Icon(Icons.brightness_auto_outlined),
            ),
          ],
          selected: {appearance.mode},
          onSelectionChanged: (selection) =>
              appearance.setMode(selection.first),
        ),
      ],
    );
  }

  Widget _refreshRow() {
    final timer = RefreshTimerScope.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Refresh', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<RefreshInterval>(
          segments: const [
            ButtonSegment(
              value: RefreshInterval.tenSeconds,
              label: Text('10s'),
            ),
            ButtonSegment(
              value: RefreshInterval.thirtySeconds,
              label: Text('30s'),
            ),
            ButtonSegment(
              value: RefreshInterval.oneMinute,
              label: Text('1m'),
            ),
            ButtonSegment(
              value: RefreshInterval.fiveMinutes,
              label: Text('5m'),
            ),
            ButtonSegment(
              value: RefreshInterval.off,
              label: Text('Off'),
            ),
          ],
          selected: {timer.interval},
          onSelectionChanged: (selection) =>
              timer.setInterval(selection.first),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _form(),
    );
  }

  Widget _form() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://your-org.atlassian.net',
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: 'API Token'),
              obscureText: true,
              validator: _required,
            ),
            const SizedBox(height: 24),
            _appearanceRow(),
            const SizedBox(height: 24),
            _refreshRow(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
