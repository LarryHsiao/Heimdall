import 'package:flutter/material.dart';

import 'preferences.dart';

class Appearance extends ChangeNotifier {
  Appearance(this._prefs, this._mode);

  final Preferences _prefs;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode next) async {
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    await _prefs.saveThemeMode(next);
  }
}

class AppearanceScope extends InheritedNotifier<Appearance> {
  const AppearanceScope({
    super.key,
    required Appearance super.notifier,
    required super.child,
  });

  static Appearance of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
    assert(scope != null, 'AppearanceScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
