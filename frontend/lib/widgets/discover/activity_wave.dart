import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';

/// Recency tiers driving the wave's visual treatment.
enum ActivityWaveTier {
  /// `< 24h`: tallest amplitude, fastest scroll, brightest cyan.
  veryRecent,

  /// `1-7 d`: mid amplitude, medium scroll.
  recent,

  /// `7-30 d`: small amplitude, slow scroll, dim color.
  dim,

  /// `> 30 d`: amplitude = 0, drawn as a near-flat baseline line.
  /// Still occupies the card's slot so every card carries a beacon
  /// — silence is communicated by *flatness*, not absence.
  flat,

  /// `null` — the artist has no `lastPostedAt`. Widget collapses to
  /// `SizedBox.shrink()` (truly silent).
  hidden,
}

/// Discovery-card "activity wave" (Idea 032 — v3 visual).
///
/// A continuously-traveling sin wave pinned to the top-right of each
/// artist card cover. Amplitude, brightness, and scroll speed all
/// scale with the artist's most-recent-post recency, so an active
/// artist looks like a beating heartbeat monitor while a dormant one
/// flatlines.
///
/// Mapping (driven entirely by `lastPostedAt` — no per-day data
/// needed):
///
///   < 24h: tall amplitude + fast scroll + bright cyan
///   1-7 d: mid amplitude + mid scroll + warm cyan
///   7-30d: small amplitude + slow scroll + dim
///   > 30d: flat (zero amplitude, baseline only)
///   null : hidden (`SizedBox.shrink`)
///
/// All movement is opacity / phase — never `Transform.scale` or
/// layout shifts (ADR 024). Reduced motion freezes the phase at zero
/// (still draws the current tier's wave shape, just not moving).
class ActivityWave extends StatefulWidget {
  /// Timestamp of the artist's most recent visible post (UTC). Picked
  /// up directly from `Artist.lastPostedAt`. `null` collapses the
  /// widget away.
  final DateTime? lastPostedAt;

  /// Optional clock seam so tests can pin recency boundaries without
  /// freezing wall time. Production callers leave this null and we
  /// use `DateTime.now()`.
  final DateTime Function()? clock;

  const ActivityWave({super.key, required this.lastPostedAt, this.clock});

  /// Published dimensions — the parent's `Positioned(top:, right:)`
  /// can offset against these. Layout is
  /// `[EQ bars] [gap] [sin wave] [gap] [EQ bars]` so the trace reads
  /// as a tiny vibration sensor rather than a single worm-like line.
  static const double kWidth = 44;
  static const double kHeight = 12;

  // EQ-bar section knobs. Two bars on each side, narrow and rounded,
  // animated by the same controller as the wave so the whole strip
  // moves in sync. Tier-driven amplitude scales bar heights too.
  static const int kEqBarsPerSide = 2;
  static const double kEqBarWidth = 1.5;
  static const double kEqBarGap = 1.5;
  static const double kEqSectionGap = 2.5; // EQ section ↔ wave

  /// Number of sin-wave cycles drawn across the *wave* section
  /// (between the two EQ sections), not the whole widget. Tuned so
  /// the central wave still reads as a heartbeat trace after losing
  /// horizontal real estate to the EQ bars.
  static const double kCycles = 1.4;

  /// Width of one EQ section (two bars + one gap).
  static double get _eqSectionWidth =>
      kEqBarsPerSide * kEqBarWidth + (kEqBarsPerSide - 1) * kEqBarGap;

  /// Map a `lastPostedAt` (UTC or local — we normalise) to a tier.
  /// Public so tests can pin the boundaries without instantiating
  /// the widget.
  static ActivityWaveTier tierFor(
    DateTime? lastPostedAt, {
    DateTime Function()? clock,
  }) {
    if (lastPostedAt == null) return ActivityWaveTier.hidden;
    final now = (clock ?? DateTime.now).call();
    final age = now.toUtc().difference(lastPostedAt.toUtc());
    if (age.inHours < 24) return ActivityWaveTier.veryRecent;
    if (age.inDays < 7) return ActivityWaveTier.recent;
    if (age.inDays < 30) return ActivityWaveTier.dim;
    return ActivityWaveTier.flat;
  }

  /// Animation cycle for each tier. Lower-activity tiers scroll
  /// slower, and the flat tier doesn't need to scroll at all.
  static Duration durationFor(ActivityWaveTier tier) {
    switch (tier) {
      case ActivityWaveTier.veryRecent:
        return const Duration(milliseconds: 2500);
      case ActivityWaveTier.recent:
        return const Duration(milliseconds: 4000);
      case ActivityWaveTier.dim:
        return const Duration(milliseconds: 6000);
      case ActivityWaveTier.flat:
      case ActivityWaveTier.hidden:
        // Non-zero so a future state-change-back-to-active doesn't
        // have to construct a fresh controller.
        return const Duration(milliseconds: 6000);
    }
  }

