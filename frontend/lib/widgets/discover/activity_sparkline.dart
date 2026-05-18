import 'package:flutter/material.dart';

import '../../models/artist.dart';
import '../../theme/gleisner_tokens.dart';

/// Discovery-card activity sparkline (Idea 032 — v2 visual).
///
/// Replaces the original single-dot "pulse beacon" with a 14-day mini
/// bar chart in the top-right of the cover image. Each bar represents
/// one UTC day's post count; bars brighten left → right so the most
/// recent days catch the eye, and the rightmost bar (today) pulses
/// gently when the artist posted within the last 24h.
///
/// Communicates more than a single dot can:
///   - **shape** — the bar pattern reads as an actual activity wave
///   - **density** — more bars / taller bars = busier artist
///   - **recency** — rightmost-bar pulse signals "active right now"
///   - **silence** — no bars (and the whole widget collapses) for an
///     artist with no activity in the last 14 days
///
/// All animation is opacity-only (ADR 024). Reduced motion freezes the
/// pulse to its baseline; the static gradient still conveys recency.
class ActivitySparkline extends StatefulWidget {
  /// Activity rows for (typically) the last 14 days. Order is not
  /// relied upon — the widget builds a `{date → count}` lookup map
  /// and walks the calendar backwards from today.
  final List<ActivityDay> series;

  /// Optional clock injection point so tests can pin "today" without
  /// freezing wall time. Production callers pass null and we use
  /// `DateTime.now()`.
  final DateTime Function()? clock;

  const ActivitySparkline({super.key, required this.series, this.clock});

  /// Number of day-columns in the sparkline. Backend query is expected
  /// to scope `activitySeries(days: kSparkDays)` to the same window so
  /// the leftmost cells aren't always empty.
  static const int kSparkDays = 14;

  /// Each bar is a thin column with a small gap between bars.
  static const double kBarWidth = 2;
  static const double kBarGap = 1.5;
  static const double kPitch = kBarWidth + kBarGap;
  static const double kMaxHeight = 12;

  /// Whole-widget bounding size — published so the parent's
  /// `Positioned(top:, right:)` can offset against a known dimension.
  static const double kWidth = kSparkDays * kPitch - kBarGap;
  static const double kHeight = kMaxHeight;

  /// Pure helper exposed for tests — returns the rendered bars'
  /// counts in display order (left → right, oldest → today). Empty
  /// when the series carries no activity inside the visible window.
  static List<int> samplesFor(
    List<ActivityDay> series, {
    DateTime Function()? clock,
  }) {
    final byDate = <String, int>{
      for (final d in series)
        if (d.date.isNotEmpty) d.date: d.count,
    };
    final today = ((clock ?? DateTime.now).call()).toUtc();
    final todayDay = DateTime.utc(today.year, today.month, today.day);
    final samples = <int>[];
    for (int i = kSparkDays - 1; i >= 0; i--) {
      final day = todayDay.subtract(Duration(days: i));
      final key = _yyyyMmDd(day);
      samples.add(byDate[key] ?? 0);
    }
    return samples;
  }

  /// Pure helper exposed for tests — does the widget collapse to
  /// `SizedBox.shrink()` for this series? True when the visible
  /// 14-day window contains no posts.
  static bool isEmptyFor(
    List<ActivityDay> series, {
    DateTime Function()? clock,
  }) {
    return samplesFor(series, clock: clock).every((c) => c <= 0);
  }

  static String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  State<ActivitySparkline> createState() => _ActivitySparklineState();
}

