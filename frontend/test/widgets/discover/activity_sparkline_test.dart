import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/models/artist.dart';
import 'package:gleisner_web/widgets/discover/activity_sparkline.dart';

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
  // Fixed today so the sparkline windowing is deterministic regardless
  // of wall time.
  final today = DateTime.utc(2026, 5, 19);
  DateTime clock() => today;

  String dateMinus(int days) {
    final d = today.subtract(Duration(days: days));
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  group('ActivitySparkline.samplesFor', () {
    test('empty series → all-zero samples of length 14', () {
      final samples = ActivitySparkline.samplesFor(const [], clock: clock);
      expect(samples, hasLength(14));
      expect(samples, everyElement(0));
    });

    test('maps activity dates to the correct columns (today on the right)', () {
      final series = [
        ActivityDay(date: dateMinus(0), count: 3), // today → last column
        ActivityDay(date: dateMinus(7), count: 5), // 7 days ago → col 6
        ActivityDay(date: dateMinus(13), count: 1), // oldest visible → col 0
      ];
      final samples = ActivitySparkline.samplesFor(series, clock: clock);
      expect(samples.last, 3, reason: 'today is the rightmost column');
      expect(samples[6], 5, reason: '7-days-ago lands at column 6');
      expect(samples.first, 1, reason: '13-days-ago lands at column 0');
      // Other slots are zero.
      for (int i = 0; i < samples.length; i++) {
        if (i != 0 && i != 6 && i != samples.length - 1) {
          expect(samples[i], 0, reason: 'col $i has no posts');
        }
      }
    });

    test('dates outside the 14-day window are ignored', () {
      // 20 days ago is beyond the visible window — must not appear in
      // samples.
      final series = [ActivityDay(date: dateMinus(20), count: 99)];
      final samples = ActivitySparkline.samplesFor(series, clock: clock);
      expect(samples, everyElement(0));
    });

    test('empty-string dates are filtered (lenient fromJson tolerance)', () {
      // ActivityDay.fromJson can emit empty strings on wire malformity
      // — they must not poison the lookup map.
      final series = [
        const ActivityDay(date: '', count: 99),
        ActivityDay(date: dateMinus(0), count: 4),
      ];
      final samples = ActivitySparkline.samplesFor(series, clock: clock);
      expect(samples.last, 4);
      // Total is just the legit entry — phantom 99 doesn't leak.
      final sum = samples.fold<int>(0, (a, b) => a + b);
      expect(sum, 4);
    });
  });

  group('ActivitySparkline.isEmptyFor', () {
    test('returns true when the visible window has no posts', () {
      expect(ActivitySparkline.isEmptyFor(const [], clock: clock), isTrue);
      expect(
        ActivitySparkline.isEmptyFor([
          ActivityDay(date: dateMinus(60), count: 10),
        ], clock: clock),
        isTrue,
        reason: 'a post 60 days ago is outside the window → empty',
      );
    });

    test('returns false when at least one visible day has a post', () {
      expect(
        ActivitySparkline.isEmptyFor([
          ActivityDay(date: dateMinus(5), count: 1),
        ], clock: clock),
        isFalse,
      );
    });
  });

  group('ActivitySparkline widget', () {
    testWidgets('collapses to SizedBox.shrink when no visible activity', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: ActivitySparkline(series: const [], clock: clock),
        ),
      );
      await tester.pump();
      // The sparkline doesn't paint when there's nothing to show.
      // Other CustomPaints elsewhere in the harness (Scaffold etc.)
      // are filtered out by matching the published widget bounds.
      final ours = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where(
            (cp) =>
                cp.size.width == ActivitySparkline.kWidth &&
                cp.size.height == ActivitySparkline.kHeight,
          )
          .toList();
      expect(ours, isEmpty);
    });

    testWidgets('renders a CustomPaint with the published bounds when active', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: ActivitySparkline(
            series: [ActivityDay(date: dateMinus(0), count: 3)],
            clock: clock,
          ),
        ),
      );
      await tester.pump();
      final cps = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.size.width > 0 && w.size.height > 0)
          .toList();
      // SizedBox parent dictates the size from the constants — assert
      // the painted area matches kWidth × kHeight at least once.
      expect(
        cps.any(
          (cp) =>
              cp.size.width == ActivitySparkline.kWidth &&
              cp.size.height == ActivitySparkline.kHeight,
        ),
        isTrue,
      );
    });

    testWidgets('reduced motion settles immediately (no pulse loop)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          reduceMotion: true,
          child: ActivitySparkline(
            // Today active — would normally pulse — but motion is off.
            series: [ActivityDay(date: dateMinus(0), count: 5)],
            clock: clock,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('today-inactive series does not start a pulse loop', (
      tester,
    ) async {
      // Activity within the window but not on today → no rightmost
      // pulse → tree settles without `pumpAndSettle` hitting the
      // animation-loop timeout.
      await tester.pumpWidget(
        _harness(
          child: ActivitySparkline(
            series: [ActivityDay(date: dateMinus(5), count: 3)],
            clock: clock,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });
}
