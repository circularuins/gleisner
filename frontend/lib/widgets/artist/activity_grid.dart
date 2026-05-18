import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/artist.dart';
import '../../theme/gleisner_tokens.dart';

/// GitHub-style activity heatmap on the artist page (Idea 032).
///
/// Layout follows GitHub's "contributions" grid 1:1 — square cells with
/// rounded corners, weekday labels on the left (Mon/Wed/Fri), month
/// labels above each month's first column, and a Less→More legend below.
/// What's different is the colour treatment: active cells glow in the
/// product's track-palette cyan, with the busiest days blending toward
/// violet and gaining a tiny inner sparkle so the grid reads as a row of
/// dim-to-bright stars laid over a calendar.
///
/// The grid hugs the right edge ("today") and scrolls horizontally when
/// the artist has more than a few months of history. Weekday labels stay
/// fixed on the left so they're always visible while the grid scrolls.
class ActivityGrid extends StatefulWidget {
  final List<ActivityDay> series;

  /// When the artist row was created — the calendar starts here. Pass the
  /// `Artist.createdAt` value directly. When null (e.g. queries that
  /// don't project `createdAt`), the grid is skipped and only the
  /// empty-state copy is shown — there is no fall-back epoch sentinel.
  final DateTime? joinedDate;

  /// Date currently selected by the surrounding screen, as a UTC
  /// `YYYY-MM-DD` string (the same format used by [ActivityDay.date]).
  /// When set, the matching cell renders an accent ring so users can see
  /// which day's posts are showing below the grid.
  final String? selectedDate;

  /// Fires when the user taps a cell that actually has activity. The
  /// string is `YYYY-MM-DD` UTC, matching [ActivityDay.date] and
  /// [selectedDate]. Empty cells are inert.
  final ValueChanged<String>? onDateSelected;

  const ActivityGrid({
    super.key,
    required this.series,
    this.joinedDate,
    this.selectedDate,
    this.onDateSelected,
  });

  @override
  State<ActivityGrid> createState() => _ActivityGridState();
}

