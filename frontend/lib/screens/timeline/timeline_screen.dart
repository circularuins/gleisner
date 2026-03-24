import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/track.dart';
import '../../providers/auth_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../utils/constellation_layout.dart';
import '../../widgets/timeline/constellation_painter.dart';
import '../../widgets/timeline/node_card.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/timeline/post_detail_sheet.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  double? _lastWidth;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  String? _focusedPostId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  void _loadData() {
    final timeline = ref.read(timelineProvider);
    if (timeline.artist != null) {
      // Already loaded — just refresh posts
      ref.read(timelineProvider.notifier).refresh();
    } else {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(timelineProvider.notifier).loadArtist(user.username);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(timelineProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: const Text(
          'Gleisner',
          style: TextStyle(color: colorTextPrimary),
        ),
        actions: const [],
      ),
      floatingActionButton: timeline.artist != null
          ? _GlowingStarButton(onPressed: () => context.go('/create-post'))
          : null,
      body: Column(
        children: [
          if (timeline.artist != null && timeline.artist!.tracks.isNotEmpty)
            _TrackSelector(
              tracks: timeline.artist!.tracks,
              selectedTrackIds: timeline.selectedTrackIds,
              allSelected: timeline.allSelected,
              onToggleTrack: (trackId) =>
                  ref.read(timelineProvider.notifier).toggleTrack(trackId),
              onToggleAll: () =>
                  ref.read(timelineProvider.notifier).toggleAll(),
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
                    child: Text(
                      timeline.artist == null
                          ? 'Register as an artist to get started'
                          : 'No posts yet',
                      style: TextStyle(
                        color: colorInteractive,
                        fontSize: theme.textTheme.bodyLarge?.fontSize,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(timelineProvider.notifier).refresh(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        if (_lastWidth != width) {
                          _lastWidth = width;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ref
                                .read(timelineProvider.notifier)
                                .computeLayout(width);
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
                            setState(() => _scrollOffset = n.metrics.pixels);
                            return false;
                          },
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: GestureDetector(
                              onTap: () {
                                if (timeline.constellationPostIds != null) {
                                  ref
                                      .read(timelineProvider.notifier)
                                      .clearConstellation();
                                } else if (_focusedPostId != null) {
                                  setState(() => _focusedPostId = null);
                                }
                              },
                              child: SizedBox(
                                height: layout.totalHeight,
                                child: Stack(
                                  children: [
                                    // Background: spine + synapses
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: ConstellationPainter(
                                          layout: layout,
                                          constellationPostIds:
                                              timeline.constellationPostIds,
                                        ),
                                      ),
                                    ),
                                    // Day labels on the spine
                                    // Find the one day closest above the midpoint
                                    ..._buildDateLabels(
                                      layout.days,
                                      _scrollOffset,
                                      constraints.maxHeight,
                                    ),
                                    // Nodes (focused node rendered last for z-order)
                                    ..._buildNodes(
                                      layout,
                                      timeline.highlightPostId,
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
            Builder(
              builder: (context) {
                final constellationName = timeline.posts
                    .where(
                      (p) =>
                          timeline.constellationPostIds!.contains(p.id) &&
                          p.constellation != null,
                    )
                    .map((p) => p.constellation!.name)
                    .firstOrNull;
                return Container(
                  color: colorSurface1,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                          constellationName != null
                              ? '$constellationName · ${timeline.constellationPostIds!.length} posts'
                              : 'Constellation · ${timeline.constellationPostIds!.length} posts',
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
                            .read(timelineProvider.notifier)
                            .clearConstellation(),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: colorInteractive,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Positioned> _buildNodes(
    LayoutResult layout,
    String? highlightPostId,
    Set<String>? constellationIds,
  ) {
    final nodes = <Positioned>[];
    Positioned? focusedNode;

    for (int i = 0; i < layout.nodes.length; i++) {
      final node = layout.nodes[i];
      final isFocused = node.post.id == _focusedPostId;
      final dimmed =
          constellationIds != null && !constellationIds.contains(node.post.id);

      final card = NodeCard(
        node: node,
        index: i,
        highlight: node.post.id == highlightPostId,
        focused: isFocused,
        onTap: () => _handleNodeTap(node.post.id),
        onToggleReaction: (postId, emoji) =>
            ref.read(timelineProvider.notifier).toggleReaction(postId, emoji),
        onOpenDetail: () => _openDetailSheet(node.post.id),
      );

      final positioned = Positioned(
        left: ConstellationLayout.spineWidth + node.x,
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

    // Focused node rendered last = highest z-order
    if (focusedNode != null) nodes.add(focusedNode);

    return nodes;
  }

  void _handleNodeTap(String postId) {
    if (_focusedPostId == postId) {
      // Already focused → open detail sheet
      setState(() => _focusedPostId = null);
      _openDetailSheet(postId);
    } else if (_isTopmost(postId)) {
      // Already on top (no overlap) → open detail directly
      _openDetailSheet(postId);
    } else {
      // Occluded → bring to front
      setState(() => _focusedPostId = postId);
    }
  }

  void _openDetailSheet(String postId) {
    final post = ref
        .read(timelineProvider)
        .posts
        .firstWhere((p) => p.id == postId);
    final notifier = ref.read(timelineProvider.notifier);
    showPostDetailSheet(
      context,
      post,
      onToggleReaction: (id, emoji) => notifier.toggleReaction(id, emoji),
      onReactionsChanged: (id, counts, myReactions) {
        notifier.updatePostReactions(id, counts, myReactions);
      },
      onCreateConnection: (sourceId, targetId) =>
          notifier.createConnection(sourceId, targetId),
      onDeleteConnection: (connectionId) =>
          notifier.deleteConnection(connectionId),
      onConnectionAdded: (conn) => notifier.addConnectionToState(conn),
      onConnectionRemoved: (conn) => notifier.removeConnectionFromState(conn),
      onViewConstellation: (ids) => notifier.showConstellation(ids),
      onNameConstellation: (postId, name) =>
          notifier.nameConstellation(postId, name),
      allPosts: ref.read(timelineProvider).posts,
    );
  }

  /// Check if a node is not occluded by any node rendered after it.
  bool _isTopmost(String postId) {
    final layout = ref.read(timelineProvider).layout;
    if (layout == null) return true;

    final nodes = layout.nodes;
    final idx = nodes.indexWhere((n) => n.post.id == postId);
    if (idx < 0) return true;

    final target = nodes[idx];
    final sw = ConstellationLayout.spineWidth;
    // Include reaction pills height (~20px) in the hit area
    final pillH = target.post.reactionCounts.isNotEmpty ? 20.0 : 0.0;
    final tRect = Rect.fromLTWH(
      sw + target.x,
      target.y,
      target.width,
      target.height + pillH,
    );

    // Check nodes rendered after this one (higher z-order in default order)
    for (int i = idx + 1; i < nodes.length; i++) {
      final other = nodes[i];
      final otherPillH = other.post.reactionCounts.isNotEmpty ? 20.0 : 0.0;
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
    List<DaySection> days,
    double scrollOffset,
    double viewportHeight,
  ) {
    // Determine which single day to highlight.
    // - If not scrolled (or scrolled back to top), only "today" highlights
    //   (via its own isToday styling) — no other day gets isHighlighted.
    // - Once scrolled, the last non-today day above the midpoint highlights,
    //   and today loses its special brightness (handled by isHighlighted being
    //   assigned to a different index).
    final midpoint = viewportHeight * 0.67;
    final hasScrolled = scrollOffset > 4;
    int? highlightedIndex;
    if (hasScrolled) {
      for (int i = 0; i < days.length; i++) {
        if (days[i].isToday) continue;
        final screenY = days[i].top + 6 - scrollOffset;
        if (screenY < midpoint) {
          highlightedIndex = i;
        }
      }
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
          ),
        ),
    ];
  }
}

class _DateLabel extends StatelessWidget {
  final DaySection day;
  final bool isHighlighted;
  final bool dimToday;

  const _DateLabel({
    required this.day,
    this.isHighlighted = false,
    this.dimToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = day.isToday;
    // Today dims when another day is highlighted (scrolled)
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

/// A glowing star button that replaces the generic Material FAB.
/// Uses warm gold accent (distinct from track colors) with a breathing
/// pulse animation. The auto_awesome + badge connects to the
/// constellation metaphor of "adding a new star."
class _GlowingStarButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _GlowingStarButton({required this.onPressed});

  @override
  State<_GlowingStarButton> createState() => _GlowingStarButtonState();
}

class _GlowingStarButtonState extends State<_GlowingStarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const glowColor = colorAccentGold;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final v = _pulse.value;
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.25 + v * 0.15),
                blurRadius: 12 + v * 8,
                spreadRadius: 2 + v * 3,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [glowColor.withValues(alpha: 0.3), colorSurface1],
                stops: const [0.0, 0.85],
              ),
              border: Border.all(
                color: glowColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.auto_awesome, color: glowColor, size: 24),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: colorSurface1,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: glowColor.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 10,
                      color: colorAccentGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
