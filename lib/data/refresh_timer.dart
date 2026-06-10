import 'package:flutter/material.dart';

import 'preferences.dart';
import 'refresh_interval.dart';

class RefreshTimer extends ChangeNotifier {
  RefreshTimer(this._prefs, this._interval);

  final Preferences _prefs;
  RefreshInterval _interval;

  RefreshInterval get interval => _interval;

  Future<void> setInterval(RefreshInterval next) async {
    if (next == _interval) return;
    _interval = next;
    notifyListeners();
    await _prefs.saveRefreshInterval(next);
  }
}

class RefreshTimerScope extends InheritedNotifier<RefreshTimer> {
  const RefreshTimerScope({
    super.key,
    required RefreshTimer super.notifier,
    required super.child,
  });

  static RefreshTimer of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<RefreshTimerScope>();
    assert(scope != null, 'RefreshTimerScope is missing from the widget tree');
    return scope!.notifier!;
  }
}
