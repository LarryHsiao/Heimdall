import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heimdall/data/preferences.dart';
import 'package:heimdall/data/refresh_interval.dart';
import 'package:heimdall/data/refresh_timer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('readRefreshInterval returns oneMinute when nothing is persisted',
      () async {
    final prefs = Preferences();
    final expected = RefreshInterval.oneMinute;

    final actual = await prefs.readRefreshInterval();

    expect(actual, expected);
  });

  test('RefreshTimer.setInterval notifies listeners and persists the choice',
      () async {
    final prefs = Preferences();
    final timer = RefreshTimer(prefs, RefreshInterval.oneMinute);
    final expected = RefreshInterval.tenSeconds;
    var notified = 0;
    timer.addListener(() => notified += 1);

    await timer.setInterval(expected);

    expect(timer.interval, expected);
    expect(notified, 1);
    expect(await Preferences().readRefreshInterval(), expected);
  });

  test('RefreshTimer.setInterval is a no-op when the interval is unchanged',
      () async {
    final prefs = Preferences();
    final timer = RefreshTimer(prefs, RefreshInterval.fiveMinutes);
    final expected = 0;
    var notified = 0;
    timer.addListener(() => notified += 1);

    await timer.setInterval(RefreshInterval.fiveMinutes);

    expect(notified, expected);
  });
}
