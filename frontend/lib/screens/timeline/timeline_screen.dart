import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../models/artist.dart';
import '../../models/post.dart';
import '../../models/timeline_item.dart';
import '../../models/track.dart';
import '../../providers/my_artist_provider.dart';
import '../../providers/pending_artist_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../utils/constellation_layout.dart';
import '../../utils/date_format.dart';
import '../../widgets/timeline/avatar_rail.dart';
import '../../widgets/timeline/constellation_painter.dart';
import '../../widgets/timeline/milestone_detail_sheet.dart';
import '../../widgets/timeline/milestone_node_card.dart';
import '../../widgets/timeline/node_card.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../theme/gleisner_assets.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/timeline/post_detail_sheet.dart';
import '../create_post/create_post_screen.dart';
import '../edit_post/edit_post_screen.dart';
import '../../widgets/tutorial/tutorial_spotlight.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with SingleTickerProviderStateMixin {
  double? _lastWidth;
  double? _lastHeight;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  String? _focusedPostId;
  final _fabLayerLink = LayerLink();
  bool _showFirstPostTutorial = false;

  /// Post shown in the desktop side panel (null = panel closed).
  String? _sidePanelPostId;

  // Synapse dot animation — continuous cycle through all connections
  late final AnimationController _dotController;

  @override
  void dispose() {
    _dotController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsProvider.notifier).trackPageView('/timeline');
    });
    // Synapse travelling dots: one full cycle = every dot visits every
    // visible connection once. 12s feels unhurried with 3 simultaneous dots.
    _dotController = AnimationController(
      duration: const Duration(seconds: 35),
      vsync: this,
    )..repeat();
    Future.microtask(_loadData);
    // Re-load data when auth state changes (e.g. new user after logout)
    ref.listenManual(myArtistProvider, (prev, next) {
      if (prev == null && next != null) {
        _viewingArtistUsername = null;
        _showFirstPostTutorial = false;
        Future.microtask(_loadData);
      }
    });
    // Listen for pending artist (set by Artist Page after Tune In)
    // Using ref.listenManual avoids the multi-fire issue of ref.watch in build()
    ref.listenManual(pendingArtistProvider, (prev, next) {
      if (next != null) {
        ref.read(pendingArtistProvider.notifier).clear();
        ref.read(tuneInProvider.notifier).loadMyTuneIns();
        _switchToArtist(next);
      }
    });
  }

  /// The username whose timeline is currently displayed.
  /// null = own timeline (Artist Mode).
  String? _viewingArtistUsername;

  /// Own artist username, derived from myArtistProvider.
  String? get _ownArtistUsername => ref.read(myArtistProvider)?.artistUsername;

  /// Whether the current view is the user's own timeline (Artist Mode).
  /// Checks both the explicit viewing state AND the actual loaded timeline
  /// data — after artist registration, _viewingArtistUsername may still
  /// point to another artist while timelineProvider has already loaded
  /// the user's own data.
  bool get _isOwnTimeline {
    final own = _ownArtistUsername;
    if (own == null) return _viewingArtistUsername == null;
    return _viewingArtistUsername == null ||
        _viewingArtistUsername == own ||
        ref.read(timelineProvider).artist?.artistUsername == own;
  }

  Future<void> _loadData() async {
    // Load own artist + tune-in list in parallel
    await Future.wait([
      ref.read(myArtistProvider.notifier).load(),
      ref.read(tuneInProvider.notifier).loadMyTuneIns(),
    ]);
    if (!mounted) return;

    final myArtist = ref.read(myArtistProvider);
    final tunedIn = ref.read(tuneInProvider).tunedInArtists;

    if (_viewingArtistUsername != null) {
      // Already viewing someone — just refresh
      return;
    }

    if (myArtist != null) {
      // Artist user — load own timeline
      ref.read(timelineProvider.notifier).loadArtist(myArtist.artistUsername);
    } else if (tunedIn.isNotEmpty) {
      // Fan-only user with tuned-in artists — show the first one
      _switchToArtist(tunedIn.first.artistUsername);
    }
    // else: fan with no tune-ins — empty state (handled by build)
  }

  void _switchToArtist(String artistUsername) {
    if (_ownArtistUsername != null && artistUsername == _ownArtistUsername) {
      // Switch to own timeline (Artist Mode)
      _viewingArtistUsername = null;
      ref.read(timelineProvider.notifier).loadArtist(_ownArtistUsername!);
    } else {
      // Switch to another artist's timeline (Fan Mode)
      _viewingArtistUsername = artistUsername;
      ref.read(timelineProvider.notifier).loadArtist(artistUsername);
    }
    // Clear constellation mode on artist switch
    ref.read(timelineProvider.notifier).clearConstellation();
    setState(() {
      _focusedPostId = null;
      _lastWidth = null; // Force layout recalculation
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(timelineProvider);
    final tuneIn = ref.watch(tuneInProvider);
    // Watch myArtistProvider so FAB and mode badge update when artist registers
    final myArtist = ref.watch(myArtistProvider);
    final selfArtistUsername = myArtist?.artistUsername;

    final theme = Theme.of(context);
    final isOwn = _isOwnTimeline;

    // Show first-post tutorial when: artist mode + no posts + not seen + loaded
    final tutorialState = ref.watch(tutorialProvider);
    if (isOwn &&
        timeline.artist != null &&
        timeline.posts.isEmpty &&
        !timeline.isLoading &&
        tutorialState.isLoaded &&
        !tutorialState.seen.contains(TutorialIds.firstPost) &&
        !_showFirstPostTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showFirstPostTutorial = true);
      });
    }

    // Header: artist name + mode badge
    final headerTitle = timeline.artist != null
        ? (isOwn
              ? 'Your Timeline'
              : timeline.artist!.displayName ?? timeline.artist!.artistUsername)
        : 'Gleisner';
    final modeBadge = timeline.artist != null
        ? (isOwn ? 'ARTIST' : 'TUNED IN')
        : null;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colorSurface0,
          appBar: AppBar(
            backgroundColor: colorSurface0,
            title: Row(
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
                  child: GestureDetector(
                    onTap: isOwn
                        ? () => context.go('/profile')
                        : timeline.artist != null
                        ? () => context.push(
                            '/artist/${timeline.artist!.artistUsername}',
                          )
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            headerTitle,
                            style: const TextStyle(
                              color: colorTextPrimary,
                              fontSize: fontSizeXl,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isOwn && timeline.artist != null)
                          const Padding(
                            padding: EdgeInsets.only(left: spaceXxs),
                            child: Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: colorInteractiveMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (modeBadge != null) ...[
                  const SizedBox(width: spaceSm),
                  if (isOwn)
                    // Artist Mode — static badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: spaceXs,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorAccentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(radiusSm),
                        border: Border.all(
                          color: colorAccentGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        modeBadge,
                        style: const TextStyle(
                          color: colorAccentGold,
                          fontSize: 9,
                          fontWeight: weightSemibold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else
                    // Fan Mode — tappable Tune Out button
                    GestureDetector(
                      onTap: () async {
                        final artistId = timeline.artist?.id;
                        if (artistId == null) return;
                        // 1. Tune out
                        await ref
                            .read(tuneInProvider.notifier)
                            .toggleTuneIn(artistId);
                        if (!mounted) return;
                        // 2. Sync with server
                        await ref.read(tuneInProvider.notifier).loadMyTuneIns();
                        if (!mounted) return;
                        // 3. Decide what to show next
                        final remaining = ref
                            .read(tuneInProvider)
                            .tunedInArtists;
                        if (remaining.isNotEmpty) {
                          // Switch to first remaining artist
                          _switchToArtist(remaining.first.artistUsername);
                        } else if (_ownArtistUsername != null) {
                          // No more tuned-in artists, show own timeline
                          _switchToArtist(_ownArtistUsername!);
                        } else {
                          // Fan-only, no artists left — empty state
                          _viewingArtistUsername = null;
                          ref.read(timelineProvider.notifier).loadMyArtist();
                          setState(() {
                            _focusedPostId = null;
                            _lastWidth = null;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: spaceSm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorAccentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(radiusFull),
                          border: Border.all(
                            color: colorAccentGold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.headphones,
                              size: 10,
                              color: colorAccentGold,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'TUNED IN',
                              style: TextStyle(
                                color: colorAccentGold,
                                fontSize: 9,
                                fontWeight: weightSemibold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(Icons.close, size: 10, color: colorAccentGold),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
            actions: const [],
          ),
          // FAB only in Artist Mode (ADR 008)
          // Use myArtist as primary check — timeline.artist may be stale
          // after initial artist registration (async load not yet complete)
          floatingActionButton: timeline.artist != null && isOwn
              ? CompositedTransformTarget(
                  link: _fabLayerLink,
                  child: _GlowingStarButton(
                    onPressed: () {
                      if (_showFirstPostTutorial) {
                        setState(() => _showFirstPostTutorial = false);
                        ref
                            .read(tutorialProvider.notifier)
                            .markSeen(TutorialIds.firstPost);
                      }
                      final screenWidth = MediaQuery.of(context).size.width;
                      if (isDesktop(screenWidth)) {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => Dialog(
                            backgroundColor: colorSurface0,
                            insetPadding: const EdgeInsets.symmetric(
                              horizontal: 80,
                              vertical: 40,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(radiusLg),
                                ),
                                child: CreatePostScreen(
                                  onSuccess: () {
                                    Navigator.of(dialogContext).pop();
                                    ref
                                        .read(timelineProvider.notifier)
                                        .refresh();
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        context.go('/create-post');
                      }
                    },
                  ),
                )
              : null,
          body: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    if (timeline.artist != null &&
                        timeline.artist!.tracks.isNotEmpty)
                      _TrackSelector(
                        tracks: timeline.artist!.tracks,
                        selectedTrackIds: timeline.selectedTrackIds,
                        allSelected: timeline.allSelected,
                        onToggleTrack: (trackId) => ref
                            .read(timelineProvider.notifier)
                            .toggleTrack(trackId),
                        onToggleAll: () =>
                            ref.read(timelineProvider.notifier).toggleAll(),
                      ),
                    // Avatar rail — always visible (not inside scroll)
                    if (tuneIn.tunedInArtists.isNotEmpty ||
                        selfArtistUsername != null)
                      AvatarRail(
                        artists: tuneIn.tunedInArtists,
                        selfArtistUsername: selfArtistUsername,
                        selfAvatarUrl: myArtist?.avatarUrl,
                        selfIsPrivate: myArtist?.isPrivate ?? false,
                        selectedArtistUsername:
                            _viewingArtistUsername ??
                            (timeline.artist?.artistUsername),
                        onSelectArtist: _switchToArtist,
                        onSelectSelf: () {
                          if (_ownArtistUsername != null) {
                            _switchToArtist(_ownArtistUsername!);
                          }
                        },
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
                          : timeline.posts.isEmpty && !isOwn
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.headphones,
                                    size: 40,
                                    color: colorInteractiveMuted,
                                  ),
                                  const SizedBox(height: spaceMd),
                                  Text(
                                    'No posts from this artist yet',
                                    style: TextStyle(
                                      color: colorInteractive,
                                      fontSize:
                                          theme.textTheme.bodyLarge?.fontSize,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : timeline.posts.isEmpty
                          ? Center(
                              child: Text(
                                timeline.artist == null
                                    ? 'Discover artists and tune in to fill your timeline'
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
                                  final height = constraints.maxHeight;
                                  final screenWidth = MediaQuery.of(
                                    context,
                                  ).size.width;
                                  final useHorizontal = isDesktop(screenWidth);
                                  if (_lastWidth != width ||
                                      _lastHeight != height) {
                                    _lastWidth = width;
                                    _lastHeight = height;
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          ref
                                              .read(timelineProvider.notifier)
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

                                  return NotificationListener<
                                    ScrollNotification
                                  >(
                                    onNotification: (n) {
                                      setState(
                                        () => _scrollOffset = n.metrics.pixels,
                                      );
                                      return false;
                                    },
                                    child: SingleChildScrollView(
                                      scrollDirection: layout.isHorizontal
                                          ? Axis.horizontal
                                          : Axis.vertical,
                                      controller: _scrollController,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      child: Column(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              if (_sidePanelPostId != null) {
                                                setState(
                                                  () => _sidePanelPostId = null,
                                                );
                                              } else if (timeline
                                                      .constellationPostIds !=
                                                  null) {
                                                ref
                                                    .read(
                                                      timelineProvider.notifier,
                                                    )
                                                    .clearConstellation();
                                              } else if (_focusedPostId !=
                                                  null) {
                                                setState(
                                                  () => _focusedPostId = null,
                                                );
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
                                                  // Background: spine + synapses + travelling dot
                                                  Positioned.fill(
                                                    child: AnimatedBuilder(
                                                      animation: _dotController,
                                                      builder: (context, _) => CustomPaint(
                                                        painter: ConstellationPainter(
                                                          layout: layout,
                                                          constellationPostIds:
                                                              timeline
                                                                  .constellationPostIds,
                                                          animationValue:
                                                              _dotController
                                                                  .value,
                                                          scrollOffset:
                                                              _scrollOffset,
                                                          viewportHeight:
                                                              constraints
                                                                  .maxHeight,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  // Day labels on the spine
                                                  ..._buildDateLabels(
                                                    layout,
                                                    _scrollOffset,
                                                    layout.isHorizontal
                                                        ? constraints.maxWidth
                                                        : constraints.maxHeight,
                                                  ),
                                                  // Nodes (focused node rendered last for z-order)
                                                  ..._buildNodes(
                                                    layout,
                                                    timeline.highlightPostId,
                                                    timeline
                                                        .constellationPostIds,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
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
                                    timeline.constellationPostIds!.contains(
                                      p.id,
                                    ) &&
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
                                      fontSize: fontSizeSm,
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
              ),
              // Desktop side panel for post detail
              if (_sidePanelPostId != null) ...[
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: colorBorder,
                ),
                SizedBox(
                  width: sidePanelWidth,
                  child: _DesktopDetailPanel(
                    postId: _sidePanelPostId!,
                    posts: timeline.posts,
                    isOwn: isOwn,
                    onClose: () => setState(() => _sidePanelPostId = null),
                    onToggleReaction: (id, emoji) => ref
                        .read(timelineProvider.notifier)
                        .toggleReaction(id, emoji),
                    onReactionsChanged: (id, counts, myReactions) => ref
                        .read(timelineProvider.notifier)
                        .updatePostReactions(id, counts, myReactions),
                    onEdit: isOwn
                        ? (post) {
                            setState(() => _sidePanelPostId = null);
                            _openEditPost(post);
                          }
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Tutorial overlay
        if (_showFirstPostTutorial)
          Positioned.fill(
            child: TutorialSpotlight(
              visible: true,
              link: _fabLayerLink,
              message: 'Add your first star to the constellation',
              subtitle:
                  'Every post becomes a point of light in your creative universe.',
              onDismiss: () {
                setState(() => _showFirstPostTutorial = false);
                ref
                    .read(tutorialProvider.notifier)
                    .markSeen(TutorialIds.firstPost);
              },
            ),
          ),
      ],
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
            highlight: post.id == highlightPostId,
            focused: isFocused,
            onTap: () => _handleNodeTap(post.id),
            onToggleReaction: (postId, emoji) => ref
                .read(timelineProvider.notifier)
                .toggleReaction(postId, emoji),
            onOpenDetail: () => _openDetailSheet(post.id),
          );
        case MilestoneItem(:final milestone):
          isFocused = false;
          card = MilestoneNodeCard(
            node: node,
            milestone: milestone,
            onTap: () => _openMilestoneDetailSheet(milestone),
            onToggleReaction: (id, emoji) => ref
                .read(timelineProvider.notifier)
                .toggleMilestoneReaction(id, emoji),
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
    // Desktop: show side panel instead of bottom sheet
    final screenWidth = MediaQuery.of(context).size.width;
    if (isDesktop(screenWidth)) {
      setState(() => _sidePanelPostId = postId);
      return;
    }

    _showDetailBottomSheet(postId);
  }

  /// Open edit post — dialog on desktop, push navigation on mobile.
  void _openEditPost(Post post) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isDesktop(screenWidth)) {
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: colorSurface0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 80,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(radiusLg)),
              child: EditPostScreen(
                post: post,
                onSaved: (_) {
                  Navigator.of(dialogContext).pop();
                  ref.read(timelineProvider.notifier).refresh();
                },
              ),
            ),
          ),
        ),
      );
    } else {
      context.push('/edit-post', extra: post);
    }
  }

  void _showDetailBottomSheet(String postId) {
    final post = ref
        .read(timelineProvider)
        .posts
        .firstWhere((p) => p.id == postId);
    final notifier = ref.read(timelineProvider.notifier);
    final isOwn = _isOwnTimeline;
    showPostDetailSheet(
      context,
      post,
      // Reactions are always available (engagement, not editing)
      onToggleReaction: (id, emoji) => notifier.toggleReaction(id, emoji),
      onReactionsChanged: (id, counts, myReactions) {
        notifier.updatePostReactions(id, counts, myReactions);
      },
      onCreateConnection: isOwn
          ? (sourceId, targetId, type) => notifier.createConnection(
              sourceId,
              targetId,
              connectionType: type,
            )
          : null,
      onDeleteConnection: isOwn
          ? (connectionId) => notifier.deleteConnection(connectionId)
          : null,
      onConnectionAdded: isOwn
          ? (conn) => notifier.addConnectionToState(conn)
          : null,
      onConnectionRemoved: isOwn
          ? (conn) => notifier.removeConnectionFromState(conn)
          : null,
      onViewConstellation: (ids) => notifier.showConstellation(ids),
      onNameConstellation: isOwn
          ? (postId, name) => notifier.nameConstellation(postId, name)
          : null,
      onEdit: isOwn
          ? () {
              Navigator.pop(context); // Close detail sheet
              _openEditPost(post);
            }
          : null,
      allPosts: ref.read(timelineProvider).posts,
    );
  }

  void _openMilestoneDetailSheet(ArtistMilestone milestone) {
    showMilestoneDetailSheet(
      context,
      milestone,
      onToggleReaction: (id, emoji) => ref
          .read(timelineProvider.notifier)
          .toggleMilestoneReaction(id, emoji),
    );
  }

  /// Check if a node is not occluded by any node rendered after it.
  bool _isTopmost(String postId) {
    final layout = ref.read(timelineProvider).layout;
    if (layout == null) return true;

    final nodes = layout.nodes;
    final idx = nodes.indexWhere((n) => n.item.id == postId);
    if (idx < 0) return true;

    final target = nodes[idx];
    final sw = ConstellationLayout.spineWidth;
    // Include reaction pills height (~20px) in the hit area
    final pillH = target.item.totalReactions > 0 ? 20.0 : 0.0;
    final tRect = Rect.fromLTWH(
      sw + target.x,
      target.y,
      target.width,
      target.height + pillH,
    );

    // Check nodes rendered after this one (higher z-order in default order)
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

  /// Show year on the oldest (bottommost) label of each year group.
  /// Timeline is top=newest, bottom=oldest, so "oldest" = last before
  /// the next label switches to a different year, or the very last label.
  static bool _shouldShowYear(List<DaySection> days, int index) {
    final year = days[index].date.year;
    // Last label in the list → always show year
    if (index + 1 >= days.length) return true;
    // Next label is a different year → this is the oldest of its group
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
              fontSize: fontSizeSm,
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

/// Desktop-only side panel showing post detail inline.
class _DesktopDetailPanel extends StatelessWidget {
  final String postId;
  final List<Post> posts;
  final bool isOwn;
  final VoidCallback onClose;
  final Future<bool> Function(String, String) onToggleReaction;
  final void Function(String, List<ReactionCount>, List<String>)
  onReactionsChanged;
  final void Function(Post)? onEdit;

  const _DesktopDetailPanel({
    required this.postId,
    required this.posts,
    required this.isOwn,
    required this.onClose,
    required this.onToggleReaction,
    required this.onReactionsChanged,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final post = posts.where((p) => p.id == postId).firstOrNull;
    if (post == null) return const SizedBox.shrink();

    return Container(
      color: colorSurface1,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: spaceLg,
              vertical: spaceSm,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: colorBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    post.title ?? 'Untitled',
                    style: const TextStyle(
                      color: colorTextPrimary,
                      fontSize: fontSizeLg,
                      fontWeight: weightSemibold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: colorInteractive,
                    ),
                    onPressed: () => onEdit!(post),
                    tooltip: 'Edit',
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: colorInteractive,
                  ),
                  onPressed: onClose,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image: show directly
                  if (post.mediaUrl != null &&
                      post.mediaType == MediaType.image)
                    Padding(
                      padding: const EdgeInsets.only(bottom: spaceLg),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radiusMd),
                        child: Image.network(
                          post.mediaUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          errorBuilder: (_, _, _) => Container(
                            height: 120,
                            color: colorSurface2,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: colorInteractiveMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Video: show thumbnail if available, else placeholder
                  if (post.mediaType == MediaType.video)
                    Padding(
                      padding: const EdgeInsets.only(bottom: spaceLg),
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: colorSurface2,
                          borderRadius: BorderRadius.circular(radiusMd),
                          image: post.thumbnailUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(post.thumbnailUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_outline,
                                size: 40,
                                color: colorTextPrimary,
                              ),
                              if (post.duration != null)
                                Text(
                                  '${post.duration! ~/ 60}:${(post.duration! % 60).toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: colorTextSecondary,
                                    fontSize: fontSizeSm,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Audio: show placeholder with duration
                  if (post.mediaType == MediaType.audio)
                    Padding(
                      padding: const EdgeInsets.only(bottom: spaceLg),
                      child: Container(
                        padding: const EdgeInsets.all(spaceLg),
                        decoration: BoxDecoration(
                          color: colorSurface2,
                          borderRadius: BorderRadius.circular(radiusMd),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.audiotrack,
                              size: 24,
                              color: colorInteractive,
                            ),
                            const SizedBox(width: spaceMd),
                            Text(
                              post.duration != null
                                  ? '${post.duration! ~/ 60}:${(post.duration! % 60).toString().padLeft(2, '0')}'
                                  : 'Audio',
                              style: const TextStyle(
                                color: colorTextSecondary,
                                fontSize: fontSizeMd,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (post.body != null && post.body!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: spaceLg),
                      child: Text(
                        post.body!,
                        style: const TextStyle(
                          color: colorTextSecondary,
                          fontSize: fontSizeMd,
                          height: 1.6,
                        ),
                      ),
                    ),
                  Text(
                    '${post.mediaType.name} · ${formatDate(post.createdAt)}',
                    style: const TextStyle(
                      color: colorTextMuted,
                      fontSize: fontSizeSm,
                    ),
                  ),
                  if (post.reactionCounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: spaceLg),
                      child: Wrap(
                        spacing: spaceSm,
                        runSpacing: spaceXs,
                        children: post.reactionCounts.map((rc) {
                          final isMine = post.myReactions.contains(rc.emoji);
                          return ActionChip(
                            label: Text(
                              '${rc.emoji} ${rc.count}',
                              style: TextStyle(
                                fontSize: fontSizeSm,
                                color: isMine
                                    ? colorAccentGold
                                    : colorTextSecondary,
                              ),
                            ),
                            backgroundColor: isMine
                                ? colorSurface2
                                : colorSurface0,
                            side: BorderSide(
                              color: isMine ? colorAccentGold : colorBorder,
                            ),
                            onPressed: () =>
                                onToggleReaction(post.id, rc.emoji),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
