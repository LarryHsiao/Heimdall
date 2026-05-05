import 'package:flutter_test/flutter_test.dart';

import 'package:heimdall/app.dart';

void main() {
  testWidgets('Heimdall renders its title', (WidgetTester tester) async {
    await tester.pumpWidget(const HeimdallApp());
    expect(find.text('Heimdall'), findsOneWidget);
  });
}
