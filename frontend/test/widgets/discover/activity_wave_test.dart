import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/widgets/discover/activity_wave.dart';

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
  // Fixed wall time so recency-boundary tests don't drift.
  final now = DateTime.utc(2026, 5, 19, 12);
  DateTime clock() => now;

  group('ActivityWave.tierFor', () {
    test('null → hidden', () {
      expect(ActivityWave.tierFor(null, clock: clock), ActivityWaveTier.hidden);
    });

    test('within 24h → veryRecent', () {
      expect(
        ActivityWave.tierFor(
          now.subtract(const Duration(hours: 1)),
          clock: clock,
        ),
        ActivityWaveTier.veryRecent,
      );
      expect(
        ActivityWave.tierFor(
          now.subtract(const Duration(hours: 23, minutes: 59)),
          clock: clock,
        ),
        ActivityWaveTier.veryRecent,
      );
    });

    test('24h boundary → recent', () {
      expect(
        ActivityWave.tierFor(
          now.subtract(const Duration(hours: 24)),
          clock: clock,
        ),
        ActivityWaveTier.recent,
      );
    });

    test('1–7 days → recent', () {
      expect(
        ActivityWave.tierFor(
          now.subtract(const Duration(days: 3)),
          clock: clock,
        ),
        ActivityWaveTier.recent,
      );
    });

    test('7-day boundary → dim', () {
      expect(
        ActivityWave.tierFor(
          now.subtract(const Duration(days: 7)),
          clock: clock,
        ),
        ActivityWaveTier.dim,
      );
    });

    test('7–30 days → dim', () {
      expect(
        ActivityWave.tierFor(
          now.subtract(const Duration(days: 20)),
          clock: clock,
        ),
        ActivityWaveTier.dim,
      );
    });

    test('30-day boundary → flat', () {
      expect(
        ActivityWave.tierFor(
          now.subtract(const Duration(days: 30)),
          clock: clock,
        ),
        ActivityWaveTier.flat,
      );
    });

    test('older than 30 days → flat (not hidden)', () {
      // Important — "flat" is a visible state. Dormant artists still
      // get a baseline line so every card carries a beacon.
      expect(
        ActivityWave.tierFor(
          now.subtract(const Duration(days: 365)),
          clock: clock,
        ),
        ActivityWaveTier.flat,
      );
    });
  });

  group('ActivityWave tier knobs', () {
    test('amplitude decreases monotonically toward flat', () {
      expect(
        ActivityWave.amplitudeFor(ActivityWaveTier.veryRecent),
        greaterThan(ActivityWave.amplitudeFor(ActivityWaveTier.recent)),
      );
      expect(
        ActivityWave.amplitudeFor(ActivityWaveTier.recent),
        greaterThan(ActivityWave.amplitudeFor(ActivityWaveTier.dim)),
      );
      expect(
        ActivityWave.amplitudeFor(ActivityWaveTier.dim),
        greaterThan(ActivityWave.amplitudeFor(ActivityWaveTier.flat)),
      );
      expect(ActivityWave.amplitudeFor(ActivityWaveTier.flat), 0);
    });

    test('amplitude never exceeds half the widget height', () {
      for (final tier in ActivityWaveTier.values) {
        expect(
          ActivityWave.amplitudeFor(tier),
          lessThanOrEqualTo(ActivityWave.kHeight / 2),
          reason: '$tier amplitude must fit within bounds',
        );
      }
    });

    test('scroll duration grows from veryRecent to dim', () {
      expect(
        ActivityWave.durationFor(ActivityWaveTier.veryRecent),
        lessThan(ActivityWave.durationFor(ActivityWaveTier.recent)),
      );
      expect(
        ActivityWave.durationFor(ActivityWaveTier.recent),
        lessThan(ActivityWave.durationFor(ActivityWaveTier.dim)),
      );
    });

    test('only animated tiers report hasMovement', () {
      expect(ActivityWave.hasMovement(ActivityWaveTier.veryRecent), isTrue);
      expect(ActivityWave.hasMovement(ActivityWaveTier.recent), isTrue);
      expect(ActivityWave.hasMovement(ActivityWaveTier.dim), isTrue);
      expect(ActivityWave.hasMovement(ActivityWaveTier.flat), isFalse);
      expect(ActivityWave.hasMovement(ActivityWaveTier.hidden), isFalse);
    });

    test('colors get more opaque toward veryRecent', () {
      final aBright = ActivityWave.colorFor(ActivityWaveTier.veryRecent).a;
      final aRecent = ActivityWave.colorFor(ActivityWaveTier.recent).a;
      final aDim = ActivityWave.colorFor(ActivityWaveTier.dim).a;
      expect(aBright, greaterThan(aRecent));
      expect(aRecent, greaterThan(aDim));
      // Hidden tier paints nothing.
      expect(ActivityWave.colorFor(ActivityWaveTier.hidden).a, 0);
    });
  });

  group('ActivityWave widget', () {
    testWidgets('hidden tier collapses to SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        _harness(child: ActivityWave(lastPostedAt: null, clock: clock)),
      );
      await tester.pump();
      final ours = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where(
            (cp) =>
                cp.size.width == ActivityWave.kWidth &&
                cp.size.height == ActivityWave.kHeight,
          )
          .toList();
      expect(ours, isEmpty);
    });

    testWidgets('any non-null lastPostedAt renders a CustomPaint at the '
        'published bounds', (tester) async {
      for (final age in const [
        Duration(hours: 2), // veryRecent
        Duration(days: 3), // recent
        Duration(days: 14), // dim
        Duration(days: 60), // flat
      ]) {
        await tester.pumpWidget(
          _harness(
            child: ActivityWave(lastPostedAt: now.subtract(age), clock: clock),
          ),
        );
        await tester.pump();
        final ours = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where(
              (cp) =>
                  cp.size.width == ActivityWave.kWidth &&
                  cp.size.height == ActivityWave.kHeight,
            )
            .toList();
        expect(ours, isNotEmpty, reason: 'tier age $age should render');
      }
    });

    testWidgets('reduced motion still renders the wave, just frozen', (
      tester,
    ) async {
      // veryRecent normally scrolls — reduceMotion should freeze it
      // without removing the wave shape.
      await tester.pumpWidget(
        _harness(
          reduceMotion: true,
          child: ActivityWave(
            lastPostedAt: now.subtract(const Duration(hours: 1)),
            clock: clock,
          ),
        ),
      );
      await tester.pump();
      // Tree settles immediately — no AnimatedBuilder loop.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      // The CustomPaint is still mounted.
      final ours = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where(
            (cp) =>
                cp.size.width == ActivityWave.kWidth &&
                cp.size.height == ActivityWave.kHeight,
          )
          .toList();
      expect(ours, isNotEmpty);
    });

    testWidgets('flat tier does not start a controller loop', (tester) async {
      // A 60-day-stale artist sits at the flat tier — pulse loop
      // should not be running, so the tree settles immediately.
      await tester.pumpWidget(
        _harness(
          child: ActivityWave(
            lastPostedAt: now.subtract(const Duration(days: 60)),
            clock: clock,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });

  group('ActivityWavePainter.shouldRepaint', () {
    test('repaints when tier changes', () {
      const a = ActivityWavePainter(
        tier: ActivityWaveTier.veryRecent,
        phase: 0.3,
      );
      const b = ActivityWavePainter(tier: ActivityWaveTier.dim, phase: 0.3);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('repaints when phase changes on a moving tier', () {
      const a = ActivityWavePainter(tier: ActivityWaveTier.recent, phase: 0.1);
      const b = ActivityWavePainter(tier: ActivityWaveTier.recent, phase: 0.8);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('does not repaint on phase change for flat / hidden tiers', () {
      const a = ActivityWavePainter(tier: ActivityWaveTier.flat, phase: 0.1);
      const b = ActivityWavePainter(tier: ActivityWaveTier.flat, phase: 0.8);
      expect(b.shouldRepaint(a), isFalse);
    });
  });
}
