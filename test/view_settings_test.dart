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
}
