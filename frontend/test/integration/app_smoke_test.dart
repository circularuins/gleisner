// Phase 0 smoke test: verifies the full app boot path (Hive cache → ProviderScope
// → GraphQLProvider → MaterialApp.router → splash screen) succeeds. This goes
// beyond `test/widget_test.dart` (which only asserts the splash text) by
// confirming router and theme bootstrap also complete without throwing.
//
// Web-only for now: lives in `test/integration/` because Flutter's integration
// test runner does not support web devices (flutter/flutter#66264). When iOS /
// Android targets are added (ADR 015), move this file to `integration_test/`
// to lift it onto the official integration test harness with no code change.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gleisner_web/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots through MaterialApp.router into splash screen', (
    tester,
  ) async {
    await initHiveForFlutter();

    await tester.pumpWidget(const ProviderScope(child: GleisnerApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Gleisner'), findsOneWidget);
  });
}
