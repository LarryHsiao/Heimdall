import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/view_settings.dart';

void main() {
  group('ViewSettings subtasksExpanded', () {
    test('defaults to false', () {
      const expected = false;
      const settings = ViewSettings();
      expect(settings.subtasksExpanded, expected);
    });

    test('copyWith overrides the flag', () {
      const expected = true;
      const base = ViewSettings();
      final next = base.copyWith(subtasksExpanded: true);
      expect(next.subtasksExpanded, expected);
    });

    test('copyWith preserves the flag when omitted', () {
      const expected = true;
      const base = ViewSettings(subtasksExpanded: true);
      final next = base.copyWith(mode: ViewMode.flat);
      expect(next.subtasksExpanded, expected);
    });

    test('survives a json round-trip', () {
      const expected = true;
      const settings = ViewSettings(subtasksExpanded: true);
      final restored = ViewSettings.fromJson(settings.toJson());
      expect(restored.subtasksExpanded, expected);
    });

    test('fromJson falls back to false when the key is absent', () {
      const expected = false;
      final restored = ViewSettings.fromJson({'mode': 'grouped'});
      expect(restored.subtasksExpanded, expected);
    });
  });

  group('ViewSettings cycledBy', () {
    test('tapping an inactive column sorts it ascending', () {
      const expected = ViewSettings(column: SortColumn.key, ascending: true);
      const base = ViewSettings();
      final next = base.cycledBy(SortColumn.key);
      expect(next.column, expected.column);
      expect(next.ascending, expected.ascending);
    });

    test('tapping the active ascending column flips to descending', () {
      const expected = ViewSettings(column: SortColumn.key, ascending: false);
      const base = ViewSettings(column: SortColumn.key, ascending: true);
      final next = base.cycledBy(SortColumn.key);
      expect(next.column, expected.column);
      expect(next.ascending, expected.ascending);
    });

    test('tapping the active descending column releases to server order', () {
      const expected = SortColumn.none;
      const base = ViewSettings(column: SortColumn.key, ascending: false);
      final next = base.cycledBy(SortColumn.key);
      expect(next.column, expected);
    });

    test('tapping a different column while one is active sorts it ascending',
        () {
      const expected = ViewSettings(column: SortColumn.status, ascending: true);
      const base = ViewSettings(column: SortColumn.key, ascending: false);
      final next = base.cycledBy(SortColumn.status);
      expect(next.column, expected.column);
      expect(next.ascending, expected.ascending);
    });
  });
}
