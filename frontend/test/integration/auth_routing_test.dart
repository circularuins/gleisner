// Routing-level integration tests for unauthenticated users. Exercises the
// real `routerProvider` redirect rules end-to-end (no JWT in storage →
// /splash → /login → other public routes), which is hard to verify with
// pure unit tests because GoRouter needs a widget context.
//
// Why this is integration-flavored, not a widget test: it boots `GleisnerApp`
// (router + theme + i18n + GraphQLProvider) so the same redirect chain a
// user hits in production runs here. Provider-layer tests cannot catch
// regressions like a routing rule that only triggers after auth init
// settles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Unauthenticated routing', () {
    testWidgets('no JWT → splash redirects to login', (tester) async {
      await pumpApp(tester);

      // Login screen renders email/password form + signup link.
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? Sign up"), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('login → tap "no account" link → signup screen', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();

      // Signup screen has 6 TextFormFields: displayName, username, email,
      // password, confirmPassword, inviteCode (all optional except the
      // required ones — but they all render).
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });

    testWidgets('signup → "already have account" link → login screen', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();

      // The link sits below 6 form fields in the narrow layout, so it
      // can fall outside the viewport. Scroll it into view before tapping.
      final backLink = find.text('Already have an account? Sign in');
      await tester.ensureVisible(backLink);
      await tester.pumpAndSettle();
      await tester.tap(backLink);
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? Sign up"), findsOneWidget);
    });
  });
}
