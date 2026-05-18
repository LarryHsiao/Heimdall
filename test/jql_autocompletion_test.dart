import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jql_autocompletion.dart';

void main() {
  group('JqlAutocompletion.fromJson', () {
    test('reads visible field names from the value attribute', () {
      const expected = ['summary', 'assignee'];

      final actual = JqlAutocompletion.fromJson({
        'visibleFieldNames': [
          {'value': 'summary', 'displayName': 'Summary'},
          {'value': 'assignee', 'displayName': 'Assignee'},
        ],
      }).fieldNames;

      expect(actual, expected);
    });

    test('reads visible function names from the value attribute', () {
      const expected = ['currentUser()', 'now()'];

      final actual = JqlAutocompletion.fromJson({
        'visibleFunctionNames': [
          {'value': 'currentUser()'},
          {'value': 'now()'},
        ],
      }).functionNames;

      expect(actual, expected);
    });

    test('reads jql reserved words as a plain string list', () {
      const expected = ['and', 'or', 'not'];

      final actual = JqlAutocompletion.fromJson({
        'jqlReservedWords': ['and', 'or', 'not'],
      }).reservedWords;

      expect(actual, expected);
    });

    test('defaults each list to empty when its key is absent', () {
      const expected = <String>[];

      final result = JqlAutocompletion.fromJson(const {});

      expect(result.fieldNames, expected);
      expect(result.functionNames, expected);
      expect(result.reservedWords, expected);
    });

    test('drops entries that are not maps with a string value', () {
      const expected = ['summary'];

      final actual = JqlAutocompletion.fromJson({
        'visibleFieldNames': [
          {'value': 'summary'},
          {'displayName': 'No value'},
          'not a map',
          {'value': 42},
        ],
      }).fieldNames;

      expect(actual, expected);
    });

    test('suggestions concatenates fields, functions, and reserved words',
        () {
      const expected = ['assignee', 'currentUser()', 'and'];

      final actual = JqlAutocompletion.fromJson({
        'visibleFieldNames': [
          {'value': 'assignee'}
        ],
        'visibleFunctionNames': [
          {'value': 'currentUser()'}
        ],
        'jqlReservedWords': ['and'],
      }).suggestions;

      expect(actual, expected);
    });
  });
}
