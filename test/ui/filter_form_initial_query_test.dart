import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heimdall/data/jira_filter.dart';
import 'package:heimdall/ui/filter_form_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'existing filter with initialQuery seeds the composed query and name',
    (tester) async {
      const composed = '(filter = 10363) OR issuekey = HEI-8';
      const existing = JiraFilter(id: '1', name: 'Mine', query: '10363');
      await tester.pumpWidget(
        const MaterialApp(
          home: FilterFormPage(existing: existing, initialQuery: composed),
        ),
      );
      await tester.pump();

      final expectedQuery = composed;
      final expectedName = 'Mine';
      expect(find.text(expectedQuery), findsOneWidget);
      expect(find.text(expectedName), findsOneWidget);
    },
  );
}