class _ActivityGridState extends State<ActivityGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  // Per-build cache for `{date -> count}`. Rebuilt only when
  // `widget.series` changes reference so `shouldRepaint`'s reference
  // comparison stays cheap across animation ticks and parent rebuilds.
  late Map<String, int> _countByDate;
  late int _totalCount;

  // 52 weeks is the GitHub-grass default and matches the backend's
  // 365-day window. If the artist joined more recently we trim the
  // leading columns so the leftmost cell aligns with the join week.
  static const int _maxWeeks = 52;

  @override
  void initState() {
    super.initState();
    _ingestSeries(widget.series);
    // Slow pulse drives the top-tier sparkle so the brightest cells
    // breathe instead of staring flat. The lower tiers don't move.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didUpdateWidget(ActivityGrid old) {
    super.didUpdateWidget(old);
    if (!identical(widget.series, old.series)) {
      _ingestSeries(widget.series);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      if (_pulse.isAnimating) _pulse.stop();
    } else {
      if (!_pulse.isAnimating) _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _ingestSeries(List<ActivityDay> series) {
    _countByDate = {for (final d in series) d.date: d.count};
    _totalCount = series.fold<int>(0, (sum, d) => sum + d.count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
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
      final daysSinceJoin = today.difference(joinedDay).inDays + 1;
      final clampedDays = daysSinceJoin.clamp(1, _maxWeeks * 7);
      weeks = (clampedDays / 7).ceil();
    }

    final reduced = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title in the same uppercase / muted style as
        // GENRES / ABOUT / LINKS to read as a peer section header.
        Text(
          l10n.activityTitle.toUpperCase(),
          style: const TextStyle(
            color: colorTextMuted,
            fontSize: fontSizeXs,
            fontWeight: weightSemibold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: spaceXs),
        // GitHub-style total. Doubles as the most obvious affordance
        // for "this is a count of posts per day" — the label alone is
        // ambiguous, the count makes it concrete.
        Text(
          l10n.activitySummary(_totalCount),
          style: const TextStyle(
            color: colorTextSecondary,
            fontSize: fontSizeMd,
          ),
        ),
        const SizedBox(height: spaceMd),
        if (canRenderGrid)
          _GridSection(
            weeks: weeks,
            today: today,
            countByDate: _countByDate,
            pulse: _pulse,
            twinkleEnabled: !reduced,
            localeTag: localeTag,
            selectedDate: widget.selectedDate,
            onDateSelected: widget.onDateSelected,
          ),
        if (canRenderGrid)
          Padding(
            padding: const EdgeInsets.only(top: spaceSm),
            child: _Legend(
              less: l10n.activityLegendLess,
              more: l10n.activityLegendMore,
            ),
          ),
        if (widget.series.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: spaceSm),
            child: Text(
              l10n.activityEmpty,
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

/// Weekday-labels-on-the-left + horizontally-scrolling (grid + month
/// labels) to the right. Weekday labels stay fixed while the grid
/// scrolls so they remain visible regardless of horizontal offset.
class _GridSection extends StatelessWidget {
  final int weeks;
  final DateTime today;
  final Map<String, int> countByDate;
  final AnimationController pulse;
  final bool twinkleEnabled;
  final String localeTag;
  final String? selectedDate;
  final ValueChanged<String>? onDateSelected;

  const _GridSection({
    required this.weeks,
    required this.today,
    required this.countByDate,
    required this.pulse,
    required this.twinkleEnabled,
    required this.localeTag,
    this.selectedDate,
    this.onDateSelected,
  });

  /// Hit-test the tap's local position against the grid, delegating to
  /// the painter's pure helper so the math stays unit-testable.
  String? _hitTest(Offset local) => ActivityGridPainter.hitTestCell(
    local: local,
    countByDate: countByDate,
    today: today,
    weeks: weeks,
  );

  @override
  Widget build(BuildContext context) {
    const monthLabelHeight = _ActivityGridMetrics.monthLabelHeight;
    const cellPitch = _ActivityGridMetrics.cellPitch;
    const cellGap = _ActivityGridMetrics.cellGap;
    final gridHeight = 7 * cellPitch - cellGap;
    final gridWidth = weeks * cellPitch - cellGap;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed weekday rail. Labels Mon / Wed / Fri only, matching
        // GitHub's sparse weekday convention.
        Padding(
          padding: const EdgeInsets.only(top: monthLabelHeight, right: spaceSm),
          child: const _WeekdayRail(),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: monthLabelHeight,
                  width: gridWidth,
                  child: _MonthLabels(
                    weeks: weeks,
                    today: today,
                    localeTag: localeTag,
                  ),
                ),
                SizedBox(
                  width: gridWidth,
                  height: gridHeight,
                  child: RepaintBoundary(
                    // Single tap target covering the whole grid. The
                    // painter knows which cell each pixel belongs to, so
                    // hit-testing on tap-down is cheaper than spawning
                    // 364 GestureDetectors. Inert (empty / future)
                    // cells fall through `_hitTest` and are ignored.
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: onDateSelected == null
                          ? null
                          : (details) {
                              final date = _hitTest(details.localPosition);
                              if (date != null) {
                                onDateSelected!(date);
                              }
                            },
                      child: AnimatedBuilder(
                        animation: pulse,
                        builder: (context, _) => CustomPaint(
                          painter: ActivityGridPainter(
                            countByDate: countByDate,
                            today: today,
                            weeks: weeks,
                            animationValue: twinkleEnabled ? pulse.value : 0.0,
                            twinkleEnabled: twinkleEnabled,
                            selectedDate: selectedDate,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Three labels (Mon, Wed, Fri) aligned to rows 0, 2, 4 of the grid.
/// Other rows are blank — keeps the rail compact while still anchoring
/// the calendar.
class _WeekdayRail extends StatelessWidget {
  const _WeekdayRail();

  @override
  Widget build(BuildContext context) {
    // ISO weekday: 1 = Monday ... 7 = Sunday. We label rows 0 / 2 / 4
    // (Mon / Wed / Fri). Build from a real DateTime so locale-aware
    // short names come straight from `intl`.
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final ref = DateTime.utc(2024, 1, 1); // 2024-01-01 was a Monday
    final fmt = DateFormat.E(localeTag);
    final mon = fmt.format(ref);
    final wed = fmt.format(ref.add(const Duration(days: 2)));
    final fri = fmt.format(ref.add(const Duration(days: 4)));

    Widget row(String? text) => SizedBox(
      height: _ActivityGridMetrics.cellPitch,
      child: Align(
        alignment: Alignment.centerRight,
        child: text == null
            ? null
            : Text(
                text,
                style: const TextStyle(
                  fontSize: fontSizeXs,
                  color: colorTextMuted,
                ),
              ),
      ),
    );

    return Column(
      children: [
        row(mon),
        row(null),
        row(wed),
        row(null),
        row(fri),
        row(null),
        row(null),
      ],
    );
  }
}

/// Month labels positioned above the leftmost column of each month
/// (locale-aware short form via `intl`).
class _MonthLabels extends StatelessWidget {
  final int weeks;
  final DateTime today;
  final String localeTag;

  const _MonthLabels({
    required this.weeks,
    required this.today,
    required this.localeTag,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMM(localeTag);
    final todayWeekday = today.weekday;
    const cellPitch = _ActivityGridMetrics.cellPitch;

    final labels = <Widget>[];
    int? prevMonth;
    for (int w = 0; w < weeks; w++) {
      // First date that falls in column `w` (its Monday). May be a
      // future date in the rightmost column — that's fine, the month is
      // still the one we want to label.
      final daysFromToday = (weeks - 1 - w) * 7 + (todayWeekday - 1);
      final colMonday = today.subtract(Duration(days: daysFromToday));
      if (colMonday.month != prevMonth) {
        labels.add(
          Positioned(
            left: w * cellPitch,
            top: 0,
            child: Text(
              fmt.format(colMonday),
              style: const TextStyle(
                fontSize: fontSizeXs,
                color: colorTextMuted,
              ),
            ),
          ),
        );
        prevMonth = colMonday.month;
      }
    }
    return Stack(clipBehavior: Clip.none, children: labels);
  }
}

/// "Less ▢▢▢▢▢ More" mini-row beneath the grid. Mirrors GitHub.
class _Legend extends StatelessWidget {
  final String less;
  final String more;
  const _Legend({required this.less, required this.more});

  @override
  Widget build(BuildContext context) {
    const swatches = [0, 1, 2, 3, 4];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          less,
          style: const TextStyle(fontSize: fontSizeXs, color: colorTextMuted),
        ),
        const SizedBox(width: spaceXs),
        for (final tier in swatches) ...[
          _LegendSwatch(tier: tier),
          if (tier < swatches.last) const SizedBox(width: 2),
        ],
        const SizedBox(width: spaceXs),
        Text(
          more,
          style: const TextStyle(fontSize: fontSizeXs, color: colorTextMuted),
        ),
      ],
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final int tier;
  const _LegendSwatch({required this.tier});

  @override
  Widget build(BuildContext context) {
    const size = _ActivityGridMetrics.cellSize;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          _ActivityGridMetrics.cellCornerRadius,
        ),
        color: ActivityGridPainter.cellColorForTier(tier),
        boxShadow: tier >= 2
            ? [
                BoxShadow(
                  color: ActivityGridPainter.glowColorForTier(tier),
                  blurRadius: ActivityGridPainter.glowBlurForTier(tier),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Shared layout numbers — kept in one place so the widget and the
/// painter agree on cell size, gaps, and the band reserved for month
/// labels above the grid.
class _ActivityGridMetrics {
  static const double cellSize = 11;
  static const double cellGap = 3;
  static const double cellPitch = cellSize + cellGap;
  static const double cellCornerRadius = 2.5;
  static const double monthLabelHeight = 16;
}

class ActivityGridPainter extends CustomPainter {
  /// Public so tests and the legend widget can read the same metrics.
  static const double cellSize = _ActivityGridMetrics.cellSize;
  static const double cellGap = _ActivityGridMetrics.cellGap;
  static const double cellPitch = _ActivityGridMetrics.cellPitch;
  static const double cellCornerRadius = _ActivityGridMetrics.cellCornerRadius;

  final Map<String, int> countByDate;
  final DateTime today;
  final int weeks;
  final double animationValue;
  final bool twinkleEnabled;

  /// `YYYY-MM-DD` of the day currently selected by the surrounding
  /// screen, or `null` for "no selection". When set, the matching cell
  /// gets an accent ring drawn on top of its body.
  final String? selectedDate;

  const ActivityGridPainter({
    required this.countByDate,
    required this.today,
    required this.weeks,
    required this.animationValue,
    required this.twinkleEnabled,
    this.selectedDate,
  });

  /// Hit-test a local-coordinate point against the rendered grid and
  /// return the `YYYY-MM-DD` of the matching active cell, or `null`
  /// when the point falls into a gutter, a future cell, or a day with
  /// zero activity. Pure so the tap-routing logic stays unit-testable
  /// without spinning up a widget tree.
  static String? hitTestCell({
    required Offset local,
    required Map<String, int> countByDate,
    required DateTime today,
    required int weeks,
  }) {
    final col = (local.dx / cellPitch).floor();
    final row = (local.dy / cellPitch).floor();
    if (col < 0 || col >= weeks || row < 0 || row >= 7) return null;
    final todayWeekday = today.weekday;
    final daysFromToday = (weeks - 1 - col) * 7 + (todayWeekday - 1 - row);
    if (daysFromToday < 0) return null;
    final cellDate = today.subtract(Duration(days: daysFromToday));
    final y = cellDate.year.toString().padLeft(4, '0');
    final m = cellDate.month.toString().padLeft(2, '0');
    final d = cellDate.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';
    final count = countByDate[dateStr] ?? 0;
    if (count == 0) return null;
    return dateStr;
  }

  /// Map a per-day post count to a brightness tier. Five tiers total:
  /// `0` = empty cell, `1..4` rising activity.
  static int tierForCount(int count) {
    if (count <= 0) return 0;
    if (count == 1) return 1;
    if (count <= 3) return 2;
    if (count <= 6) return 3;
    return 4;
  }

  /// Solid fill color for each tier — alpha-blended cyan over the empty
  /// shade, with the top tier picking up a violet tint to read as a
  /// small nebula.
  static Color cellColorForTier(int tier) {
    switch (tier) {
      case 0:
        return colorActivityEmpty;
      case 1:
        return Color.lerp(colorActivityEmpty, colorActivityBase, 0.35)!;
      case 2:
        return Color.lerp(colorActivityEmpty, colorActivityBase, 0.65)!;
      case 3:
        return colorActivityBase;
      case 4:
      default:
        return Color.lerp(colorActivityBase, colorActivityHigh, 0.45)!;
    }
  }

  /// Halo color used as a [BoxShadow] (legend) or a blurred RRect
  /// (painter). Transparent for tiers that don't glow.
  static Color glowColorForTier(int tier) {
    switch (tier) {
      case 2:
        return colorActivityBase.withValues(alpha: 0.30);
      case 3:
        return colorActivityBase.withValues(alpha: 0.45);
      case 4:
        return colorActivityHigh.withValues(alpha: 0.55);
      default:
        return Colors.transparent;
    }
  }

  /// Blur radius for the halo at each tier.
  static double glowBlurForTier(int tier) {
    switch (tier) {
      case 2:
        return 3;
      case 3:
        return 5;
      case 4:
        return 7;
      default:
        return 0;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final todayWeekday = today.weekday;

    for (int w = 0; w < weeks; w++) {
      for (int d = 0; d < 7; d++) {
        final daysFromToday = (weeks - 1 - w) * 7 + (todayWeekday - 1 - d);
        final left = w * cellPitch;
        final top = d * cellPitch;
        final rect = Rect.fromLTWH(left, top, cellSize, cellSize);

        if (daysFromToday < 0) {
          // Future cell in the current week — paint as empty so the grid
          // stays rectangular without lighting up days that haven't
          // happened.
          _paintCell(canvas, rect, 0, dateStr: '');
          continue;
        }
        final cellDate = today.subtract(Duration(days: daysFromToday));
        final dateStr = _formatYYYYMMDD(cellDate);
        final count = countByDate[dateStr] ?? 0;
        _paintCell(canvas, rect, count, dateStr: dateStr);
      }
    }
  }

  void _paintCell(
    Canvas canvas,
    Rect rect,
    int count, {
    required String dateStr,
  }) {
    final tier = tierForCount(count);
    final radius = Radius.circular(cellCornerRadius);

    // Halo (drawn first so the body sits on top of it).
    if (tier >= 2) {
      double pulseBoost = 0;
      if (tier == 4 && twinkleEnabled) {
        // Top tier subtly breathes so the most-active days catch the
        // eye. Other tiers stay static so the page doesn't shimmer
        // everywhere at once.
        pulseBoost = (animationValue - 0.5).abs() * 0.30;
      }
      final glow = glowColorForTier(tier);
      final blur = glowBlurForTier(tier);
      final inflated = rect.inflate(1.5);
      final haloPaint = Paint()
        ..color = glow.withValues(alpha: (glow.a + pulseBoost).clamp(0, 1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawRRect(RRect.fromRectAndRadius(inflated, radius), haloPaint);
    }

    // Cell body — rounded rectangle (GitHub-style square).
    final bodyPaint = Paint()..color = cellColorForTier(tier);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), bodyPaint);

    // Inner sparkle on the brightest tier — a tiny + cross that gives
    // the square a lens-flare hint of star.
    if (tier == 4) {
      final center = rect.center;
      double sparkleAlpha = 0.85;
      if (twinkleEnabled) {
        sparkleAlpha = 0.85 + (animationValue - 0.5) * 0.30;
      }
      final sparklePaint = Paint()
        ..color = colorActivitySparkle.withValues(
          alpha: sparkleAlpha.clamp(0, 1),
        )
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      final arm = rect.width * 0.30;
      canvas.drawLine(
        center.translate(-arm, 0),
        center.translate(arm, 0),
        sparklePaint,
      );
      canvas.drawLine(
        center.translate(0, -arm),
        center.translate(0, arm),
        sparklePaint,
      );
    }

    // Selection ring — drawn on top of everything so the chosen day is
    // unambiguous even at the brightest tier. Uses the product accent
    // gold so it reads as "user-controlled" rather than "more data".
    if (selectedDate != null && dateStr == selectedDate) {
      final ringRect = rect.inflate(2);
      final ringRadius = Radius.circular(cellCornerRadius + 2);
      final ringPaint = Paint()
        ..color = colorAccentGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(ringRect, ringRadius),
        ringPaint,
      );
    }
  }

  String _formatYYYYMMDD(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  bool shouldRepaint(ActivityGridPainter old) {
    return countByDate != old.countByDate ||
        today != old.today ||
        weeks != old.weeks ||
        twinkleEnabled != old.twinkleEnabled ||
        animationValue != old.animationValue ||
        selectedDate != old.selectedDate;
  }
}
