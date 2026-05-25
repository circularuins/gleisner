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

  /// Memoized chip-width estimates keyed by label text. Rebuilt only when
  /// the label set changes between builds.
  Map<String, double> _chipWidthCache = const {};

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
    if (state != AppLifecycleState.resumed) return;
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
    if (_mode == _RailMode.expanded) _exitExpanded();
  }

  void _onAllChipTap() {
    widget.onToggleAll();
    if (_mode == _RailMode.expanded) _exitExpanded();
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
    final tp = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // Match _chip's horizontal padding (8 px each side) + border allowance.
    final width = tp.width + 18;
    _chipWidthCache[label] = width;
    return width;
  }

  void _schedulePulse(bool disableAnimations) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (disableAnimations) {
        if (_pulseController.isAnimating) _pulseController.stop();
      } else {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
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
      _marqueeController.duration = Duration(milliseconds: durationMs);
      _marqueeController.repeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    _schedulePulse(disableAnimations);
    final l10n = context.l10n;
    final activity = computeTrackActivity(widget.posts);

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

          _scheduleMarquee(
            wantsMarquee: true,
            scrollDistance: tracksWidth,
            disableAnimations: disableAnimations,
          );
          return _buildMarquee(
            activity,
            chipStyle,
            allChipWidth: allChipWidth,
            scrollDistance: tracksWidth,
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
    // Single-row layout used when all chips fit. We still apply the
    // shuffleSeed so the order is consistent with what marquee mode
    // would have shown if the screen had been narrower.
    final shuffled = widget.shuffleSeed == 0
        ? widget.tracks
        : shuffleTracks(widget.tracks, widget.shuffleSeed);
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
                for (final track in shuffled)
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

    Widget chipRow() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final track in shuffled)
          Padding(
            padding: const EdgeInsets.only(right: spaceXs),
            child: _buildTrackChip(track, activity, chipStyle),
          ),
      ],
    );

    final marqueeContent = LayoutBuilder(
      builder: (context, marqueeConstraints) {
        final viewportWidth = marqueeConstraints.maxWidth;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _marqueeController,
            builder: (context, _) {
              final progress = disableAnimations
                  ? 0.0
                  : _marqueeController.value;
              final offset = -progress * scrollDistance;
              return SizedBox(
                width: viewportWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: offset, top: 0, child: chipRow()),
                    // Wrapping copy keeps the strip seamless past the
                    // viewport edge for any scroll distance.
                    Positioned(
                      left: offset + scrollDistance,
                      top: 0,
                      child: chipRow(),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
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
    final sorted = sortByWeekActivity(widget.tracks, activity);
    return Wrap(
      spacing: spaceXs,
      runSpacing: spaceXxs,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: spaceSm),
          child: _buildAllChip(chipStyle),
        ),
        for (final track in sorted) _buildTrackChip(track, activity, chipStyle),
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
    return _HighlightedChip(
      pulseAnimation: _pulseController,
      disableAnimations: _lastDisableAnimations,
      activity: stats,
      trackColor: track.displayColor,
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
  final Widget child;

  const _HighlightedChip({
    required this.pulseAnimation,
    required this.disableAnimations,
    required this.activity,
    required this.trackColor,
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
        // Reduced-motion: settle on the midpoint of the pulse so the
        // glow is visible without animating.
        final t = disableAnimations ? 0.5 : pulseAnimation.value;
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
            ),
        ];
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: shadows,
          ),
          child: child,
        );
      },
    );
  }
}
