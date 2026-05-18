import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/artist.dart';
import '../../theme/gleisner_tokens.dart';

/// Activity heatmap themed as a night sky (Idea 032).
///
/// Reinterprets the GitHub contribution grid as a star chart: empty cells are
/// voids of deep space, posted days are stars whose brightness scales with
/// post count, and the highest-activity days tint cyan to read as small
/// nebulae. Anchored to the artist's registration date, so the leftmost
/// column shows the week they joined and the rightmost shows the current
/// week.
///
/// The widget owns a single low-frequency [AnimationController] that drives
/// a subtle, opacity-only twinkle across active cells. The animation is
/// halted entirely when [MediaQuery.disableAnimationsOf] is true so the
/// reduced-motion contract is honoured. The painted grid lives inside a
/// [RepaintBoundary] so animation ticks never reach the surrounding
/// artist-page sections.
class StarCalendar extends StatefulWidget {
  final List<ActivityDay> series;

  /// When the artist row was created — the calendar starts here. Pass the
  /// `Artist.createdAt` value directly. When null (e.g. queries that don't
  /// project `createdAt`), the grid is skipped and only the empty-state
  /// message is shown — there is no fall-back epoch sentinel.
  final DateTime? joinedDate;

  const StarCalendar({super.key, required this.series, this.joinedDate});

  @override
  State<StarCalendar> createState() => _StarCalendarState();
}

