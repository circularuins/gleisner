import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/widgets/common/app_footer.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('AppFooter', () {
    testWidgets('renders Gleisner text and About link', (tester) async {
      await tester.pumpWidget(_wrap(const AppFooter()));
      await tester.pumpAndSettle();

      expect(find.text('Gleisner'), findsOneWidget);
      expect(find.text('About / External Services'), findsOneWidget);
    });

    testWidgets('fires onAboutTap when link is tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(AppFooter(onAboutTap: () => tapped = true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('About / External Services'));
      expect(tapped, isTrue);
    });

    testWidgets('renders safely when onAboutTap is null', (tester) async {
      await tester.pumpWidget(_wrap(const AppFooter()));
      await tester.pumpAndSettle();

      // Tapping should not crash
      await tester.tap(find.text('About / External Services'));
      await tester.pump();
      expect(find.text('Gleisner'), findsOneWidget);
    });
  });
}
