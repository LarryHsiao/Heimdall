import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'refresh_interval.dart';
import 'view_settings.dart';

class Preferences {
  static const _viewKey = 'view_settings';
  static const _themeKey = 'theme_mode';
  static const _refreshKey = 'refresh_interval';

  Future<ViewSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_viewKey);
    if (raw == null || raw.isEmpty) {
      return const ViewSettings();
    }
    return ViewSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(ViewSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewKey, jsonEncode(settings.toJson()));
  }

  Future<ThemeMode> readThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<RefreshInterval> readRefreshInterval() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_refreshKey);
    return RefreshInterval.values.firstWhere(
      (i) => i.name == raw,
      orElse: () => RefreshInterval.oneMinute,
    );
  }

  Future<void> saveRefreshInterval(RefreshInterval interval) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshKey, interval.name);
  }
}