  /// Peak amplitude (px) for each tier. Capped at `kHeight / 2` so
  /// the wave never clips against the bounds.
  static double amplitudeFor(ActivityWaveTier tier) {
    switch (tier) {
      case ActivityWaveTier.veryRecent:
        return kHeight * 0.42;
      case ActivityWaveTier.recent:
        return kHeight * 0.25;
      case ActivityWaveTier.dim:
        return kHeight * 0.12;
      case ActivityWaveTier.flat:
      case ActivityWaveTier.hidden:
        return 0;
    }
  }

  /// `true` for tiers whose wave should scroll continuously; `false`
  /// for the flat / hidden tiers that render as a static baseline.
  /// Used by the State to decide whether to repeat the controller,
  /// and by the painter to short-circuit `shouldRepaint`.
  static bool hasMovement(ActivityWaveTier tier) {
    switch (tier) {
      case ActivityWaveTier.veryRecent:
      case ActivityWaveTier.recent:
      case ActivityWaveTier.dim:
        return true;
      case ActivityWaveTier.flat:
      case ActivityWaveTier.hidden:
        return false;
    }
  }

  /// Stroke color for each tier. Cyan throughout — the difference is
  /// alpha, not hue, so the gradient of "alive ←→ dormant" stays
  /// coherent across the row.
  static Color colorFor(ActivityWaveTier tier) {
    switch (tier) {
      case ActivityWaveTier.veryRecent:
        return colorActivityBase.withValues(alpha: 0.95);
      case ActivityWaveTier.recent:
        return colorActivityBase.withValues(alpha: 0.75);
      case ActivityWaveTier.dim:
        return colorActivityBase.withValues(alpha: 0.55);
      case ActivityWaveTier.flat:
        return colorTextMuted.withValues(alpha: 0.45);
      case ActivityWaveTier.hidden:
        return Colors.transparent;
    }
  }

  @override
  State<ActivityWave> createState() => _ActivityWaveState();
}

class _ActivityWaveState extends State<ActivityWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase;
  late ActivityWaveTier _tier;
  // Tri-state: `null` until the first `didChangeDependencies` — see
  // ActivityGrid for the same idiom and rationale.
  bool? _reduced;

  @override
  void initState() {
    super.initState();
    _tier = ActivityWave.tierFor(widget.lastPostedAt, clock: widget.clock);
    _phase = AnimationController(
      vsync: this,
      duration: ActivityWave.durationFor(_tier),
    );
  }

  @override
  void didUpdateWidget(ActivityWave old) {
    super.didUpdateWidget(old);
    if (widget.lastPostedAt != old.lastPostedAt || widget.clock != old.clock) {
      final next = ActivityWave.tierFor(
        widget.lastPostedAt,
        clock: widget.clock,
      );
      if (next != _tier) {
        _tier = next;
        _phase.stop();
        _phase.duration = ActivityWave.durationFor(next);
        _refreshAnimation();
      }
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

  /// Start the phase scroll only when the wave has a non-zero
  /// amplitude *and* reduced motion is off. Flat / hidden / dim with
  /// reduced motion all stay frozen.
  void _refreshAnimation() {
    final shouldAnimate = _reduced != true && ActivityWave.hasMovement(_tier);
    if (!shouldAnimate) {
      if (_phase.isAnimating) _phase.stop();
      return;
    }
    if (!_phase.isAnimating) _phase.repeat();
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tier == ActivityWaveTier.hidden) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ActivityWave.kWidth,
      height: ActivityWave.kHeight,
      child: AnimatedBuilder(
        animation: _phase,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(ActivityWave.kWidth, ActivityWave.kHeight),
            painter: ActivityWavePainter(
              tier: _tier,
              phase: _reduced == true ? 0 : _phase.value,
            ),
          );
        },
      ),
    );
  }
}

/// Public for tests — paints the hybrid sensor: two EQ bars on each
/// side bracket a central traveling sin wave. `phase` is a 0..1
/// progress that drives both the wave's horizontal scroll and each
/// EQ bar's vertical oscillation so the whole strip animates in
/// sync.
@visibleForTesting
class ActivityWavePainter extends CustomPainter {
  final ActivityWaveTier tier;
  final double phase;

  const ActivityWavePainter({required this.tier, required this.phase});

