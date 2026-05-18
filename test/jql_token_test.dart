import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jql_token.dart';

void main() {
  group('lastTokenAt', () {
    test('returns empty string when text is empty', () {
      const expected = '';
      final actual = lastTokenAt('', 0);
      expect(actual, expected);
    });

    test('returns empty string when cursor sits at offset zero', () {
      const expected = '';
      final actual = lastTokenAt('summary', 0);
      expect(actual, expected);
    });

    test('returns the partial word up to the cursor', () {
      const expected = 'assi';
      final actual = lastTokenAt('assignee', 4);
      expect(actual, expected);
    });

    test('stops at whitespace before the cursor', () {
      const expected = 'curr';
      final actual = lastTokenAt('assignee = curr', 15);
      expect(actual, expected);
    });

    test('returns empty when cursor sits right after an operator', () {
      const expected = '';
      final actual = lastTokenAt('assignee =', 10);
      expect(actual, expected);
    });

    test('stops at parenthesis before the cursor', () {
      const expected = '';
      final actual = lastTokenAt('currentUser(', 12);
      expect(actual, expected);
    });

    test('returns the whole word when no stops precede the cursor', () {
      const expected = 'currentUser';
      final actual = lastTokenAt('currentUser', 11);
      expect(actual, expected);
    });
  });
}
