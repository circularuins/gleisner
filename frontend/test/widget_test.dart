import 'package:flutter_test/flutter_test.dart';

import 'package:gleisner_web/main.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const GleisnerApp());

    expect(find.text('Gleisner'), findsOneWidget);
    expect(find.text('Your multitrack creative timeline'), findsOneWidget);
  });
}