class _ActivitySparklineState extends State<ActivitySparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late List<int> _samples;
  // Tri-state: null until `didChangeDependencies` has consumed the
  // MediaQuery once, so the initial sync isn't short-circuited.
  bool? _reduced;

  @override
  void initState() {
    super.initState();
    _samples = ActivitySparkline.samplesFor(widget.series, clock: widget.clock);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void didUpdateWidget(ActivitySparkline old) {
    super.didUpdateWidget(old);
    if (!identical(widget.series, old.series) || widget.clock != old.clock) {
      _samples = ActivitySparkline.samplesFor(
        widget.series,
        clock: widget.clock,
      );
      _refreshAnimation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    _refreshAnimation();
  }

  /// Start the pulse only when there's activity *today* — the
  /// rightmost bar is the only one that animates, so a silent today
  /// means a static sparkline. Skip entirely under reduced motion.
  void _refreshAnimation() {
    final todayHasActivity = _samples.isNotEmpty && _samples.last > 0;
    if (_reduced == true || !todayHasActivity) {
      if (_pulse.isAnimating) _pulse.stop();
      return;
    }
    if (!_pulse.isAnimating) _pulse.repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_samples.every((c) => c <= 0)) {
      return const SizedBox.shrink();
    }

    final maxCount = _samples.reduce((a, b) => a > b ? a : b);
    final totalCount = _samples.fold<int>(0, (sum, c) => sum + c);

    return SizedBox(
      width: ActivitySparkline.kWidth,
      height: ActivitySparkline.kHeight,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          // Explicit `size:` so the painter and the tests have a
          // single source of truth for the painted bounds.
          return CustomPaint(
            size: const Size(
              ActivitySparkline.kWidth,
              ActivitySparkline.kHeight,
            ),
            painter: _SparklinePainter(
              samples: _samples,
              maxCount: maxCount,
              totalCount: totalCount,
              pulsePhase: _reduced == true ? 0.5 : _pulse.value,
              pulseEnabled: _reduced != true,
            ),
          );
        },
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> samples;
  final int maxCount;
  final int totalCount;
  final double pulsePhase;
  final bool pulseEnabled;

  const _SparklinePainter({
    required this.samples,
    required this.maxCount,
    required this.totalCount,
    required this.pulsePhase,
    required this.pulseEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxCount <= 0) return;

    // Overall intensity multiplier — busier artists glow brighter
    // (the "活発であればあるほど強く光る" requirement). Caps so the
    // brightest tier isn't washing out next to the cover image.
    // Anchored at sqrt to soften the curve: doubling posts shouldn't
    // double the visible glow.
    final activityBoost = (totalCount / 30).clamp(0.0, 1.0);
    final intensity = 0.55 + 0.45 * (activityBoost * activityBoost);

    final lastIndex = samples.length - 1;
    for (int i = 0; i < samples.length; i++) {
      final count = samples[i];
      if (count <= 0) continue;

      // Height = (this day's count) / max-count-in-window, never below
      // a 2px minimum so a single post still reads as a visible nub.
      final relHeight = count / maxCount;
      final rawHeight = relHeight * ActivitySparkline.kMaxHeight;
      final height = rawHeight < 2 ? 2.0 : rawHeight;

      final x = i * ActivitySparkline.kPitch;
      final y = ActivitySparkline.kHeight - height;
      final rect = Rect.fromLTWH(x, y, ActivitySparkline.kBarWidth, height);

      // Recency gradient — leftmost bars are dim, rightmost bright.
      final recency = lastIndex == 0 ? 1.0 : i / lastIndex;
      // Pulse only the rightmost bar; other bars stay static. The
      // pulse amplitude is gentle (±10%) so the column feels alive
      // without flickering.
      double pulseAlpha = 0;
      if (pulseEnabled && i == lastIndex) {
        // Triangle wave from the controller's 0..1 progress —
        // smoother than sin, cheaper to compute, and the eye reads
        // the same.
        final t = (pulsePhase - 0.5).abs();
        pulseAlpha = (0.5 - t) * 0.2;
      }
      final baseAlpha = (0.35 + 0.65 * recency) * intensity;
      final alpha = (baseAlpha + pulseAlpha).clamp(0.0, 1.0);

      // Color shifts cyan → violet across the row so today's bar
      // pops against the cover even on cyan-tinted artwork.
      final color = Color.lerp(
        colorActivityBase,
        colorActivityHigh,
        recency * 0.7,
      )!;
      final bodyPaint = Paint()..color = color.withValues(alpha: alpha);

      final radius = const Radius.circular(1);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), bodyPaint);

      // Halo on the rightmost active bar so the eye finds "today"
      // even at a glance against busy cover art.
      if (i == lastIndex) {
        final haloPaint = Paint()
          ..color = color.withValues(alpha: alpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(0.8), radius),
          haloPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) {
    if (!_listIntEquals(samples, old.samples) ||
        maxCount != old.maxCount ||
        totalCount != old.totalCount ||
        pulseEnabled != old.pulseEnabled) {
      return true;
    }
    return pulseEnabled && pulsePhase != old.pulsePhase;
  }

  static bool _listIntEquals(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
