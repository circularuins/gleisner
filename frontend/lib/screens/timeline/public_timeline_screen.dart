import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../models/timeline_item.dart';
import '../../models/track.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/public_timeline_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../utils/constellation_layout.dart';
import '../../widgets/timeline/constellation_painter.dart';
import '../../widgets/timeline/milestone_detail_sheet.dart';
import '../../widgets/timeline/milestone_node_card.dart';
import '../../widgets/timeline/node_card.dart';
import '../../widgets/timeline/post_detail_sheet.dart';
import '../../theme/gleisner_assets.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/common/artist_not_found_view.dart';

class PublicTimelineScreen extends ConsumerStatefulWidget {
  final String username;

  const PublicTimelineScreen({super.key, required this.username});

  @override
  ConsumerState<PublicTimelineScreen> createState() =>
      _PublicTimelineScreenState();
}

class _PublicTimelineScreenState extends ConsumerState<PublicTimelineScreen>
    with SingleTickerProviderStateMixin {
  double? _lastWidth;
  double? _lastHeight;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  String? _focusedPostId;

  // Synapse dot animation — same as timeline_screen
  late final AnimationController _dotController;

  @override
  void dispose() {
    _dotController.dispose();
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsProvider.notifier).trackPageView('/@:username');
    });
    _dotController = AnimationController(
      duration: const Duration(seconds: 35),
      vsync: this,
    )..repeat();
    Future.microtask(() {
      ref.read(publicTimelineProvider.notifier).loadArtist(widget.username);
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(publicTimelineProvider);
    final tuneIn = ref.watch(tuneInProvider);
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;
    final artistId = timeline.artist?.id;
    final isTunedIn = artistId != null && tuneIn.isTunedIn(artistId);
    // Hide Tune In on own public timeline
    final isSelf =
        isAuthenticated &&
        timeline.artist != null &&
        timeline.artist!.artistUsername == widget.username;

    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: spaceSm),
              child: SvgPicture.asset(
                GleisnerAssets.logoIcon,
                height: 28,
                excludeFromSemantics: true,
              ),
            ),
            Flexible(
              child: Text(
                timeline.artist?.displayName ??
                    timeline.artist?.artistUsername ??
                    '@${widget.username}',
                style: const TextStyle(color: colorTextPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (timeline.artist != null) ...[
              const SizedBox(width: spaceSm),
              Text(
                '${timeline.artist!.tunedInCount}',
                style: const TextStyle(
                  color: colorTextMuted,
                  fontSize: fontSizeSm,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.headphones, size: 12, color: colorTextMuted),
            ],
          ],
        ),
        actions: [
          // Tune In button (ADR 013) — not shown on own timeline
          if (isAuthenticated && artistId != null && !isSelf)
            Padding(
              padding: const EdgeInsets.only(right: spaceSm),
              child: _TuneInButton(
                isTunedIn: isTunedIn,
                onTap: () async {
                  final tunedIn = await ref
                      .read(tuneInProvider.notifier)
                      .toggleTuneIn(artistId);
                  if (tunedIn && context.mounted) {
                    // ADR 013: auto-navigate to Timeline tab with this artist
                    context.go('/timeline');
                  }
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (timeline.artist != null && timeline.artist!.tracks.isNotEmpty)
            _TrackSelector(
              tracks: timeline.artist!.tracks,
              selectedTrackIds: timeline.selectedTrackIds,
              allSelected: timeline.allSelected,
              onToggleTrack: (trackId) => ref
                  .read(publicTimelineProvider.notifier)
                  .toggleTrack(trackId),
              onToggleAll: () =>
                  ref.read(publicTimelineProvider.notifier).toggleAll(),
            ),
          if (timeline.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                timeline.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          Expanded(
            child: timeline.isLoading && timeline.posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : timeline.posts.isEmpty
                ? Center(
                    child: timeline.artist == null
                        ? const ArtistNotFoundView(showBackButton: false)
                        : Text(
                            'No posts yet',
                            style: TextStyle(
                              color: colorInteractive,
                              fontSize: theme.textTheme.bodyLarge?.fontSize,
                            ),
                          ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(publicTimelineProvider.notifier).refresh(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final height = constraints.maxHeight;
                        final useHorizontal = isDesktop(width);
                        if (_lastWidth != width || _lastHeight != height) {
                          _lastWidth = width;
                          _lastHeight = height;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!context.mounted) return;
                            ref
                                .read(publicTimelineProvider.notifier)
                                .computeLayout(
                                  width,
                                  height: height,
                                  horizontal: useHorizontal,
                                );
                          });
                        }

                        final layout = timeline.layout;
                        if (layout == null) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        return NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            _scrollOffset.value = n.metrics.pixels;
                            return false;
                          },
                          child: SingleChildScrollView(
                            scrollDirection: layout.isHorizontal
                                ? Axis.horizontal
                                : Axis.vertical,
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: GestureDetector(
                              onTap: () {
                                if (timeline.constellationPostIds != null) {
                                  ref
                                      .read(publicTimelineProvider.notifier)
                                      .clearConstellation();
                                } else if (_focusedPostId != null) {
                                  setState(() => _focusedPostId = null);
                                }
                              },
                              child: SizedBox(
                                height: layout.isHorizontal
                                    ? constraints.maxHeight
                                    : layout.totalHeight,
                                width: layout.isHorizontal
                                    ? layout.totalWidth
                                    : null,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: AnimatedBuilder(
                                        animation: _dotController,
                                        builder: (context, _) => CustomPaint(
                                          painter: ConstellationPainter(
                                            layout: layout,
                                            constellationPostIds:
                                                timeline.constellationPostIds,
                                            animationValue:
                                                _dotController.value,
                                            scrollOffset: _scrollOffset.value,
                                            viewportHeight:
                                                constraints.maxHeight,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Date labels rebuild only on scroll
                                    ValueListenableBuilder<double>(
                                      valueListenable: _scrollOffset,
                                      builder: (context, offset, _) {
                                        return Stack(
                                          children: _buildDateLabels(
                                            layout,
                                            offset,
                                            layout.isHorizontal
                                                ? constraints.maxWidth
                                                : constraints.maxHeight,
                                          ),
                                        );
                                      },
                                    ),
                                    ..._buildNodes(
                                      layout,
                                      timeline.constellationPostIds,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          // Constellation highlight banner
          if (timeline.constellationPostIds != null)
            Container(
              color: colorSurface1,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: colorInteractive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _constellationLabel(timeline),
                      style: const TextStyle(
                        color: colorTextSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref
                        .read(publicTimelineProvider.notifier)
                        .clearConstellation(),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: colorInteractive,
                    ),
                  ),
                ],
              ),
            ),
          // Login CTA banner for unauthenticated users
          if (!isAuthenticated)
            Container(
              color: colorSurface1,
              padding: const EdgeInsets.symmetric(
                horizontal: spaceLg,
                vertical: spaceMd,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: colorAccentGold,
                  ),
                  const SizedBox(width: spaceMd),
                  Expanded(
                    child: Text(
                      'Discover more artists',
                      style: textHeading.copyWith(fontSize: 13),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => context.go('/signup'),
                    child: const Text('Sign up'),
                  ),
                  const SizedBox(width: spaceSm),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Login'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _constellationLabel(TimelineState timeline) {
    final name = timeline.posts
        .where(
          (p) =>
              timeline.constellationPostIds!.contains(p.id) &&
              p.constellation != null,
        )
        .map((p) => p.constellation!.name)
        .firstOrNull;
    final count = timeline.constellationPostIds!.length;
    return name != null
        ? '$name · $count posts'
        : 'Constellation · $count posts';
  }

  List<Positioned> _buildNodes(
    LayoutResult layout,
    Set<String>? constellationIds,
  ) {
    final nodes = <Positioned>[];
    Positioned? focusedNode;

    for (int i = 0; i < layout.nodes.length; i++) {
      final node = layout.nodes[i];
      final dimmed =
          constellationIds != null && !constellationIds.contains(node.item.id);

      final Widget card;
      final bool isFocused;

      switch (node.item) {
        case PostItem(:final post):
          isFocused = post.id == _focusedPostId;
          card = NodeCard(
            node: node,
            index: i,
            highlight: false,
            focused: isFocused,
            onTap: () => _handleNodeTap(post.id),
            onToggleReaction: null,
            onOpenDetail: () => _openDetailSheet(post.id),
          );
        case MilestoneItem(:final milestone):
          isFocused = false;
          card = MilestoneNodeCard(
            node: node,
            milestone: milestone,
            onTap: () => showMilestoneDetailSheet(context, milestone),
            onToggleReaction: null, // no reactions for unauthenticated
          );
      }

      final positioned = Positioned(
        left: layout.isHorizontal
            ? node.x
            : ConstellationLayout.spineWidth + node.x,
        top: node.y,
        width: node.width,
        child: dimmed
            ? Opacity(opacity: 0.15, child: IgnorePointer(child: card))
            : card,
      );

      if (isFocused) {
        focusedNode = positioned;
      } else {
        nodes.add(positioned);
      }
    }

    if (focusedNode != null) nodes.add(focusedNode);
    return nodes;
  }

  void _handleNodeTap(String postId) {
    if (_focusedPostId == postId) {
      setState(() => _focusedPostId = null);
      _openDetailSheet(postId);
    } else if (_isTopmost(postId)) {
      _openDetailSheet(postId);
    } else {
      setState(() => _focusedPostId = postId);
    }
  }

  void _openDetailSheet(String postId) {
    final posts = ref.read(publicTimelineProvider).posts;
    final post = posts.firstWhereOrNull((p) => p.id == postId);
    if (post == null) return;
    showPostDetailSheet(
      context,
      post,
      onToggleReaction: null,
      onReactionsChanged: null,
      onCreateConnection: null,
      onDeleteConnection: null,
      onConnectionAdded: null,
      onConnectionRemoved: null,
      onViewConstellation: (ids) =>
          ref.read(publicTimelineProvider.notifier).showConstellation(ids),
      onNameConstellation: null,
      allPosts: ref.read(publicTimelineProvider).posts,
    );
  }

  bool _isTopmost(String postId) {
    final layout = ref.read(publicTimelineProvider).layout;
    if (layout == null) return true;

    final nodes = layout.nodes;
    final idx = nodes.indexWhere((n) => n.item.id == postId);
    if (idx < 0) return true;

    final target = nodes[idx];
    final sw = ConstellationLayout.spineWidth;
    final pillH = target.item.totalReactions > 0 ? 20.0 : 0.0;
    final tRect = Rect.fromLTWH(
      sw + target.x,
      target.y,
      target.width,
      target.height + pillH,
    );

    for (int i = idx + 1; i < nodes.length; i++) {
      final other = nodes[i];
      final otherPillH = other.item.totalReactions > 0 ? 20.0 : 0.0;
      final oRect = Rect.fromLTWH(
        sw + other.x,
        other.y,
        other.width,
        other.height + otherPillH,
      );
      if (tRect.overlaps(oRect)) return false;
    }
    return true;
  }

  List<Positioned> _buildDateLabels(
    LayoutResult layout,
    double scrollOffset,
    double viewportSize,
  ) {
    final days = layout.days;
    final horizontal = layout.isHorizontal;
    final midpoint = viewportSize * 0.67;
    final hasScrolled = scrollOffset > 4;
    int? highlightedIndex;
    if (hasScrolled) {
      for (int i = 0; i < days.length; i++) {
        if (days[i].isToday) continue;
        final screenPos = horizontal
            ? days[i].left + 6 - scrollOffset
            : days[i].top + 6 - scrollOffset;
        if (screenPos < midpoint) {
          highlightedIndex = i;
        }
      }
    }

    if (horizontal) {
      return [
        for (int i = 0; i < days.length; i++)
          Positioned(
            left: days[i].left + 6,
            top: 0,
            child: _DateLabel(
              day: days[i],
              isHighlighted: i == highlightedIndex,
              dimToday: highlightedIndex != null,
              showYear: _shouldShowYear(days, i),
              horizontal: true,
            ),
          ),
      ];
    }

    return [
      for (int i = 0; i < days.length; i++)
        Positioned(
          left: 0,
          top: days[i].top + 6,
          child: _DateLabel(
            day: days[i],
            isHighlighted: i == highlightedIndex,
            dimToday: highlightedIndex != null,
            showYear: _shouldShowYear(days, i),
          ),
        ),
    ];
  }

  static bool _shouldShowYear(List<DaySection> days, int index) {
    final year = days[index].date.year;
    if (index + 1 >= days.length) return true;
    return days[index + 1].date.year != year;
  }
}

class _DateLabel extends StatelessWidget {
  final DaySection day;
  final bool isHighlighted;
  final bool dimToday;
  final bool showYear;
  final bool horizontal;

  const _DateLabel({
    required this.day,
    this.isHighlighted = false,
    this.dimToday = false,
    this.showYear = false,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = day.isToday;
    final todayDimmed = isToday && dimToday;

    final Color dayColor;
    final Color monthColor;
    if (isHighlighted) {
      dayColor = colorTextPrimary;
      monthColor = colorTextSecondary;
    } else if (isToday && !todayDimmed) {
      dayColor = colorTextPrimary;
      monthColor = colorTextSecondary;
    } else {
      dayColor = colorInteractiveMuted;
      monthColor = colorInteractiveMuted;
    }

    if (horizontal) {
      return SizedBox(
        height: ConstellationLayout.spineHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isToday)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 4),
                decoration: const BoxDecoration(
                  color: colorError,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              '${_shortMonth(day.date.month)} ${day.date.day}',
              style: TextStyle(
                color: dayColor,
                fontSize: fontSizeSm,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            if (showYear)
              Text(
                " '${(day.date.year % 100).toString().padLeft(2, '0')}",
                style: TextStyle(
                  color: monthColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: ConstellationLayout.spineWidth,
      child: Column(
        children: [
          if (isToday)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: const BoxDecoration(
                color: colorError,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            day.date.day.toString(),
            style: TextStyle(
              color: dayColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            _shortMonth(day.date.month),
            style: TextStyle(
              color: monthColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (showYear)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                "'${(day.date.year % 100).toString().padLeft(2, '0')}",
                style: TextStyle(
                  color: monthColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _shortMonth(int month) => _months[month - 1];

class _TuneInButton extends StatelessWidget {
  final bool isTunedIn;
  final VoidCallback onTap;

  const _TuneInButton({required this.isTunedIn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceXs,
        ),
        decoration: BoxDecoration(
          color: isTunedIn
              ? colorAccentGold.withValues(alpha: 0.15)
              : colorAccentGold,
          borderRadius: BorderRadius.circular(radiusFull),
          border: isTunedIn
              ? Border.all(color: colorAccentGold.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTunedIn ? Icons.check : Icons.headphones,
              size: 14,
              color: isTunedIn ? colorAccentGold : colorSurface0,
            ),
            const SizedBox(width: spaceXs),
            Text(
              isTunedIn ? 'Tuned In' : 'Tune In',
              style: TextStyle(
                color: isTunedIn ? colorAccentGold : colorSurface0,
                fontSize: fontSizeSm,
                fontWeight: weightSemibold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackSelector extends StatelessWidget {
  final List<Track> tracks;
  final Set<String> selectedTrackIds;
  final bool allSelected;
  final ValueChanged<String> onToggleTrack;
  final VoidCallback onToggleAll;

  const _TrackSelector({
    required this.tracks,
    required this.selectedTrackIds,
    required this.allSelected,
    required this.onToggleTrack,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _chip(
              label: 'All',
              selected: allSelected,
              onTap: onToggleAll,
              selectedColor: colorInteractive,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          for (final track in tracks)
            _chip(
              label: track.name,
              selected: selectedTrackIds.contains(track.id),
              onTap: () => onToggleTrack(track.id),
              selectedColor: track.displayColor,
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color selectedColor,
    BorderRadius? borderRadius,
  }) {
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
          style: TextStyle(
            fontSize: 11,
            color: selected ? selectedColor : colorInteractive,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
