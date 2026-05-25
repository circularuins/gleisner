import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../models/track.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/track_activity.dart';

/// Layout mode for the track rail.
///
/// `automatic` lets `build` decide between a static single row and the
/// marquee based on whether all chips fit within the available width.
/// `expanded` is the user-driven multi-row Wrap that surfaces every chip
/// for selection.
enum _RailMode { automatic, expanded }

/// Pixel height reserved for the marquee viewport. Sized to give the
/// chip (~22 dp) plus ~7 dp on each side of headroom for the highlight
/// glow's blur so the pulse is visible without the `ClipRect` shaving
/// it off. Still ~10 dp shorter than the original two-row Wrap.
const double _marqueeViewportHeight = 36;

/// Replacement for the original `_TrackSelector` that stops the chip list
/// from eating two or more rows of the timeline.
///
/// Behavior:
///   - When the full chip set fits on one row → static row, no animation.
///   - When it overflows → "All" stays pinned at the left, the rest scroll
///     leftward as a marquee.
///   - Tapping the marquee region expands into a multi-row Wrap (week
///     activity descending) for selection. Selecting a chip, idling for
///     `motionRailExpandedIdleTimeout`, or the app returning to the
///     foreground collapses it back to the marquee.
///   - Tracks with posts in the last 24h pulse with a white glow; tracks
///     with >= 5 posts in the last 7 days carry a steady track-colored
///     halo. Both signals are gated by `MediaQuery.disableAnimationsOf`.
class MarqueeTrackRail extends StatefulWidget {
  final List<Track> tracks;
  final List<Post> posts;
  final Set<String> selectedTrackIds;
  final bool allSelected;
  final int shuffleSeed;
  final ValueChanged<String> onToggleTrack;
  final VoidCallback onToggleAll;
  final VoidCallback onReshuffle;

  const MarqueeTrackRail({
    super.key,
    required this.tracks,
    required this.posts,
    required this.selectedTrackIds,
    required this.allSelected,
    required this.shuffleSeed,
    required this.onToggleTrack,
    required this.onToggleAll,
    required this.onReshuffle,
  });

  @override
  State<MarqueeTrackRail> createState() => _MarqueeTrackRailState();
}

