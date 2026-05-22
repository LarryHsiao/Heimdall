import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heimdall/data/jira_filter.dart';
import 'package:heimdall/ui/filters_page.dart';

const _filterAlpha = JiraFilter(id: 'a', name: 'Alpha', query: 'project = A');
const _filterBeta = JiraFilter(id: 'b', name: 'Beta', query: 'project = B');

void _seedFilters(List<JiraFilter> filters) {
  final encoded =
      jsonEncode(filters.map((f) => f.toJson()).toList());
  SharedPreferences.setMockInitialValues({
    'configured_filters': encoded,
  });
}

Future<void> _pumpFiltersPage(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: FiltersPage()));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FiltersPage delete confirmation', () {
    testWidgets('tapping delete shows a confirm dialog naming the filter',
        (tester) async {
      _seedFilters([_filterAlpha]);
      await _pumpFiltersPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      const expectedTitle = 'Delete filter?';
      const expectedBody = '"Alpha" will be removed.';
      expect(find.text(expectedTitle), findsOneWidget);
      expect(find.text(expectedBody), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Cancel dismisses the dialog and keeps the filter',
        (tester) async {
      _seedFilters([_filterAlpha]);
      await _pumpFiltersPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      const expectedRemaining = 'Alpha';
      expect(find.text(expectedRemaining), findsOneWidget);
      expect(find.text('Delete filter?'), findsNothing);
    });

    testWidgets('Delete removes the chosen filter and leaves the others',
        (tester) async {
      _seedFilters([_filterAlpha, _filterBeta]);
      await _pumpFiltersPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      const expectedSurvivor = 'Beta';
      expect(find.text('Alpha'), findsNothing);
      expect(find.text(expectedSurvivor), findsOneWidget);
    });
  });
}
