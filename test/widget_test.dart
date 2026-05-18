import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heimdall/app.dart';

void main() {
  testWidgets('Heimdall renders its title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const HeimdallApp());
    // Drain the hydrate future, then a frame for the rebuilt MaterialApp.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pump();
    expect(find.text('Heimdall'), findsOneWidget);
  });
}
