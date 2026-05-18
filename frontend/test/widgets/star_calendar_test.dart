import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/models/artist.dart';
import 'package:gleisner_web/widgets/artist/star_calendar.dart';

/// Read AppLocalizations off the harness Scaffold so the test assertions
/// stay coupled to the ARB rather than a copy of the English string —
/// future ARB edits flag in tests instead of silently diverging.
AppLocalizations _l10n(WidgetTester tester) {
  final ctx = tester.element(find.byType(Scaffold));
  return AppLocalizations.of(ctx)!;
}

/// Wrap the widget under test in the minimum scaffold the StarCalendar needs:
/// a MaterialApp providing localisations + an optional reduced-motion
/// override for the disable-animations test.
Widget _harness({required Widget child, bool reduceMotion = false}) {
  // Use builder to inject a reduced-motion MediaQuery only when needed.
  // The widget under test is placed inside a SingleChildScrollView via the
  // home Scaffold so its horizontal-scrolling grid has bounded width.
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
  group('StarCalendar widget', () {
    testWidgets('renders the section title', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: StarCalendar(
            series: const [],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_l10n(tester).starCalendarTitle), findsOneWidget);
    });

    testWidgets('shows the empty-state message when the series is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: StarCalendar(
            series: const [],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_l10n(tester).starCalendarEmpty), findsOneWidget);
    });

    testWidgets('hides the empty-state message when the series has data', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          child: StarCalendar(
            series: const [ActivityDay(date: '2026-05-01', count: 3)],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_l10n(tester).starCalendarEmpty), findsNothing);
    });

    testWidgets('renders a CustomPaint with non-zero size', (tester) async {
      await tester.pumpWidget(
        _harness(
          child: StarCalendar(
            series: const [],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();
      // CustomPaint inside the AnimatedBuilder.
      final cp = find.byType(CustomPaint);
      expect(cp, findsWidgets);
      // Verify at least one CustomPaint has a non-zero size — the grid one.
      final sizes = tester
          .widgetList<CustomPaint>(cp)
          .map((w) => w.size)
          .where((s) => s.width > 0 && s.height > 0)
          .toList();
      expect(sizes, isNotEmpty);
    });

    testWidgets('null joinedDate skips the grid but keeps the title', (
      tester,
    ) async {
      // When the query doesn't project createdAt (e.g. discoverArtists),
      // the widget must degrade to the empty-state surface instead of
      // back-filling a sentinel date and rendering 52 weeks of voids.
      await tester.pumpWidget(_harness(child: const StarCalendar(series: [])));
      await tester.pump();
      expect(find.text(_l10n(tester).starCalendarTitle), findsOneWidget);
      // Inside the AnimatedBuilder there's a single non-zero CustomPaint
      // when the grid renders; with joinedDate=null only the Text widgets
      // exist, so no CustomPaint with non-zero size should be present.
      final sized = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((w) => w.size.width > 0 && w.size.height > 0)
          .toList();
      expect(sized, isEmpty);
    });

    testWidgets('reduced motion stops the animation controller', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          reduceMotion: true,
          child: StarCalendar(
            series: const [ActivityDay(date: '2026-05-01', count: 5)],
            joinedDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      // Two pumps so didChangeDependencies has run and consumed the
      // reduced-motion signal.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // If the controller were still ticking, pumping would deliver a new
      // frame request indefinitely; `pumpAndSettle` would time out. With
      // reduced motion respected, the tree settles immediately.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      // No assertion failure means the tree settled — implicit pass.
    });
  });

  group('StarCalendarPainter.shouldRepaint', () {
    StarCalendarPainter makePainter({
      Map<String, int>? countByDate,
      DateTime? today,
      int? weeks,
      double? animationValue,
      bool? twinkleEnabled,
    }) {
      return StarCalendarPainter(
        countByDate: countByDate ?? {},
        today: today ?? DateTime.utc(2026, 5, 18),
        weeks: weeks ?? 20,
        animationValue: animationValue ?? 0.0,
        twinkleEnabled: twinkleEnabled ?? true,
      );
    }

    test('returns false when every input matches (same-reference map)', () {
      // The widget builds a single Map per parent build and shares it
      // across AnimatedBuilder ticks, so reference equality is the
      // hot-path case the shouldRepaint contract needs to optimise.
      final shared = <String, int>{'2026-05-18': 1};
      final today = DateTime.utc(2026, 5, 18);
      final a = StarCalendarPainter(
        countByDate: shared,
        today: today,
        weeks: 20,
        animationValue: 0.5,
        twinkleEnabled: true,
      );
      final b = StarCalendarPainter(
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
      // Different Map instances even with identical content — by design,
      // we reference-compare, so this repaints. Acceptable cost: the map
      // is rebuilt only on parent build, not per animation tick.
      expect(b.shouldRepaint(a), isTrue);
    });
  });
}
