import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'jira_credentials.dart';

class Vault {
  static const _key = 'jira_credentials';

  final FlutterSecureStorage _storage;

  Vault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<JiraCredentials?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return JiraCredentials.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  Future<void> save(JiraCredentials credentials) async {
    await _storage.write(
      key: _key,
      value: jsonEncode(credentials.toJson()),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
