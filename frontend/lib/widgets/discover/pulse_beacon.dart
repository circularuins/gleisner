import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';

/// Discovery-card "pulse beacon" — a small glowing dot in the
/// top-right of the cover image that signals recency of the artist's
/// most recent public post (Idea 032).
///
/// Four states, mapped from `lastPostedAt`:
///   - within 24h: bright cyan, fast breathing pulse
///   - within 7d: warm white, slower pulse
///   - within 30d: dim static glow, no animation
///   - >30d or null: not rendered (silence is a meaningful state)
///
/// The animation is opacity-only — never `Transform.scale` or layout
/// shifts — per ADR 024 ("motion over shape"). Reduced motion
/// (`MediaQuery.disableAnimationsOf`) clamps every state to the
/// static dim treatment so the card stays calm under accessibility
/// settings. Wrapped externally in [RepaintBoundary] by the caller
/// so the pulse can't trigger repaints on the surrounding card.
class PulseBeacon extends StatefulWidget {
  /// ISO 8601 timestamp of the artist's most recent visible post, or
  /// `null` when the discover resolver returns no qualifying post for
  /// this artist. Read from `Artist.lastPostedAt`.
  final DateTime? lastPostedAt;

  /// Optional clock injection point for tests so they can assert
  /// against deterministic recency boundaries without freezing
  /// `DateTime.now()`. Production callers leave this null and we use
  /// `DateTime.now()`.
  final DateTime Function()? clock;

  const PulseBeacon({super.key, required this.lastPostedAt, this.clock});

  /// Diameter of the dot. Public so the parent can pad the
  /// `Positioned(top:, right:)` offsets consistently — keep them in
  /// sync if you change this.
  static const double dotSize = 10;

  /// Map `lastPostedAt` to a beacon state. Public so tests can pin
  /// the recency boundaries without standing up a widget tree.
  /// `clock` is the testable seam — production passes null and we
  /// use `DateTime.now()`.
  static PulseBeaconState stateFor(
    DateTime? lastPostedAt, {
    DateTime Function()? clock,
  }) {
    if (lastPostedAt == null) return PulseBeaconState.hidden;
    final now = (clock ?? DateTime.now).call();
    final age = now.toUtc().difference(lastPostedAt.toUtc());
    if (age.inHours < 24) return PulseBeaconState.veryRecent;
    if (age.inDays < 7) return PulseBeaconState.recent;
    if (age.inDays < 30) return PulseBeaconState.dim;
    return PulseBeaconState.hidden;
  }

  @override
  State<PulseBeacon> createState() => _PulseBeaconState();
}

/// Recency buckets that the widget renders. Internal — exported only
/// via [PulseBeacon.stateFor] for tests.
enum PulseBeaconState {
  /// `< 24h` since the last post. Brightest tier, fastest pulse.
  veryRecent,

  /// `1-7 days`. Mid-brightness, slower pulse.
  recent,

  /// `7-30 days`. Dim static glow — no animation even with motion on.
  dim,

  /// `> 30 days` or `lastPostedAt == null`. Widget collapses to
  /// `SizedBox.shrink()` — silence reads as "no recent activity".
  hidden,
}

