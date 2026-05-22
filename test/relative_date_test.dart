import 'package:flutter_test/flutter_test.dart';

import 'package:heimdall/ui/relative_date.dart';

void main() {
  // Local DateTime so calendar-day comparisons are TZ-independent in tests.
  final now = DateTime(2026, 5, 22, 14, 0, 0);
  final nowUtc = DateTime.utc(2026, 5, 22, 14, 0, 0);

  group('relativeDate — duration branches', () {
    test('null returns empty string', () {
      const expected = '';
      expect(relativeDate(null, now: nowUtc), expected);
    });

    test('empty string returns empty', () {
      const expected = '';
      expect(relativeDate('', now: nowUtc), expected);
    });

    test('under one minute renders "just now"', () {
      final raw = nowUtc.subtract(const Duration(seconds: 30)).toIso8601String();
      const expected = 'just now';
      expect(relativeDate(raw, now: nowUtc), expected);
    });

    test('under one hour renders "Xm ago"', () {
      final raw = nowUtc.subtract(const Duration(minutes: 5)).toIso8601String();
      const expected = '5m ago';
      expect(relativeDate(raw, now: nowUtc), expected);
    });

    test('under one day renders "Xh ago"', () {
      final raw = nowUtc.subtract(const Duration(hours: 3)).toIso8601String();
      const expected = '3h ago';
      expect(relativeDate(raw, now: nowUtc), expected);
    });

    test('Jira ISO format with offset parses correctly', () {
      const raw = '2026-05-22T13:55:00.000+0000';
      const expected = '5m ago';
      expect(relativeDate(raw, now: nowUtc), expected);
    });

    test('malformed string falls back to the raw value', () {
      const raw = '2024-not-a-date';
      const expected = '2024-not-a-date';
      expect(relativeDate(raw, now: nowUtc), expected);
    });

    test('future timestamp falls back to ISO date', () {
      final raw = nowUtc.add(const Duration(days: 1)).toIso8601String();
      const expected = '2026-05-23';
      expect(relativeDate(raw, now: nowUtc), expected);
    });
  });

  group('relativeDate — calendar-day branches', () {
    test('one calendar day ago renders "yesterday"', () {
      final raw = DateTime(2026, 5, 21, 14, 0, 0).toIso8601String();
      const expected = 'yesterday';
      expect(relativeDate(raw, now: now), expected);
    });

    test('two calendar days ago renders "2d ago"', () {
      final raw = DateTime(2026, 5, 20, 14, 0, 0).toIso8601String();
      const expected = '2d ago';
      expect(relativeDate(raw, now: now), expected);
    });

    test('six calendar days ago renders "6d ago"', () {
      final raw = DateTime(2026, 5, 16, 14, 0, 0).toIso8601String();
      const expected = '6d ago';
      expect(relativeDate(raw, now: now), expected);
    });

    test('seven calendar days or older falls back to ISO date', () {
      final raw = DateTime(2026, 5, 8, 14, 0, 0).toIso8601String();
      const expected = '2026-05-08';
      expect(relativeDate(raw, now: now), expected);
    });

    test('25h delta crossing two calendar boundaries renders "2d ago"', () {
      // The debt this fix exists for: a 25h wall-clock delta that crosses two
      // calendar midnights — posted at 23:30 two days back, viewed at 00:30 today —
      // should read "2d ago", not "yesterday".
      final clock = DateTime(2026, 5, 22, 0, 30, 0);
      final raw = DateTime(2026, 5, 20, 23, 30, 0).toIso8601String();
      const expected = '2d ago';
      expect(relativeDate(raw, now: clock), expected);
    });
  });
}
