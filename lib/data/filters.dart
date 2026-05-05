import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'jira_filter.dart';

class Filters {
  static const _key = 'configured_filters';

  Future<List<JiraFilter>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => JiraFilter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<JiraFilter> filters) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(filters.map((f) => f.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  Future<void> add(JiraFilter filter) async {
    final current = await read();
    await save([...current, filter]);
  }

  Future<void> remove(String id) async {
    final current = await read();
    await save(current.where((f) => f.id != id).toList());
  }

  Future<void> update(JiraFilter filter) async {
    final current = await read();
    await save(
      current.map((f) => f.id == filter.id ? filter : f).toList(),
    );
  }
}