class _PulseBeaconState extends State<PulseBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late PulseBeaconState _stateValue;
  // Tri-state: `null` until the first `didChangeDependencies` so the
  // initial sync isn't short-circuited as "no change". After that
  // it's true / false and matches the OS setting.
  bool? _reduced;

  @override
  void initState() {
    super.initState();
    _stateValue = PulseBeacon.stateFor(
      widget.lastPostedAt,
      clock: widget.clock,
    );
    _pulse = AnimationController(
      vsync: this,
      duration: _durationFor(_stateValue),
    );
    // `repeat()` only kicks in after `didChangeDependencies` resolves
    // the reduced-motion setting. Avoids racing on the first frame.
  }

  @override
  void didUpdateWidget(PulseBeacon old) {
    super.didUpdateWidget(old);
    if (widget.lastPostedAt != old.lastPostedAt || widget.clock != old.clock) {
      final next = PulseBeacon.stateFor(
        widget.lastPostedAt,
        clock: widget.clock,
      );
      if (next != _stateValue) {
        _stateValue = next;
        _pulse.stop();
        _pulse.duration = _durationFor(next);
        _restartIfAnimating();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _pulse.stop();
    } else {
      _restartIfAnimating();
    }
  }

  void _restartIfAnimating() {
    if (_reduced == true) return;
    if (_stateValue == PulseBeaconState.veryRecent ||
        _stateValue == PulseBeaconState.recent) {
      if (!_pulse.isAnimating) _pulse.repeat();
    }
  }

  static Duration _durationFor(PulseBeaconState state) {
    switch (state) {
      case PulseBeaconState.veryRecent:
        return const Duration(milliseconds: 1200);
      case PulseBeaconState.recent:
        return const Duration(milliseconds: 2000);
      case PulseBeaconState.dim:
      case PulseBeaconState.hidden:
        // Idle durations — the controller is stopped in these states.
        // Pick a non-zero value so a future restart doesn't blow up.
        return const Duration(milliseconds: 2000);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String? _semanticLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (_stateValue) {
      case PulseBeaconState.veryRecent:
        return l10n.pulseBeaconActiveDay;
      case PulseBeaconState.recent:
        return l10n.pulseBeaconActiveWeek;
      case PulseBeaconState.dim:
        return l10n.pulseBeaconActiveMonth;
      case PulseBeaconState.hidden:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stateValue == PulseBeaconState.hidden) {
      return const SizedBox.shrink();
    }

    // Static tiers (dim + reduced-motion fallbacks) just render the
    // baseline alpha — no AnimatedBuilder, no controller cost at all.
    // `_reduced` may briefly be null before the first
    // `didChangeDependencies`; treat that as "motion allowed" so
    // first paint isn't a fixed-alpha snapshot of an active state.
    final animates =
        _reduced != true &&
        (_stateValue == PulseBeaconState.veryRecent ||
            _stateValue == PulseBeaconState.recent);
    final dot = animates
        ? AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) =>
                _PulseDot(state: _stateValue, animationValue: _pulse.value),
          )
        : _PulseDot(state: _stateValue, animationValue: 0.5);

    return Semantics(
      label: _semanticLabel(context),
      container: true,
      child: dot,
    );
  }
}

/// Pure presentational dot. Receives a 0..1 [animationValue] from the
/// parent (or `0.5` baseline for the static tiers) and maps it to the
/// glowing dot's alpha. No timer of its own.
class _PulseDot extends StatelessWidget {
  final PulseBeaconState state;
  final double animationValue;

  const _PulseDot({required this.state, required this.animationValue});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(state);
    final base = _baseAlphaFor(state);
    final amp = _ampFor(state);
    // sin-wave over a 0..1 controller phase. Static states never see
    // this called with a non-baseline `animationValue`, so `amp = 0`
    // collapses the formula to `base` automatically.
    final alpha = (base + amp * (0.5 - (animationValue - 0.5).abs())).clamp(
      0.0,
      1.0,
    );
    final dotAlpha = alpha.toDouble();
    final haloAlpha = (dotAlpha * 0.6).clamp(0.0, 1.0);
    final size = PulseBeacon.dotSize;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: dotAlpha),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: haloAlpha),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorFor(PulseBeaconState state) {
    switch (state) {
      case PulseBeaconState.veryRecent:
        return colorActivityBase; // cyan
      case PulseBeaconState.recent:
        return colorActivityHigh; // warm violet — distinct from 24h
      case PulseBeaconState.dim:
        return colorTextMuted; // calm, no glow drama
      case PulseBeaconState.hidden:
        return Colors.transparent;
    }
  }

  static double _baseAlphaFor(PulseBeaconState state) {
    switch (state) {
      case PulseBeaconState.veryRecent:
        return 0.85;
      case PulseBeaconState.recent:
        return 0.65;
      case PulseBeaconState.dim:
        return 0.45;
      case PulseBeaconState.hidden:
        return 0;
    }
  }

  /// Animation amplitude — how far above/below the base alpha the
  /// breathing reaches. Zero for static states.
  static double _ampFor(PulseBeaconState state) {
    switch (state) {
      case PulseBeaconState.veryRecent:
        return 0.25;
      case PulseBeaconState.recent:
        return 0.15;
      case PulseBeaconState.dim:
      case PulseBeaconState.hidden:
        return 0;
    }
  }
}
