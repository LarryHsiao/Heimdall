import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heimdall/data/jira_filter.dart';
import 'package:heimdall/ui/add_ticket_page.dart';

Future<void> _pumpAddTicketPage(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: AddTicketPage()));
  await tester.pumpAndSettle();
}

bool _saveEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(find.byType(FilledButton));
  return button.onPressed != null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AddTicketPage save gating', () {
    testWidgets('the save button is disabled until a valid key is entered',
        (tester) async {
      await _pumpAddTicketPage(tester);

      final keyField = find.widgetWithText(TextFormField, 'Ticket key');

      const expectedInitiallyEnabled = false;
      expect(_saveEnabled(tester), expectedInitiallyEnabled);

      await tester.enterText(keyField, 'not a key');
      await tester.pump();
      const expectedInvalidEnabled = false;
      expect(_saveEnabled(tester), expectedInvalidEnabled);

      await tester.enterText(keyField, 'HEI-6');
      await tester.pump();
      const expectedValidEnabled = true;
      expect(_saveEnabled(tester), expectedValidEnabled);
    });
  });

  group('children JQL composition', () {
    test('an epic key composes self OR Epic Link', () {
      const key = 'HEI-6';
      final composed = 'issuekey = $key OR (${childrenJql(key, isEpic: true)})';
      const expected = 'issuekey = HEI-6 OR ("Epic Link" = HEI-6)';
      expect(composed, expected);
    });

    test('a non-epic key composes self OR parent', () {
      const key = 'HEI-6';
      final composed = 'issuekey = $key OR (${childrenJql(key, isEpic: false)})';
      const expected = 'issuekey = HEI-6 OR (parent = HEI-6)';
      expect(composed, expected);
    });
  });
}
