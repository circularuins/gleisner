import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/widgets/discover/pulse_beacon.dart';

AppLocalizations _l10n(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold));
  return AppLocalizations.of(ctx)!;
}

Widget _harness({required Widget child, bool reduceMotion = false}) {
  final scaffold = Scaffold(body: Center(child: child));
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    builder: reduceMotion
        ? (context, app) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(disableAnimations: true),
              child: app ?? const SizedBox.shrink(),
            );
          }
        : null,
    home: scaffold,
  );
}

void main() {
  // Fixed `now` so the recency boundaries don't drift with wall time.
  final now = DateTime.utc(2026, 5, 19, 12);
  DateTime clock() => now;

  group('PulseBeacon.stateFor', () {
    test('null lastPostedAt → hidden', () {
      expect(PulseBeacon.stateFor(null, clock: clock), PulseBeaconState.hidden);
    });

    test('within 24h → veryRecent', () {
      // 1 hour ago.
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(hours: 1)),
          clock: clock,
        ),
        PulseBeaconState.veryRecent,
      );
      // 23h 59m ago — still inside the bucket.
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(hours: 23, minutes: 59)),
          clock: clock,
        ),
        PulseBeaconState.veryRecent,
      );
    });

    test('24h boundary crosses into recent', () {
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(hours: 24)),
          clock: clock,
        ),
        PulseBeaconState.recent,
      );
    });

    test('1–7 days → recent', () {
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(days: 3)),
          clock: clock,
        ),
        PulseBeaconState.recent,
      );
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(days: 6, hours: 23)),
          clock: clock,
        ),
        PulseBeaconState.recent,
      );
    });

    test('7-day boundary crosses into dim', () {
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(days: 7)),
          clock: clock,
        ),
        PulseBeaconState.dim,
      );
    });

    test('7–30 days → dim', () {
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(days: 15)),
          clock: clock,
        ),
        PulseBeaconState.dim,
      );
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(days: 29)),
          clock: clock,
        ),
        PulseBeaconState.dim,
      );
    });

    test('30-day boundary crosses into hidden', () {
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(days: 30)),
          clock: clock,
        ),
        PulseBeaconState.hidden,
      );
    });

    test('older than 30 days → hidden', () {
      expect(
        PulseBeacon.stateFor(
          now.subtract(const Duration(days: 365)),
          clock: clock,
        ),
        PulseBeaconState.hidden,
      );
    });
  });

  group('PulseBeacon widget', () {
    testWidgets('hidden state collapses to SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: PulseBeacon(
            lastPostedAt: now.subtract(const Duration(days: 60)),
            clock: clock,
          ),
        ),
      );
      await tester.pump();
      // No DecoratedBox (the dot is one) for the >30d / hidden state.
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('null lastPostedAt collapses to SizedBox.shrink', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(child: PulseBeacon(lastPostedAt: null, clock: clock)),
      );
      await tester.pump();
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets(
      'veryRecent state renders the dot with the correct semantic label',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            child: PulseBeacon(
              lastPostedAt: now.subtract(const Duration(hours: 2)),
              clock: clock,
            ),
          ),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel(_l10n(tester).pulseBeaconActiveDay),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'recent state renders the dot with the correct semantic label',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            child: PulseBeacon(
              lastPostedAt: now.subtract(const Duration(days: 3)),
              clock: clock,
            ),
          ),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel(_l10n(tester).pulseBeaconActiveWeek),
          findsOneWidget,
        );
      },
    );

    testWidgets('dim state renders the dot with the correct semantic label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: PulseBeacon(
            lastPostedAt: now.subtract(const Duration(days: 14)),
            clock: clock,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(_l10n(tester).pulseBeaconActiveMonth),
        findsOneWidget,
      );
    });

    testWidgets('reduced motion settles instantly (no AnimatedBuilder loop)', (
      tester,
    ) async {
      // Without the static-tier fallback, an AnimatedBuilder loop on
      // a veryRecent state would keep scheduling frames and
      // `pumpAndSettle` would time out under reduceMotion.
      await tester.pumpWidget(
        _harness(
          reduceMotion: true,
          child: PulseBeacon(
            lastPostedAt: now.subtract(const Duration(hours: 1)),
            clock: clock,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });
}