  // Reusable paints — instantiating these every `paint()` call (60fps
  // × N visible cards) churns the GC. Static + `..color = ...` per
  // call keeps allocation off the hot path. `MaskFilter.blur` is the
  // most expensive piece to recreate, so it especially benefits.
  static final Paint _barPaint = Paint();
  static final Paint _wavePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  static final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);

  @override
  void paint(Canvas canvas, Size size) {
    final color = ActivityWave.colorFor(tier);
    if (color.a == 0) return;

    final amplitude = ActivityWave.amplitudeFor(tier);
    final midY = size.height / 2;
    final eqWidth = ActivityWave._eqSectionWidth;
    final waveStartX = eqWidth + ActivityWave.kEqSectionGap;
    final waveEndX = size.width - eqWidth - ActivityWave.kEqSectionGap;

    // Left EQ section — phase 0.
    _paintEqBars(
      canvas,
      color: color,
      amplitude: amplitude,
      startX: 0,
      midY: midY,
      phaseOffset: 0,
      maxBarHeight: size.height - 1,
    );

    // Centre wave between the two EQ sections.
    _paintWave(
      canvas,
      color: color,
      amplitude: amplitude,
      startX: waveStartX,
      endX: waveEndX,
      midY: midY,
    );

    // Right EQ section — phase offset by π so the two sides don't
    // pulse in lockstep with each other (slight visual interest).
    _paintEqBars(
      canvas,
      color: color,
      amplitude: amplitude,
      startX: size.width - eqWidth,
      midY: midY,
      phaseOffset: math.pi,
      maxBarHeight: size.height - 1,
    );
  }

  void _paintEqBars(
    Canvas canvas, {
    required Color color,
    required double amplitude,
    required double startX,
    required double midY,
    required double phaseOffset,
    required double maxBarHeight,
  }) {
    _barPaint.color = color;
    final twoPi = math.pi * 2;
    for (int i = 0; i < ActivityWave.kEqBarsPerSide; i++) {
      // Per-bar phase offset — 0.83 rad ≈ 47°. Picked because it's
      // not a simple fraction of π, so adjacent bars never look like
      // they're moving in formation.
      final barPhase = phaseOffset + i * 0.83;
      final t = math.sin(phase * twoPi + barPhase);
      final normalized = 0.5 + 0.5 * t; // 0..1
      // Baseline 2px + tier-driven amplitude. Flat tier collapses
      // to 2px stubs (consistent with the wave's flatline shortcut).
      // `.clamp` returns `num` when bounds are int literals — the
      // explicit `.toDouble()` keeps Flutter's strict types happy.
      final height = (2 + amplitude * 1.4 * normalized)
          .clamp(1.0, maxBarHeight)
          .toDouble();

      final x =
          startX + i * (ActivityWave.kEqBarWidth + ActivityWave.kEqBarGap);
      final rect = Rect.fromLTWH(
        x,
        midY - height / 2,
        ActivityWave.kEqBarWidth,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(ActivityWave.kEqBarWidth / 2),
        ),
        _barPaint,
      );
    }
  }

  void _paintWave(
    Canvas canvas, {
    required Color color,
    required double amplitude,
    required double startX,
    required double endX,
    required double midY,
  }) {
    _wavePaint.color = color;
    final width = endX - startX;
    if (width <= 0) return;

    // Flat-tier shortcut — single baseline line. Skips the path
    // build entirely for dormant artists.
    if (amplitude <= 0) {
      canvas.drawLine(Offset(startX, midY), Offset(endX, midY), _wavePaint);
      return;
    }

    final path = Path();
    final steps = width.ceil() * 2; // 2 samples per logical px
    final twoPi = math.pi * 2;
    final cycles = ActivityWave.kCycles;
    final phaseOffset = phase * twoPi;
    for (int i = 0; i <= steps; i++) {
      final localX = width * i / steps;
      final t = (localX / width) * twoPi * cycles + phaseOffset;
      // Negative so a crest reads as "up" — canvas y grows downward.
      final y = midY - amplitude * math.sin(t);
      final x = startX + localX;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, _wavePaint);

    // Soft halo on the very-recent tier — reinforces "this artist
    // is hot right now" without flooding the card visually. The
    // glow paint (with its expensive MaskFilter.blur) is static-
    // cached too; only its colour changes per draw.
    if (tier == ActivityWaveTier.veryRecent) {
      _glowPaint.color = color.withValues(alpha: 0.35);
      canvas.drawPath(path, _glowPaint);
    }
  }

  @override
  bool shouldRepaint(ActivityWavePainter old) {
    if (tier != old.tier) return true;
    // Static tiers — wave is a baseline line and EQ bars sit at
    // their floor height. No phase comparison needed.
    if (!ActivityWave.hasMovement(tier)) return false;
    return phase != old.phase;
  }
}
