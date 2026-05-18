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
  /// can offset against these. Roughly two and a half full
  /// wavelengths fit across the width when amplitude is at its peak.
  static const double kWidth = 36;
  static const double kHeight = 12;

  /// Number of sin-wave cycles drawn across the width. Higher = more
  /// dense oscillation; this value feels like a heartbeat trace at
  /// this size.
  static const double kCycles = 1.5;

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

/// Public for tests — paints a single horizontal sin-wave trace.
/// `phase` is a 0..1 progress through one full wavelength shift, so
/// the wave appears to scroll to the right when `phase` rises
/// linearly from 0 → 1 → wraps.
@visibleForTesting
class ActivityWavePainter extends CustomPainter {
  final ActivityWaveTier tier;
  final double phase;

  const ActivityWavePainter({required this.tier, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final amplitude = ActivityWave.amplitudeFor(tier);
    final color = ActivityWave.colorFor(tier);
    if (color.a == 0) return;

    final midY = size.height / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    // Flat-tier shortcut: draw a single horizontal line. Cheap and
    // visually correct (zero amplitude would render the same with
    // the sin loop below, just wastefully).
    if (amplitude <= 0) {
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
      return;
    }

    final path = Path();
    final steps = size.width.ceil() * 2; // 2 samples per logical px
    final twoPi = math.pi * 2;
    final cycles = ActivityWave.kCycles;
    final phaseOffset = phase * twoPi;
    for (int i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      // Wave function: y = midY - amplitude * sin(2π·cycles·(x/width) + phase)
      // Negative because canvas y grows downward — using minus keeps
      // a rising-wave crest read as "up" intuitively.
      final t = (x / size.width) * twoPi * cycles + phaseOffset;
      final y = midY - amplitude * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Soft halo for the very-recent tier so the right edge picks up
    // a subtle glow — reinforces "this artist is hot right now".
    if (tier == ActivityWaveTier.veryRecent) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
      canvas.drawPath(path, glowPaint);
    }
  }

  @override
  bool shouldRepaint(ActivityWavePainter old) {
    if (tier != old.tier) return true;
    // Skip phase comparison for the flat / hidden tiers — they're
    // static lines and won't repaint.
    if (!ActivityWave.hasMovement(tier)) return false;
    return phase != old.phase;
  }
}
