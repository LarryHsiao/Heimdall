import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'view_settings.dart';

class Preferences {
  static const _key = 'view_settings';

  Future<ViewSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const ViewSettings();
    }
    return ViewSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(ViewSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
