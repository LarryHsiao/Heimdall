import 'package:flutter_test/flutter_test.dart';
import 'package:heimdall/data/jql_context.dart';

void main() {
  group('jqlContextAt', () {
    test('empty text yields field-name context with empty partial', () {
      const expectedField = '';
      const expectedPartial = '';

      final ctx = jqlContextAt('', 0);

      expect(ctx.fieldName, expectedField);
      expect(ctx.partial, expectedPartial);
      expect(ctx.isValueContext, false);
    });

    test('plain word at cursor is a field-name partial', () {
      const expectedPartial = 'assi';

      final ctx = jqlContextAt('assi', 4);

      expect(ctx.isValueContext, false);
      expect(ctx.partial, expectedPartial);
    });

    test('cursor right after = is a value context with empty partial', () {
      const expectedField = 'assignee';
      const expectedPartial = '';

      final ctx = jqlContextAt('assignee =', 10);

      expect(ctx.isValueContext, true);
      expect(ctx.fieldName, expectedField);
      expect(ctx.partial, expectedPartial);
    });

    test('cursor after = then space yields value context, empty partial', () {
      const expectedField = 'assignee';
      const expectedPartial = '';

      final ctx = jqlContextAt('assignee = ', 11);

      expect(ctx.isValueContext, true);
      expect(ctx.fieldName, expectedField);
      expect(ctx.partial, expectedPartial);
    });

    test('partial value after operator yields field plus the partial', () {
      const expectedField = 'assignee';
      const expectedPartial = 'curr';

      final ctx = jqlContextAt('assignee = curr', 15);

      expect(ctx.isValueContext, true);
      expect(ctx.fieldName, expectedField);
      expect(ctx.partial, expectedPartial);
    });

    test('multi-character operator != surfaces value context', () {
      const expectedField = 'summary';
      const expectedPartial = 'abc';

      final ctx = jqlContextAt('summary != abc', 14);

      expect(ctx.isValueContext, true);
      expect(ctx.fieldName, expectedField);
      expect(ctx.partial, expectedPartial);
    });

    test('contains operator ~ surfaces value context', () {
      const expectedField = 'summary';
      const expectedPartial = 'pay';

      final ctx = jqlContextAt('summary ~ pay', 13);

      expect(ctx.isValueContext, true);
      expect(ctx.fieldName, expectedField);
      expect(ctx.partial, expectedPartial);
    });

    test('cursor before any operator stays in field-name context', () {
      const expectedField = '';
      const expectedPartial = 'summary';

      final ctx = jqlContextAt('summary', 7);

      expect(ctx.isValueContext, false);
      expect(ctx.fieldName, expectedField);
      expect(ctx.partial, expectedPartial);
    });

    test('cursor after whitespace alone yields empty partial, no field',
        () {
      const expectedField = '';
      const expectedPartial = '';

      final ctx = jqlContextAt('summary ', 8);

      expect(ctx.isValueContext, false);
      expect(ctx.fieldName, expectedField);
      expect(ctx.partial, expectedPartial);
    });
  });
}
