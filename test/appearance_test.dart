import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heimdall/data/appearance.dart';
import 'package:heimdall/data/preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('readThemeMode returns ThemeMode.system when nothing is persisted', () async {
    final prefs = Preferences();
    final expected = ThemeMode.system;

    final actual = await prefs.readThemeMode();

    expect(actual, expected);
  });

  test('Appearance.setMode notifies listeners and persists the choice', () async {
    final prefs = Preferences();
    final appearance = Appearance(prefs, ThemeMode.system);
    final expected = ThemeMode.dark;
    var notified = 0;
    appearance.addListener(() => notified += 1);

    await appearance.setMode(expected);

    expect(appearance.mode, expected);
    expect(notified, 1);
    expect(await Preferences().readThemeMode(), expected);
  });

  test('Appearance.setMode is a no-op when the mode is unchanged', () async {
    final prefs = Preferences();
    final appearance = Appearance(prefs, ThemeMode.light);
    final expected = 0;
    var notified = 0;
    appearance.addListener(() => notified += 1);

    await appearance.setMode(ThemeMode.light);

    expect(notified, expected);
  });
}
