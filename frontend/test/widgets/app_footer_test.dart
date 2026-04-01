import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/widgets/common/app_footer.dart';

void main() {
  group('AppFooter', () {
    testWidgets('renders Gleisner text and About link', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppFooter())),
      );

      expect(find.text('Gleisner'), findsOneWidget);
      expect(find.text('About / External Services'), findsOneWidget);
    });

    testWidgets('fires onAboutTap when link is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppFooter(onAboutTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('About / External Services'));
      expect(tapped, isTrue);
    });

    testWidgets('renders safely when onAboutTap is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AppFooter())),
      );

      // Tapping should not crash
      await tester.tap(find.text('About / External Services'));
      await tester.pump();
      expect(find.text('Gleisner'), findsOneWidget);
    });
  });
}
