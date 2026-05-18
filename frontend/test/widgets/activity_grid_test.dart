import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/models/artist.dart';
import 'package:gleisner_web/widgets/artist/activity_grid.dart';

/// Read AppLocalizations off the harness Scaffold so test assertions
/// stay coupled to the ARB rather than to a copy of the English string —
/// future ARB edits flag in tests instead of silently diverging.
AppLocalizations _l10n(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold));
  return AppLocalizations.of(ctx)!;
}

Widget _harness({required Widget child, bool reduceMotion = false}) {
  final scaffold = Scaffold(body: SingleChildScrollView(child: child));
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
  group('ActivityGrid widget', () {
    testWidgets('renders uppercase title and zero-summary when empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: ActivityGrid(
            series: const [],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      final l10n = _l10n(tester);
      expect(find.text(l10n.activityTitle.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.activitySummary(0)), findsOneWidget);
    });

    testWidgets('summary reflects the total post count across the series', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: ActivityGrid(
            series: const [
              ActivityDay(date: '2026-05-01', count: 3),
              ActivityDay(date: '2026-05-02', count: 5),
            ],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_l10n(tester).activitySummary(8)), findsOneWidget);
    });

    testWidgets('shows the empty-state copy when the series is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: ActivityGrid(
            series: const [],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_l10n(tester).activityEmpty), findsOneWidget);
    });

    testWidgets('hides the empty-state copy once the series has data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: ActivityGrid(
            series: const [ActivityDay(date: '2026-05-01', count: 3)],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_l10n(tester).activityEmpty), findsNothing);
    });

    testWidgets('renders Less / More legend labels under the grid', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: ActivityGrid(
            series: const [ActivityDay(date: '2026-05-01', count: 1)],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      final l10n = _l10n(tester);
      expect(find.text(l10n.activityLegendLess), findsOneWidget);
      expect(find.text(l10n.activityLegendMore), findsOneWidget);
    });

    testWidgets('null joinedDate skips the grid + legend', (tester) async {
      await tester.pumpWidget(_harness(child: const ActivityGrid(series: [])));
      await tester.pump();
      final l10n = _l10n(tester);
      // Title + summary still render
      expect(find.text(l10n.activityTitle.toUpperCase()), findsOneWidget);
      // …but no legend (legend lives inside the grid section)
      expect(find.text(l10n.activityLegendLess), findsNothing);
      expect(find.text(l10n.activityLegendMore), findsNothing);
    });

    testWidgets('reduced motion stops the pulse controller', (tester) async {
      await tester.pumpWidget(
        _harness(
          reduceMotion: true,
          child: ActivityGrid(
            series: const [ActivityDay(date: '2026-05-01', count: 8)],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // If the controller were still ticking, `pumpAndSettle` would time
      // out (AnimatedBuilder schedules a frame each cycle). With reduced
      // motion respected, the tree settles immediately.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });
  });

  group('ActivityGridPainter.hitTestCell', () {
    // Anchored on a known Wednesday so the grid layout is deterministic
    // (Wed.weekday == 3, so today sits at column = weeks-1, row 2).
    final today = DateTime.utc(2026, 5, 13);
    const weeks = 4;
    final countByDate = <String, int>{
      '2026-05-13': 3, // today
      '2026-05-08': 1, // last Friday
    };

    Offset cellCenter(int col, int row) {
      final pitch = ActivityGridPainter.cellPitch;
      return Offset(col * pitch + pitch / 2, row * pitch + pitch / 2);
    }

    test('returns the date for an active cell', () {
      // Today is at column 3 (rightmost), row 2 (Wednesday).
      final result = ActivityGridPainter.hitTestCell(
        local: cellCenter(3, 2),
        countByDate: countByDate,
        today: today,
        weeks: weeks,
      );
      expect(result, '2026-05-13');
    });

    test('returns null for an empty cell', () {
      // Column 3, row 0 (Monday of today's week) — no activity.
      final result = ActivityGridPainter.hitTestCell(
        local: cellCenter(3, 0),
        countByDate: countByDate,
        today: today,
        weeks: weeks,
      );
      expect(result, isNull);
    });

    test('returns null for future cells', () {
      // Column 3, row 6 (Sunday of today's week) — future since today
      // is Wednesday.
      final result = ActivityGridPainter.hitTestCell(
        local: cellCenter(3, 6),
        countByDate: countByDate,
        today: today,
        weeks: weeks,
      );
      expect(result, isNull);
    });

    test('returns null for out-of-bounds coordinates', () {
      final result = ActivityGridPainter.hitTestCell(
        local: const Offset(-5, -5),
        countByDate: countByDate,
        today: today,
        weeks: weeks,
      );
      expect(result, isNull);
    });

    test('resolves an active cell from a previous week', () {
      // Last Friday (2026-05-08) is at column 2, row 4 in this layout:
      // today = 2026-05-13 (Wed, col=3, row=2)
      // Going back 5 days → col=2, row=4 (Friday of previous week).
      final result = ActivityGridPainter.hitTestCell(
        local: cellCenter(2, 4),
        countByDate: countByDate,
        today: today,
        weeks: weeks,
      );
      expect(result, '2026-05-08');
    });
  });

  group('ActivityGridPainter.tierForCount', () {
    test('maps counts to the 5-tier ramp', () {
      expect(ActivityGridPainter.tierForCount(0), 0);
      expect(ActivityGridPainter.tierForCount(1), 1);
      expect(ActivityGridPainter.tierForCount(2), 2);
      expect(ActivityGridPainter.tierForCount(3), 2);
      expect(ActivityGridPainter.tierForCount(4), 3);
      expect(ActivityGridPainter.tierForCount(6), 3);
      expect(ActivityGridPainter.tierForCount(7), 4);
      expect(ActivityGridPainter.tierForCount(99), 4);
    });
  });

  group('ActivityGridPainter.shouldRepaint', () {
    ActivityGridPainter makePainter({
      Map<String, int>? countByDate,
      DateTime? today,
      int? weeks,
      double? animationValue,
      bool? twinkleEnabled,
    }) {
      return ActivityGridPainter(
        countByDate: countByDate ?? {},
        today: today ?? DateTime.utc(2026, 5, 18),
        weeks: weeks ?? 20,
        animationValue: animationValue ?? 0.0,
        twinkleEnabled: twinkleEnabled ?? true,
      );
    }

    test('returns false when every input matches (same-reference map)', () {
      final shared = <String, int>{'2026-05-18': 1};
      final today = DateTime.utc(2026, 5, 18);
      final a = ActivityGridPainter(
        countByDate: shared,
        today: today,
        weeks: 20,
        animationValue: 0.5,
        twinkleEnabled: true,
      );
      final b = ActivityGridPainter(
        countByDate: shared,
        today: today,
        weeks: 20,
        animationValue: 0.5,
        twinkleEnabled: true,
      );
      expect(b.shouldRepaint(a), isFalse);
    });

    test('returns true when animationValue changes', () {
      final shared = <String, int>{'2026-05-18': 1};
      final a = makePainter(countByDate: shared, animationValue: 0.1);
      final b = makePainter(countByDate: shared, animationValue: 0.6);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('returns true when today changes', () {
      final shared = <String, int>{};
      final a = makePainter(
        countByDate: shared,
        today: DateTime.utc(2026, 5, 18),
      );
      final b = makePainter(
        countByDate: shared,
        today: DateTime.utc(2026, 5, 19),
      );
      expect(b.shouldRepaint(a), isTrue);
    });

    test('returns true when weeks changes', () {
      final shared = <String, int>{};
      final a = makePainter(countByDate: shared, weeks: 10);
      final b = makePainter(countByDate: shared, weeks: 20);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('returns true when twinkleEnabled changes', () {
      final shared = <String, int>{};
      final a = makePainter(countByDate: shared, twinkleEnabled: true);
      final b = makePainter(countByDate: shared, twinkleEnabled: false);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('returns true when countByDate reference changes', () {
      final a = makePainter(countByDate: {'2026-05-18': 1});
      final b = makePainter(countByDate: {'2026-05-18': 1});
      expect(b.shouldRepaint(a), isTrue);
    });

    test('returns true when selectedDate changes', () {
      final shared = <String, int>{'2026-05-18': 1};
      final a = ActivityGridPainter(
        countByDate: shared,
        today: DateTime.utc(2026, 5, 18),
        weeks: 20,
        animationValue: 0,
        twinkleEnabled: true,
        selectedDate: null,
      );
      final b = ActivityGridPainter(
        countByDate: shared,
        today: DateTime.utc(2026, 5, 18),
        weeks: 20,
        animationValue: 0,
        twinkleEnabled: true,
        selectedDate: '2026-05-18',
      );
      expect(b.shouldRepaint(a), isTrue);
    });
  });
}
