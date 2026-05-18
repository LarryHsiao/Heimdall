import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jql_value_suggestions.dart';

void main() {
  group('parseJqlValueSuggestions', () {
    test('reads value strings from a full payload', () {
      const expected = ['Aragorn', 'Boromir'];

      final actual = parseJqlValueSuggestions({
        'results': [
          {'value': 'Aragorn', 'displayName': 'Aragorn (Aragorn)'},
          {'value': 'Boromir', 'displayName': 'Boromir'},
        ],
      });

      expect(actual, expected);
    });

    test('returns an empty list when the body is null', () {
      const expected = <String>[];

      final actual = parseJqlValueSuggestions(null);

      expect(actual, expected);
    });

    test('returns an empty list when results is absent', () {
      const expected = <String>[];

      final actual = parseJqlValueSuggestions(const {});

      expect(actual, expected);
    });

    test('drops entries that are not maps with a string value', () {
      const expected = ['Aragorn'];

      final actual = parseJqlValueSuggestions({
        'results': [
          {'value': 'Aragorn'},
          {'displayName': 'No value'},
          'not a map',
          {'value': 42},
        ],
      });

      expect(actual, expected);
    });
  });
}