class _StarCalendarState extends State<StarCalendar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;

  // Per-build cache for `{date -> count}`. Rebuilt only when `widget.series`
  // changes (parent state churn doesn't re-allocate it) so the painter's
  // `shouldRepaint` reference comparison on `countByDate` stays cheap
  // across animation ticks AND parent rebuilds.
  late Map<String, int> _countByDate;

  // 52 weeks is the GitHub-grass default and matches the backend's 365-day
  // window. If the artist joined more recently we trim the leading columns
  // so the leftmost cell aligns with the registration week.
  static const int _maxWeeks = 52;

  @override
  void initState() {
    super.initState();
    _countByDate = _buildCountMap(widget.series);
    // Long period to keep the twinkle subtle. Per-cell phase is randomised
    // (see `StarCalendarPainter._twinkleFor`) so individual stars don't
    // breathe in lockstep.
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didUpdateWidget(StarCalendar old) {
    super.didUpdateWidget(old);
    // Reference inequality is the right signal: `series` is rebuilt by the
    // provider whenever activity is refetched, and identical-content
    // rebuilds without a refetch are rare enough that paying a repaint
    // for them is fine.
    if (!identical(widget.series, old.series)) {
      _countByDate = _buildCountMap(widget.series);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      if (_twinkle.isAnimating) _twinkle.stop();
    } else {
      if (!_twinkle.isAnimating) _twinkle.repeat();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  Map<String, int> _buildCountMap(List<ActivityDay> series) {
    return {for (final d in series) d.date: d.count};
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nowUtc = DateTime.now().toUtc();
    final today = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
    final joinedDay = widget.joinedDate == null
        ? null
        : DateTime.utc(
            widget.joinedDate!.toUtc().year,
            widget.joinedDate!.toUtc().month,
            widget.joinedDate!.toUtc().day,
          );

    final canRenderGrid = joinedDay != null && !joinedDay.isAfter(today);
    int weeks = 0;
    if (canRenderGrid) {
      // Weeks to show: at least 1 (registration day itself counts), capped
      // at 52. Older artists' history beyond 52 weeks is intentionally
      // dropped — matches the backend's 365-day window.
      final daysSinceJoin = today.difference(joinedDay).inDays + 1;
      final clampedDays = daysSinceJoin.clamp(1, _maxWeeks * 7);
      weeks = (clampedDays / 7).ceil();
    }

    final reduced = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: spaceSm),
          child: Text(
            l10n.starCalendarTitle,
            style: const TextStyle(
              fontSize: fontSizeLg,
              fontWeight: weightSemibold,
              color: colorTextSecondary,
            ),
          ),
        ),
        if (canRenderGrid)
          // Horizontal scroll so a freshly registered artist's narrow grid
          // hugs the left edge while a year-old artist's 52-column grid
          // scrolls. `reverse: true` keeps "today" (rightmost column)
          // visible on first paint, which is the column users want to see.
          //
          // `RepaintBoundary` wraps the AnimatedBuilder directly (not the
          // outer Column) so the section title and empty-state copy stay
          // out of the animation layer.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _twinkle,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(
                      weeks * StarCalendarPainter.cellPitch -
                          StarCalendarPainter.cellGap,
                      7 * StarCalendarPainter.cellPitch -
                          StarCalendarPainter.cellGap,
                    ),
                    painter: StarCalendarPainter(
                      countByDate: _countByDate,
                      today: today,
                      weeks: weeks,
                      animationValue: reduced ? 0.0 : _twinkle.value,
                      twinkleEnabled: !reduced,
                    ),
                  );
                },
              ),
            ),
          ),
        if (widget.series.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: spaceMd),
            child: Text(
              l10n.starCalendarEmpty,
              style: const TextStyle(
                fontSize: fontSizeSm,
                color: colorTextMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class StarCalendarPainter extends CustomPainter {
  /// Each grid cell is a 10px circle. Tweaking is centralised here so the
  /// `Size` computation in the widget and the painter stay in sync.
  static const double cellRadius = 5.0;
  static const double cellGap = 6.0;
  static const double cellPitch = cellRadius * 2 + cellGap;

  final Map<String, int> countByDate;
  final DateTime today;
  final int weeks;
  final double animationValue;
  final bool twinkleEnabled;

  const StarCalendarPainter({
    required this.countByDate,
    required this.today,
    required this.weeks,
    required this.animationValue,
    required this.twinkleEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ISO weekday: Monday = 1 ... Sunday = 7. Top row in the grid is
    // Monday, bottom row is Sunday. The rightmost column is "today's
    // week" — its `todayWeekday - 1` row is today; rows below today are
    // future cells (drawn as void, not stars) so the grid keeps a tidy
    // rectangular shape.
    final todayWeekday = today.weekday;

    for (int w = 0; w < weeks; w++) {
      for (int d = 0; d < 7; d++) {
        // daysFromToday is 0 for today's cell. Positive = past; negative
        // = future (only happens in the rightmost column for days that
        // haven't occurred yet this week).
        final daysFromToday = (weeks - 1 - w) * 7 + (todayWeekday - 1 - d);

        final cx = w * cellPitch + cellRadius;
        final cy = d * cellPitch + cellRadius;
        final center = Offset(cx, cy);

        if (daysFromToday < 0) {
          // Future cell in the current week — paint as void only.
          _paintVoid(canvas, center);
          continue;
        }

        final cellDate = today.subtract(Duration(days: daysFromToday));
        final dateStr = _formatYYYYMMDD(cellDate);
        final count = countByDate[dateStr] ?? 0;

        if (count == 0) {
          _paintVoid(canvas, center);
        } else {
          _paintStar(canvas, center, count, dateStr);
        }
      }
    }
  }

  void _paintVoid(Canvas canvas, Offset center) {
    final p = Paint()..color = colorStarVoid.withValues(alpha: 0.7);
    canvas.drawCircle(center, cellRadius, p);
  }

  void _paintStar(Canvas canvas, Offset center, int count, String dateStr) {
    // Brightness tiers map post count to a target opacity, base color, and
    // halo radius. Chosen so the steps read at a glance but never blow
    // out next to the surrounding artist-page typography.
    Color base;
    double opacity;
    double haloRadius;
    Color? haloColor;

    if (count == 1) {
      base = colorStarFaint;
      opacity = 0.55;
      haloRadius = 0;
      haloColor = null;
    } else if (count <= 3) {
      base = colorStarBright;
      opacity = 0.75;
      haloRadius = 0;
      haloColor = null;
    } else if (count <= 6) {
      base = colorStarBrightest;
      opacity = 0.9;
      haloRadius = cellRadius * 1.4;
      haloColor = colorStarBrightest.withValues(alpha: 0.18);
    } else {
      // 7+ posts: nebula tier. Cyan glow signals streak-level activity.
      base = colorStarBrightest;
      opacity = 1.0;
      haloRadius = cellRadius * 1.8;
      haloColor = colorStarNebulaCyan.withValues(alpha: 0.32);
    }

    // Per-cell twinkle phase keeps stars from breathing in lockstep.
    // Range is ±0.08 around the base opacity — barely perceptible but
    // adds the right amount of life. Skipped entirely when reduced-motion
    // is on (animationValue passed as 0.0).
    double adjusted = opacity;
    if (twinkleEnabled) {
      final phase = _twinkleFor(dateStr);
      final t = (math.sin((animationValue + phase) * math.pi * 2) + 1) / 2;
      adjusted = (opacity - 0.08 + 0.16 * t).clamp(0.0, 1.0);
    }

    if (haloRadius > 0 && haloColor != null) {
      final haloPaint = Paint()
        ..color = haloColor.withValues(alpha: haloColor.a * adjusted)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(center, haloRadius, haloPaint);
    }

    final starPaint = Paint()..color = base.withValues(alpha: adjusted);
    canvas.drawCircle(center, cellRadius, starPaint);
  }

  /// Deterministic per-cell twinkle phase in [0, 1). Same date → same phase
  /// across rebuilds.
  double _twinkleFor(String dateStr) {
    final h = dateStr.hashCode.abs();
    return (h % 1000) / 1000.0;
  }

  String _formatYYYYMMDD(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  bool shouldRepaint(StarCalendarPainter old) {
    // `countByDate` is cached on the widget State and only rebuilt when
    // the underlying series changes, so reference equality stays cheap
    // across both animation ticks (same reference forever) and parent
    // rebuilds that don't touch the series.
    return countByDate != old.countByDate ||
        today != old.today ||
        weeks != old.weeks ||
        twinkleEnabled != old.twinkleEnabled ||
        animationValue != old.animationValue;
  }
}