class _MarqueeTrackRailState extends State<MarqueeTrackRail>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _marqueeController;
  late final AnimationController _pulseController;
  Timer? _expandTimer;
  bool _hoverPaused = false;
  _RailMode _mode = _RailMode.automatic;

  /// Wall-clock time of the last `AppLifecycleState.paused`, used to
  /// debounce the resume-driven reshuffle. iOS / Android raise
  /// `paused → resumed` for transient system events (notification
  /// banners, biometric prompts, control center, etc.), so we only
  /// treat a *meaningfully long* absence as a genuine "user came back
  /// to the app" signal.
  DateTime? _lastPausedAt;

  /// Memoized chip-width estimates keyed by label text. Rebuilt only when
  /// the label set changes between builds.
  Map<String, double> _chipWidthCache = const {};

  /// Attached to the leading marquee chip-row so we can read its actual
  /// laid-out width after the first frame. The text estimate is used to
  /// pick "marquee vs static" before the real measurement is available,
  /// but the marquee animation distance is the measured value — under-
  /// estimating made the two copies overlap; over-estimating left a
  /// visible blank gap at the wrap point.
  final GlobalKey _measureKey = GlobalKey();

  /// Most recent measured width of one chip-row, or `null` until the
  /// first frame has been laid out.
  double? _measuredChipRowWidth;

  /// Most recent measured height of one chip-row. Used to center the
  /// marquee chips inside the (taller) viewport so they align with the
  /// pinned "All" chip on the same row.
  double? _measuredChipRowHeight;

  // Snapshot of the last marquee parameters we asked the controller to
  // run with — used to avoid restarting the animation on every build.
  double _currentScrollDistance = 0;
  bool _wantsMarquee = false;
  bool _lastDisableAnimations = false;

  @override
  void initState() {
    super.initState();
    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    // Start the pulse at its visible mid-point so reduced-motion users
    // see the static glow without ever ticking. `build` toggles the
    // repeat on/off based on `MediaQuery.disableAnimationsOf`.
    _pulseController = AnimationController(
      vsync: this,
      duration: motionPulsePeriod,
      value: 0.5,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expandTimer?.cancel();
    _marqueeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    // Only fire on a meaningfully long absence — transient system
    // events (notification banners, biometric prompts, control
    // center, push notifications) raise paused → resumed within
    // seconds and should NOT bump the shuffleSeed or collapse the
    // expanded view (the user did not "return to the app" in their
    // mental model).
    final pausedAt = _lastPausedAt;
    _lastPausedAt = null;
    if (pausedAt == null ||
        DateTime.now().difference(pausedAt) < const Duration(seconds: 60)) {
      return;
    }
    // Defer to next frame: didChangeAppLifecycleState fires outside the
    // build phase, but parent rebuilds triggered by `onReshuffle` should
    // not race the resume-paint that Flutter is about to schedule.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onReshuffle();
      if (_mode == _RailMode.expanded) _exitExpanded();
    });
  }

  void _enterExpanded() {
    if (_mode == _RailMode.expanded) {
      _restartExpandTimer();
      return;
    }
    setState(() => _mode = _RailMode.expanded);
    _marqueeController.stop();
    _restartExpandTimer();
  }

  void _exitExpanded() {
    if (_mode != _RailMode.expanded) return;
    _expandTimer?.cancel();
    _expandTimer = null;
    // Clear any leftover hover-paused flag — the pointer state from
    // before entering expanded mode would otherwise keep the marquee
    // stopped after the timer fires (especially in DevTools mobile
    // emulation where `onExit` does not fire on touch end).
    _hoverPaused = false;
    setState(() => _mode = _RailMode.automatic);
  }

  void _restartExpandTimer() {
    _expandTimer?.cancel();
    _expandTimer = Timer(motionRailExpandedIdleTimeout, () {
      if (mounted) _exitExpanded();
    });
  }

  void _onChipTap(String trackId) {
    widget.onToggleTrack(trackId);
    // Stay in expanded mode so the user can keep toggling multiple
    // tracks; just restart the idle timer.
    if (_mode == _RailMode.expanded) _restartExpandTimer();
  }

  void _onAllChipTap() {
    widget.onToggleAll();
    if (_mode == _RailMode.expanded) _restartExpandTimer();
  }

  void _onHoverEnter() {
    if (_hoverPaused) return;
    _hoverPaused = true;
    if (_marqueeController.isAnimating) _marqueeController.stop();
  }

  void _onHoverExit() {
    if (!_hoverPaused) return;
    _hoverPaused = false;
    if (_wantsMarquee && !_lastDisableAnimations) {
      _marqueeController.repeat();
    }
  }

  double _estimateChipWidth(String label, TextStyle style) {
    final cached = _chipWidthCache[label];
    if (cached != null) return cached;
    // Measure with bold weight (FontWeight.w600). The selected chip
    // renders bold, which is meaningfully wider than the unselected
    // (w400) baseline — under-measuring made the two marquee copies
    // overlap because the wrapping copy started before the first one
    // visually ended.
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: style.copyWith(fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // Chip horizontal padding (8 px each side) + 1 px border each side
    // = 18 px geometric overhead. Extra slack (10 px) absorbs font
    // metric differences between `TextPainter` and the rendered `Text`
    // widget under CanvasKit / Flutter web, plus the halo blur radius
    // when highlighted chips wrap past the end of the strip.
    final width = tp.width + 28;
    _chipWidthCache[label] = width;
    return width;
  }

  /// Read the leading chip-row's actual laid-out size and, if it has
  /// changed by more than 0.5 px, store it and request a rebuild so the
  /// marquee animation cycle distance matches reality (no gap, no
  /// overlap at the wrap point) and the chips stay vertically aligned
  /// with the pinned "All" chip.
  void _scheduleMeasureChipRow() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _measureKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final measuredWidth = box.size.width;
      final measuredHeight = box.size.height;
      if (measuredWidth <= 0 || measuredHeight <= 0) return;
      final widthChanged =
          _measuredChipRowWidth == null ||
          (_measuredChipRowWidth! - measuredWidth).abs() > 0.5;
      final heightChanged =
          _measuredChipRowHeight == null ||
          (_measuredChipRowHeight! - measuredHeight).abs() > 0.5;
      if (widthChanged || heightChanged) {
        setState(() {
          _measuredChipRowWidth = measuredWidth;
          _measuredChipRowHeight = measuredHeight;
        });
      }
    });
  }

  void _schedulePulse({
    required bool disableAnimations,
    required bool hasAnyHighlight,
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Stop the ticker whenever the pulse would be invisible — no
      // tracks have a fresh / active highlight, or the user has
      // reduced-motion enabled. Idle artists (common in Phase 0)
      // would otherwise spin a vsync-rate ticker forever.
      if (disableAnimations || !hasAnyHighlight) {
        if (_pulseController.isAnimating) _pulseController.stop();
      } else {
        if (!_pulseController.isAnimating) {
          // Plain sawtooth, not `reverse: true`. Each chip computes
          // its own triangular pulse from the raw controller value +
          // a per-chip phase offset so neighboring highlighted chips
          // do not synchronize and visually merge into one block.
          _pulseController.repeat();
        }
      }
    });
  }

  void _scheduleMarquee({
    required bool wantsMarquee,
    required double scrollDistance,
    required bool disableAnimations,
  }) {
    if (_wantsMarquee == wantsMarquee &&
        (_currentScrollDistance - scrollDistance).abs() < 0.5 &&
        _lastDisableAnimations == disableAnimations) {
      return;
    }
    _wantsMarquee = wantsMarquee;
    _currentScrollDistance = scrollDistance;
    _lastDisableAnimations = disableAnimations;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!wantsMarquee || disableAnimations || _hoverPaused) {
        if (_marqueeController.isAnimating) _marqueeController.stop();
        return;
      }
      final durationMs = (scrollDistance / motionMarqueeSpeedDp * 1000)
          .round()
          .clamp(1000, 120000);
      final currentDurationMs =
          _marqueeController.duration?.inMilliseconds ?? -1;
      final needsReset =
          !_marqueeController.isAnimating || currentDurationMs != durationMs;
      if (needsReset) {
        // Reset only when something material changed (cold start,
        // viewport resized, expand → idle 10s collapse). Refreshes
        // that only swap the shuffle order keep the scroll mid-cycle
        // so the rail does not visibly jump back to its head.
        _marqueeController.reset();
        _marqueeController.duration = Duration(milliseconds: durationMs);
      }
      if (!_marqueeController.isAnimating) {
        _marqueeController.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final l10n = context.l10n;
    final activity = computeTrackActivity(widget.posts);
    final hasAnyHighlight = activity.values.any((a) => a.isFresh || a.isActive);
    _schedulePulse(
      disableAnimations: disableAnimations,
      hasAnyHighlight: hasAnyHighlight,
    );

    // Reset chip-width cache if the label set changed between builds.
    final currentLabels = {l10n.all, for (final t in widget.tracks) t.name};
    if (!_chipWidthCache.keys.toSet().containsAll(currentLabels) ||
        _chipWidthCache.length > currentLabels.length * 2) {
      _chipWidthCache = <String, double>{};
    }

    const chipStyle = TextStyle(fontSize: fontSizeSm - 1); // 11
    final allChipWidth = _estimateChipWidth(l10n.all, chipStyle) + spaceSm;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          double tracksWidth = 0;
          for (final t in widget.tracks) {
            tracksWidth += _estimateChipWidth(t.name, chipStyle) + spaceXs;
          }
          final overflows = (allChipWidth + tracksWidth) > maxWidth;

          if (_mode == _RailMode.expanded) {
            _scheduleMarquee(
              wantsMarquee: false,
              scrollDistance: 0,
              disableAnimations: disableAnimations,
            );
            return _buildExpanded(activity, chipStyle);
          }

          if (!overflows) {
            _scheduleMarquee(
              wantsMarquee: false,
              scrollDistance: 0,
              disableAnimations: disableAnimations,
            );
            return _buildStatic(activity, chipStyle);
          }

          // Prefer the measured chip-row width if we have one — the
          // text-painter estimate ends up off by ~10 px on real Web
          // builds, which is enough to either cover or expose the
          // wrap-point between marquee copies.
          final effectiveScrollDistance = _measuredChipRowWidth ?? tracksWidth;
          _scheduleMarquee(
            wantsMarquee: true,
            scrollDistance: effectiveScrollDistance,
            disableAnimations: disableAnimations,
          );
          _scheduleMeasureChipRow();
          return _buildMarquee(
            activity,
            chipStyle,
            allChipWidth: allChipWidth,
            scrollDistance: effectiveScrollDistance,
            disableAnimations: disableAnimations,
          );
        },
      ),
    );
  }

  Widget _buildStatic(
    Map<String, TrackActivity> activity,
    TextStyle chipStyle,
  ) {
    // Single-row layout used when all chips fit. Use the backend order
    // directly — a static row is a stable selector, so reshuffling on
    // every pull-to-refresh / resume would only hurt muscle memory.
    // The marquee path is the only place that benefits from rotation.
    return Row(
      children: [
        _buildAllChip(chipStyle),
        const SizedBox(width: spaceSm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Manual horizontal scroll is still allowed as an escape hatch
            // if the estimate slightly mis-predicts overflow.
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                for (final track in widget.tracks)
                  Padding(
                    padding: const EdgeInsets.only(right: spaceXs),
                    child: _buildTrackChip(track, activity, chipStyle),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarquee(
    Map<String, TrackActivity> activity,
    TextStyle chipStyle, {
    required double allChipWidth,
    required double scrollDistance,
    required bool disableAnimations,
  }) {
    final shuffled = widget.shuffleSeed == 0
        ? widget.tracks
        : shuffleTracks(widget.tracks, widget.shuffleSeed);

    Widget chipRow({Key? key}) => Row(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final track in shuffled)
          Padding(
            padding: const EdgeInsets.only(right: spaceXs),
            child: _buildTrackChip(track, activity, chipStyle),
          ),
      ],
    );

    // Marquee viewport:
    //   - `SizedBox(height: ...)` gives the Stack a finite height. A
    //     Stack with only `Positioned` children otherwise inherits
    //     `maxHeight: infinity` from the column above us and the
    //     parent layout collapses the rail to 0 px — was visible as
    //     the chips disappearing on narrow viewports (first round).
    //   - `ClipRect` crops the painting horizontally so the chip-row
    //     copies render only inside the viewport.
    //   - Each chip-row copy is `Positioned(left, top)`. With only the
    //     two coordinates set the child receives loose constraints,
    //     so the `Row` lays out at its natural width without tripping
    //     the parent's bounded-width constraint (no RenderFlex stripe).
    //   - `IgnorePointer` swallows chip-level taps during the marquee
    //     so the outer `GestureDetector` always wins and expands the
    //     rail (otherwise the underlying chip would toggle its
    //     selection without ever opening the expand view).
    // Vertically center the chips inside the viewport so they line up
    // with the pinned "All" chip (which the parent `Row` centers in
    // the same available height). Falls back to top:0 on the very
    // first frame before measurement lands; the next frame snaps
    // into place.
    final double chipTop = _measuredChipRowHeight == null
        ? 0
        : ((_marqueeViewportHeight - _measuredChipRowHeight!) / 2).clamp(
            0.0,
            _marqueeViewportHeight,
          );

    Widget marqueeChip(double translateX, {Key? key}) {
      return Positioned(
        left: translateX,
        top: chipTop,
        child: IgnorePointer(child: chipRow(key: key)),
      );
    }

    final marqueeContent = SizedBox(
      height: _marqueeViewportHeight,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _marqueeController,
          builder: (context, _) {
            final progress = disableAnimations ? 0.0 : _marqueeController.value;
            final offset = -progress * scrollDistance;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Leading copy carries the measurement key so the next
                // post-frame can read its real width.
                marqueeChip(offset, key: _measureKey),
                // Wrapping copy keeps the strip seamless past the
                // viewport edge for any scroll distance.
                marqueeChip(offset + scrollDistance),
              ],
            );
          },
        ),
      ),
    );

    Widget marqueeArea = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enterExpanded,
      child: Tooltip(
        message: context.l10n.trackRailExpandHint,
        child: marqueeContent,
      ),
    );

    if (kIsWeb) {
      marqueeArea = MouseRegion(
        onEnter: (_) => _onHoverEnter(),
        onExit: (_) => _onHoverExit(),
        child: marqueeArea,
      );
    }

    return Row(
      children: [
        _buildAllChip(chipStyle),
        const SizedBox(width: spaceSm),
        Expanded(child: marqueeArea),
      ],
    );
  }

  Widget _buildExpanded(
    Map<String, TrackActivity> activity,
    TextStyle chipStyle,
  ) {
    // Expanded uses the same shuffled order as the marquee so swapping
    // between modes does not visually rearrange the chips under the
    // user's finger. Activity-descending sort felt like a stronger
    // signal in theory but read as a jarring reflow in practice.
    final ordered = widget.shuffleSeed == 0
        ? widget.tracks
        : shuffleTracks(widget.tracks, widget.shuffleSeed);
    return Wrap(
      spacing: spaceXs,
      runSpacing: spaceXxs,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: spaceSm),
          child: _buildAllChip(chipStyle),
        ),
        for (final track in ordered)
          _buildTrackChip(track, activity, chipStyle),
      ],
    );
  }

  Widget _buildAllChip(TextStyle chipStyle) {
    return _Chip(
      label: context.l10n.all,
      selected: widget.allSelected,
      selectedColor: colorInteractive,
      borderRadius: BorderRadius.circular(radiusSm),
      onTap: _onAllChipTap,
      textStyle: chipStyle,
    );
  }

  Widget _buildTrackChip(
    Track track,
    Map<String, TrackActivity> activity,
    TextStyle chipStyle,
  ) {
    final stats = activity[track.id] ?? TrackActivity.empty;
    final selected = widget.selectedTrackIds.contains(track.id);
    // Deterministic phase offset in [0, 1) keyed on track id so the
    // pulse never lands on the same beat for two chips at once. Using
    // the hash mod-100 gives 100 distinct phases, well beyond what
    // the eye can tell apart on a short rail.
    final phaseOffset = (track.id.hashCode % 100).abs() / 100.0;
    return _HighlightedChip(
      pulseAnimation: _pulseController,
      disableAnimations: _lastDisableAnimations,
      activity: stats,
      trackColor: track.displayColor,
      phaseOffset: phaseOffset,
      child: _Chip(
        label: track.name,
        selected: selected,
        selectedColor: track.displayColor,
        onTap: () => _onChipTap(track.id),
        textStyle: chipStyle,
      ),
    );
  }
}

