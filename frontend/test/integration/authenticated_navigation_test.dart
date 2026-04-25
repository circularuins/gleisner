// Authenticated-state navigation: a JWT is present in fake storage and the
// `Me` query returns a fan-only user (no artist registration). The router
// should land the user on `/timeline`, and tapping bottom-nav destinations
// should swap branches without throwing.
//
// Why fan-only / no artist: keeps the GraphQL surface narrow. With no own
// artist and no tune-ins, Timeline / Discover / Profile render their empty
// state (or just the screen scaffold + AppBar) without firing follow-up
// queries that would require additional mocks.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gleisner_web/screens/discover/discover_screen.dart';
import 'package:gleisner_web/screens/timeline/timeline_screen.dart';

import '_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authenticated navigation', () {
    testWidgets('valid JWT → router lands on /timeline with bottom nav', (
      tester,
    ) async {
      await pumpApp(
        tester,
        client: stubClient(
          responses: {
            'Me': meUserPayload(),
            'MyArtist': const {'myArtist': null},
            'MyTuneIns': const {'myTuneIns': []},
          },
        ),
        storage: FakeSecureStorage(initial: {'jwt': 'valid-token'}),
      );

      // The Timeline branch is the initial destination after auth.
      expect(find.byType(TimelineScreen), findsOneWidget);
      // All three destination labels render in the bottom NavigationBar.
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Timeline → tap Discover destination switches branch', (
      tester,
    ) async {
      await pumpApp(
        tester,
        client: stubClient(
          responses: {
            'Me': meUserPayload(),
            'MyArtist': const {'myArtist': null},
            'MyTuneIns': const {'myTuneIns': []},
            'DiscoverArtists': const {'discoverArtists': []},
            'Genres': const {'genres': []},
          },
        ),
        storage: FakeSecureStorage(initial: {'jwt': 'valid-token'}),
      );

      // Before navigation: Timeline branch is mounted; the only "Discover"
      // text in the tree is the bottom-nav destination label.
      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(find.byType(DiscoverScreen), findsNothing);
      expect(find.text('Discover'), findsOneWidget);

      // Tap the destination by its visible label.
      await tester.tap(find.text('Discover'));
      // Use pump (not pumpAndSettle) — Discover screen has its own
      // animation controllers; settle would hang.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // After: Discover branch is now the active screen. StatefulShellRoute
      // keeps the previous branch alive offstage, so we assert the active
      // route by checking the visible screen widget.
      expect(find.byType(DiscoverScreen), findsOneWidget);
    });
  });
}
