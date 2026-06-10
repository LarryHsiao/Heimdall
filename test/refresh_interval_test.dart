import 'package:flutter_test/flutter_test.dart';

import 'package:heimdall/data/refresh_interval.dart';

void main() {
  test('each preset carries the cadence it names', () {
    final expected = <RefreshInterval, Duration?>{
      RefreshInterval.tenSeconds: const Duration(seconds: 10),
      RefreshInterval.thirtySeconds: const Duration(seconds: 30),
      RefreshInterval.oneMinute: const Duration(seconds: 60),
      RefreshInterval.fiveMinutes: const Duration(minutes: 5),
    };

    for (final entry in expected.entries) {
      expect(entry.key.duration, entry.value);
    }
  });

  test('off carries no duration', () {
    const Duration? expected = null;

    final actual = RefreshInterval.off.duration;

    expect(actual, expected);
  });
}