/// The base chip — visually equivalent to the original `_TrackSelector`
/// inner chip. Kept as a stateless leaf so the highlight wrapper can sit
/// outside it without touching its rendering.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  final TextStyle textStyle;
  final BorderRadius? borderRadius;

  const _Chip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    required this.textStyle,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(10),
          color: selected ? selectedColor.withValues(alpha: 0.2) : null,
          border: Border.all(color: selected ? selectedColor : colorBorder),
        ),
        child: Text(
          label,
          style: textStyle.copyWith(
            color: selected ? selectedColor : colorInteractive,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Adds the freshness pulse + active halo on top of a `_Chip`.
///
/// The pulse is driven by an `AnimationController` owned by the parent
/// rail (one controller for the entire rail instead of one-per-chip
/// keeps the widget tree light and stays well below the `Ticker` cost
/// of many simultaneous animations).
class _HighlightedChip extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final bool disableAnimations;
  final TrackActivity activity;
  final Color trackColor;
  final double phaseOffset;
  final Widget child;

  const _HighlightedChip({
    required this.pulseAnimation,
    required this.disableAnimations,
    required this.activity,
    required this.trackColor,
    required this.phaseOffset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isFresh = activity.isFresh;
    final isActive = activity.isActive;
    if (!isFresh && !isActive) return child;

    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, _) {
        // The shared controller runs as a sawtooth 0 → 1. Each chip
        // converts that to its own triangular pulse (0 → 1 → 0) using
        // a per-chip `phaseOffset`, so highlighted neighbors never
        // peak simultaneously and never blur into one big glow.
        //
        // Reduced-motion: settle on the midpoint so the glow is
        // visible without animating.
        final double t;
        if (disableAnimations) {
          t = 0.5;
        } else {
          final phase = (pulseAnimation.value + phaseOffset) % 1.0;
          t = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
        }

        // Highlight is only an outer glow. The shadow is painted on a
        // backing plate that is the **same opaque color as the page
        // surface** so the bloom never bleeds through the chip's
        // transparent (unselected) interior — that bleed was the
        // "white text background" the user kept seeing.
        final shadows = <BoxShadow>[
          if (isActive)
            BoxShadow(
              color: trackColor.withValues(alpha: highlightActiveHaloAlpha),
              blurRadius: highlightActiveHaloBlur,
              spreadRadius: 0.5,
            ),
          if (isFresh)
            BoxShadow(
              color: Colors.white.withValues(
                alpha:
                    highlightFreshAlphaMin +
                    (highlightFreshAlphaMax - highlightFreshAlphaMin) * t,
              ),
              blurRadius:
                  highlightFreshBlurMin +
                  (highlightFreshBlurMax - highlightFreshBlurMin) * t,
              spreadRadius: 0.5,
            ),
        ];

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  // Opaque plate that occludes the inner half of the
                  // shadow. Matches the timeline canvas surface so it
                  // is invisible against the page bg.
                  color: colorSurface0,
                  boxShadow: shadows,
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
