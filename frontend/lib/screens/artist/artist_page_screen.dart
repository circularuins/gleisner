import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../utils/open_url.dart';

import '../../models/artist.dart';
import '../../models/post.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/artist_page_provider.dart';
import '../../providers/discover_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/edit_artist_provider.dart';
import '../../providers/my_artist_provider.dart';
import '../../providers/pending_artist_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../providers/media_upload_provider.dart';
import '../../widgets/media/avatar_image.dart';
import '../../widgets/media/cover_image.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../widgets/timeline/post_detail_sheet.dart';
import '../unassigned_posts/unassigned_posts_screen.dart';
import 'edit_artist_about_sheet.dart';
import 'edit_artist_genres_sheet.dart';
import 'edit_artist_links_sheet.dart';
import 'edit_milestones_sheet.dart';
import '../../utils/milestone_category.dart';
import 'edit_artist_tracks_sheet.dart';

/// Artist Page (ADR 013).
/// Discover → Tap artist card → This screen → [Tune In] → Timeline tab.
class ArtistPageScreen extends ConsumerStatefulWidget {
  final String username;

  const ArtistPageScreen({super.key, required this.username});

  @override
  ConsumerState<ArtistPageScreen> createState() => _ArtistPageScreenState();
}

class _ArtistPageScreenState extends ConsumerState<ArtistPageScreen> {
  /// Post shown in the desktop side panel (null = panel closed).
  String? _sidePanelPostId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsProvider.notifier).trackPageView('/artist/:username');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(artistPageProvider.notifier).loadArtist(widget.username);
      // Only load unassigned posts when viewing own artist page
      final myArtist = ref.read(myArtistProvider);
      if (myArtist != null && myArtist.artistUsername == widget.username) {
        ref.read(unassignedPostsProvider.notifier).load();
      }
    });
  }

  void _openPostDetail(Post post) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isDesktop(screenWidth)) {
      setState(() => _sidePanelPostId = post.id);
      return;
    }
    showPostDetailSheet(context, post);
  }

  Widget _buildSidePanel(ArtistPageState state) {
    final post = state.recentPosts
        .where((p) => p.id == _sidePanelPostId)
        .firstOrNull;
    if (post == null) return const SizedBox.shrink();

    return Container(
      color: colorSurface1,
      child: Column(
        children: [
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
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: colorInteractive,
                  ),
                  onPressed: () => setState(() => _sidePanelPostId = null),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Expanded(
            child: PostDetailContent(
              post: post,
              allPosts: state.recentPosts,
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(artistPageProvider);
    final tuneIn = ref.watch(tuneInProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;
    final artist = state.artist;
    final isTunedIn = artist != null && tuneIn.isTunedIn(artist.id);
    final myArtist = ref.watch(myArtistProvider);
    final isSelf =
        artist != null && myArtist != null && artist.id == myArtist.id;
    final unassignedCount = isSelf
        ? ref.watch(unassignedPostsProvider).posts.length
        : 0;

    return Scaffold(
      backgroundColor: colorSurface0,
      body: state.isLoading && artist == null
          ? const Center(
              child: CircularProgressIndicator(color: colorAccentGold),
            )
          : state.error != null && artist == null
          ? _ErrorView(
              error: state.error!,
              onRetry: () => ref
                  .read(artistPageProvider.notifier)
                  .loadArtist(widget.username),
            )
          : artist == null
          ? _ErrorView(error: 'Artist not found', onRetry: null)
          : Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _sidePanelPostId != null
                        ? () => setState(() => _sidePanelPostId = null)
                        : null,
                    behavior: HitTestBehavior.translucent,
                    child: CustomScrollView(
                      slivers: [
                        // Cover image
                        SliverAppBar(
                          expandedHeight: 200,
                          pinned: true,
                          backgroundColor: colorSurface0,
                          leading: IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: colorTextPrimary,
                            ),
                            onPressed: () => context.pop(),
                          ),
                          flexibleSpace: FlexibleSpaceBar(
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                CoverImage(
                                  imageUrl: artist.coverImageUrl,
                                  seed: artist.artistUsername,
                                  onTap: isSelf
                                      ? () => _uploadCoverImage(context)
                                      : null,
                                ),
                                // Gradient fade at bottom (IgnorePointer so taps pass through to CoverImage)
                                const Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 60,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0x00000000),
                                            colorSurface0,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: maxContentWidth,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: spaceXl,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: spaceLg),
                                    // Avatar
                                    AvatarImage(
                                      imageUrl: artist.avatarUrl,
                                      seed: artist.artistUsername,
                                      size: 72,
                                      onTap: isSelf
                                          ? () => _uploadAvatarImage(context)
                                          : null,
                                    ),
                                    const SizedBox(height: spaceMd),

                                    // Header: name + username + tuned in count
                                    Row(
                                      children: [
                                        Flexible(
                                          child: GestureDetector(
                                            onTap: isSelf
                                                ? () => _showEditDisplayName(
                                                    context,
                                                    artist,
                                                  )
                                                : null,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    artist.displayName ??
                                                        artist.artistUsername,
                                                    style: const TextStyle(
                                                      color: colorTextPrimary,
                                                      fontSize: fontSizeTitle,
                                                      fontWeight: weightBold,
                                                    ),
                                                  ),
                                                ),
                                                if (isSelf) ...[
                                                  const SizedBox(
                                                    width: spaceXs,
                                                  ),
                                                  const Icon(
                                                    Icons.edit_outlined,
                                                    size: 14,
                                                    color: colorTextMuted,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (artist.profileVisibility ==
                                            'private') ...[
                                          const SizedBox(width: spaceSm),
                                          const Icon(
                                            Icons.lock_outline,
                                            size: 18,
                                            color: colorTextMuted,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: spaceXxs),
                                    Row(
                                      children: [
                                        Text(
                                          '@${artist.artistUsername}',
                                          style: const TextStyle(
                                            color: colorTextMuted,
                                            fontSize: fontSizeMd,
                                          ),
                                        ),
                                        const SizedBox(width: spaceMd),
                                        const Icon(
                                          Icons.headphones,
                                          size: 13,
                                          color: colorTextMuted,
                                        ),
                                        const SizedBox(width: spaceXxs),
                                        Text(
                                          '${artist.tunedInCount}',
                                          style: const TextStyle(
                                            color: colorTextMuted,
                                            fontSize: fontSizeSm,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: spaceLg),

                                    // Tune In button (not shown on own page)
                                    if (isAuthenticated && !isSelf)
                                      _TuneInButton(
                                        isTunedIn: isTunedIn,
                                        onTap: () async {
                                          final tunedIn = await ref
                                              .read(tuneInProvider.notifier)
                                              .toggleTuneIn(artist.id);
                                          if (!context.mounted) return;
                                          if (tunedIn) {
                                            ref
                                                .read(
                                                  pendingArtistProvider
                                                      .notifier,
                                                )
                                                .set(artist.artistUsername);
                                            context.go('/timeline');
                                          }
                                        },
                                      ),

                                    // Genres
                                    if (artist.genres.isNotEmpty || isSelf) ...[
                                      const SizedBox(height: spaceXl),
                                      if (isSelf)
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'GENRES',
                                                style: TextStyle(
                                                  color: colorTextMuted,
                                                  fontSize: fontSizeXs,
                                                  fontWeight: weightSemibold,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: colorTextMuted,
                                              ),
                                              onPressed: () =>
                                                  _showEditGenresSheet(
                                                    context,
                                                    artist,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      if (artist.genres.isNotEmpty)
                                        Wrap(
                                          spacing: spaceSm,
                                          runSpacing: spaceSm,
                                          children: artist.genres.map((ag) {
                                            return _Chip(
                                              label: ag.genre.name,
                                              color: colorTextSecondary,
                                              bgColor: colorSurface2,
                                              borderColor: colorBorder,
                                            );
                                          }).toList(),
                                        ),
                                    ],

                                    // About section
                                    if (isSelf ||
                                        artist.location != null ||
                                        artist.activeSince != null ||
                                        artist.tagline != null ||
                                        artist.bio != null) ...[
                                      const SizedBox(height: spaceXl),
                                      if (isSelf)
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'ABOUT',
                                                style: TextStyle(
                                                  color: colorTextMuted,
                                                  fontSize: fontSizeXs,
                                                  fontWeight: weightSemibold,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: colorTextMuted,
                                              ),
                                              onPressed: () =>
                                                  _showEditAboutSheet(
                                                    context,
                                                    artist,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      // Location + Active since
                                      if (artist.location != null ||
                                          artist.activeSince != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: spaceSm,
                                          ),
                                          child: Row(
                                            children: [
                                              if (artist.location != null) ...[
                                                const Icon(
                                                  Icons.place_outlined,
                                                  size: 14,
                                                  color: colorTextMuted,
                                                ),
                                                const SizedBox(width: spaceXxs),
                                                Text(
                                                  artist.location!,
                                                  style: const TextStyle(
                                                    color: colorTextMuted,
                                                    fontSize: fontSizeSm,
                                                  ),
                                                ),
                                              ],
                                              if (artist.location != null &&
                                                  artist.activeSince != null)
                                                const Text(
                                                  ' · ',
                                                  style: TextStyle(
                                                    color: colorTextMuted,
                                                  ),
                                                ),
                                              if (artist.activeSince != null)
                                                Text(
                                                  'Active since ${artist.activeSince}',
                                                  style: const TextStyle(
                                                    color: colorTextMuted,
                                                    fontSize: fontSizeSm,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      // Tagline
                                      if (artist.tagline != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: spaceSm,
                                          ),
                                          child: Text(
                                            artist.tagline!,
                                            style: const TextStyle(
                                              color: colorTextSecondary,
                                              fontSize: fontSizeMd,
                                              fontStyle: FontStyle.italic,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      // Bio
                                      if (artist.bio != null)
                                        Text(
                                          artist.bio!,
                                          style: const TextStyle(
                                            color: colorTextSecondary,
                                            fontSize: fontSizeMd,
                                            height: 1.6,
                                          ),
                                        ),
                                    ],

                                    // Links section
                                    if (artist.links.isNotEmpty || isSelf) ...[
                                      const SizedBox(height: spaceXl),
                                      if (isSelf)
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'LINKS',
                                                style: TextStyle(
                                                  color: colorTextMuted,
                                                  fontSize: fontSizeXs,
                                                  fontWeight: weightSemibold,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: colorTextMuted,
                                              ),
                                              onPressed: () =>
                                                  _showEditLinksSheet(
                                                    context,
                                                    artist,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      if (artist.links.isNotEmpty)
                                        _LinksSection(links: artist.links),
                                    ],

                                    // Career milestones section
                                    if (artist.milestones.isNotEmpty ||
                                        isSelf) ...[
                                      const SizedBox(height: spaceXl),
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'CAREER',
                                              style: TextStyle(
                                                color: colorTextMuted,
                                                fontSize: fontSizeXs,
                                                fontWeight: weightSemibold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                          if (isSelf)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: colorInteractive,
                                              ),
                                              onPressed: () =>
                                                  _showEditMilestonesSheet(
                                                    context,
                                                    artist,
                                                  ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                        ],
                                      ),
                                      if (artist.milestones.isNotEmpty)
                                        _MilestonesSection(
                                          milestones: artist.milestones,
                                        ),
                                    ],

                                    // Tracks section
                                    if (artist.tracks.isNotEmpty || isSelf) ...[
                                      const SizedBox(height: spaceXl),
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'TRACKS',
                                              style: TextStyle(
                                                color: colorTextMuted,
                                                fontSize: fontSizeXs,
                                                fontWeight: weightSemibold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                          if (isSelf)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 18,
                                                color: colorTextMuted,
                                              ),
                                              onPressed: () =>
                                                  _showEditTracksSheet(
                                                    context,
                                                    artist,
                                                  ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: spaceXxs),
                                      const Text(
                                        "This artist's content streams",
                                        style: TextStyle(
                                          color: colorTextMuted,
                                          fontSize: fontSizeXs,
                                        ),
                                      ),
                                      const SizedBox(height: spaceMd),
                                      Wrap(
                                        spacing: spaceSm,
                                        runSpacing: spaceSm,
                                        children: artist.tracks.map((track) {
                                          return _Chip(
                                            label: track.name,
                                            color: track.displayColor,
                                            bgColor: track.displayColor
                                                .withValues(alpha: 0.1),
                                            borderColor: track.displayColor
                                                .withValues(alpha: 0.3),
                                            dot: true,
                                          );
                                        }).toList(),
                                      ),
                                    ],

                                    // Recent Posts section
                                    if (state.recentPosts.isNotEmpty) ...[
                                      const SizedBox(height: spaceXl),
                                      const Text(
                                        'RECENT POSTS',
                                        style: TextStyle(
                                          color: colorTextMuted,
                                          fontSize: fontSizeXs,
                                          fontWeight: weightSemibold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: spaceMd),
                                      const SizedBox(height: spaceSm),
                                      Wrap(
                                        spacing: spaceSm,
                                        runSpacing: spaceSm,
                                        children: state.recentPosts
                                            .map(
                                              (p) => SizedBox(
                                                width:
                                                    (MediaQuery.of(
                                                          context,
                                                        ).size.width -
                                                        spaceXl * 2 -
                                                        spaceSm) /
                                                    2,
                                                child: _RecentPostCard(
                                                  post: p,
                                                  onTap: () =>
                                                      _openPostDetail(p),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],

                                    // Unassigned posts link (own view only)
                                    if (isSelf && unassignedCount > 0) ...[
                                      const SizedBox(height: spaceLg),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(
                                          radiusMd,
                                        ),
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                UnassignedPostsScreen(
                                                  tracks: artist.tracks,
                                                ),
                                          ),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: spaceMd,
                                            vertical: spaceSm,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorSurface1,
                                            borderRadius: BorderRadius.circular(
                                              radiusMd,
                                            ),
                                            border: Border.all(
                                              color: colorBorder,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.inventory_2_outlined,
                                                size: 16,
                                                color: colorTextMuted,
                                              ),
                                              const SizedBox(width: spaceSm),
                                              Text(
                                                'Unassigned posts',
                                                style: const TextStyle(
                                                  color: colorTextSecondary,
                                                  fontSize: fontSizeSm,
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: spaceSm,
                                                      vertical: spaceXxs,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colorAccentGold
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        radiusSm,
                                                      ),
                                                ),
                                                child: Text(
                                                  '$unassignedCount',
                                                  style: const TextStyle(
                                                    color: colorAccentGold,
                                                    fontSize: fontSizeXs,
                                                    fontWeight: weightSemibold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: spaceXs),
                                              const Icon(
                                                Icons.chevron_right,
                                                size: 18,
                                                color: colorInteractiveMuted,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],

                                    // View full timeline link
                                    const SizedBox(height: spaceXl),
                                    const Divider(color: colorBorder),
                                    const SizedBox(height: spaceMd),
                                    TextButton.icon(
                                      onPressed: () => context.push(
                                        '/@${artist.artistUsername}',
                                      ),
                                      icon: const Icon(
                                        Icons.grid_view,
                                        size: 16,
                                      ),
                                      label: const Text('View full timeline'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: colorInteractive,
                                      ),
                                    ),
                                    const SizedBox(height: spaceXl),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    child: _buildSidePanel(state),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _uploadAvatarImage(BuildContext context) async {
    final url = await ref
        .read(mediaUploadProvider.notifier)
        .pickAndUploadImage(
          category: UploadCategory.avatars,
          maxWidth: 512,
          maxHeight: 512,
        );
    if (url == null || !context.mounted) return;
    await ref.read(editArtistProvider.notifier).updateArtist(avatarUrl: url);
    if (!context.mounted) return;
    _refreshAfterUpload();
  }

  Future<void> _uploadCoverImage(BuildContext context) async {
    final url = await ref
        .read(mediaUploadProvider.notifier)
        .pickAndUploadImage(
          category: UploadCategory.covers,
          maxWidth: 1280,
          maxHeight: 720,
        );
    if (url == null || !context.mounted) return;
    await ref
        .read(editArtistProvider.notifier)
        .updateArtist(coverImageUrl: url);
    if (!context.mounted) return;
    _refreshAfterUpload();
  }

  void _refreshAfterUpload() {
    ref.read(artistPageProvider.notifier).loadArtist(widget.username);
    ref.invalidate(tuneInProvider);
    ref.read(tuneInProvider.notifier).loadMyTuneIns();
    ref.read(discoverProvider.notifier).loadInitial();
  }

  void _showEditDisplayName(BuildContext context, Artist artist) {
    final controller = TextEditingController(
      text: artist.displayName ?? artist.artistUsername,
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;

        Future<void> doSave(
          BuildContext ctx,
          void Function(void Function()) setState,
        ) async {
          final name = controller.text.trim();
          if (name.isEmpty) return;
          setState(() => isSaving = true);
          final ok = await ref
              .read(editArtistProvider.notifier)
              .updateArtist(displayName: name);
          if (!ctx.mounted) return;
          if (ok) {
            ref
                .read(artistPageProvider.notifier)
                .loadArtist(artist.artistUsername);
            ref.read(myArtistProvider.notifier).load();
            Navigator.pop(dialogContext);
          }
          setState(() => isSaving = false);
        }

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colorSurface1,
            title: const Text(
              'Display Name',
              style: TextStyle(color: colorTextPrimary),
            ),
            content: TextField(
              controller: controller,
              maxLength: 50,
              autofocus: true,
              style: const TextStyle(color: colorTextPrimary),
              decoration: InputDecoration(
                hintText: 'Enter display name',
                hintStyle: const TextStyle(color: colorTextMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radiusMd),
                  borderSide: const BorderSide(color: colorBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radiusMd),
                  borderSide: const BorderSide(color: colorAccentGold),
                ),
                filled: true,
                fillColor: colorSurface0,
              ),
              onSubmitted: isSaving
                  ? null
                  : (_) => doSave(context, setDialogState),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => doSave(context, setDialogState),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorAccentGold,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(color: colorAccentGold),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditAboutSheet(BuildContext context, Artist artist) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditArtistAboutSheet(artist: artist),
    );
  }

  void _showEditLinksSheet(BuildContext context, Artist artist) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditArtistLinksSheet(artist: artist),
    );
  }

  void _showEditMilestonesSheet(BuildContext context, Artist artist) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditMilestonesSheet(
        milestones: artist.milestones,
        artistUsername: artist.artistUsername,
      ),
    );
  }

  void _showEditGenresSheet(BuildContext context, Artist artist) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditArtistGenresSheet(artist: artist),
    );
  }

  void _showEditTracksSheet(BuildContext context, Artist artist) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditArtistTracksSheet(artist: artist),
    );
  }
}

// ── Error View ──

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const _ErrorView({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: colorTextMuted, size: 40),
          const SizedBox(height: spaceMd),
          Text(error, style: const TextStyle(color: colorTextMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: spaceLg),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(color: colorAccentGold),
              ),
            ),
          ],
          const SizedBox(height: spaceMd),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

// ── Tune In Button ──

class _TuneInButton extends StatelessWidget {
  final bool isTunedIn;
  final VoidCallback onTap;

  const _TuneInButton({required this.isTunedIn, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: spaceMd),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTunedIn ? Icons.check : Icons.headphones,
              size: 16,
              color: isTunedIn ? colorAccentGold : colorSurface0,
            ),
            const SizedBox(width: spaceSm),
            Text(
              isTunedIn ? 'Tuned In' : 'Tune In',
              style: TextStyle(
                color: isTunedIn ? colorAccentGold : colorSurface0,
                fontSize: fontSizeMd,
                fontWeight: weightSemibold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Links Section ──

class _LinksSection extends StatelessWidget {
  final List<ArtistLink> links;

  const _LinksSection({required this.links});

  @override
  Widget build(BuildContext context) {
    // Sort: music first, then social/video, then others
    final sorted = [...links]
      ..sort((a, b) {
        const order = {
          'music': 0,
          'social': 1,
          'video': 1,
          'website': 2,
          'store': 3,
          'other': 4,
        };
        return (order[a.linkCategory] ?? 5).compareTo(
          order[b.linkCategory] ?? 5,
        );
      });

    return Wrap(
      spacing: spaceSm,
      runSpacing: spaceSm,
      children: sorted.map((l) => _LinkChip(link: l)).toList(),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final ArtistLink link;

  const _LinkChip({required this.link});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(link.url),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceXs,
        ),
        decoration: BoxDecoration(
          color: colorSurface2,
          borderRadius: BorderRadius.circular(radiusFull),
          border: Border.all(color: colorBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _platformIcon(link.platform),
              size: 14,
              color: colorInteractive,
            ),
            const SizedBox(width: spaceXs),
            Text(
              link.platform,
              style: const TextStyle(
                color: colorTextSecondary,
                fontSize: fontSizeSm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (uri.scheme != 'https' && uri.scheme != 'http') return;
    openUrlImpl(uri.toString());
  }

  static IconData _platformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('spotify') ||
        p.contains('apple') ||
        p.contains('soundcloud') ||
        p.contains('bandcamp')) {
      return Icons.music_note;
    }
    if (p.contains('youtube')) return Icons.play_circle_outline;
    if (p.contains('instagram') || p.contains('twitter') || p.contains('x')) {
      return Icons.alternate_email;
    }
    return Icons.link;
  }
}

// ── Recent Post Card ──

class _RecentPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;

  const _RecentPostCard({required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final trackColor = post.trackColor != null
        ? _parseHex(post.trackColor!)
        : colorInteractiveMuted;
    final date = post.createdAt.toLocal();
    final dateStr = '${date.month}/${date.day}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(spaceSm),
        decoration: BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: colorBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: media icon + track name + date
            Row(
              children: [
                Icon(_mediaIcon(post.mediaType), size: 16, color: trackColor),
                const SizedBox(width: spaceXs),
                if (post.trackName != null)
                  Expanded(
                    child: Text(
                      post.trackName!,
                      style: TextStyle(
                        color: trackColor.withValues(alpha: 0.7),
                        fontSize: fontSizeXs,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: colorTextMuted,
                    fontSize: fontSizeXs,
                  ),
                ),
              ],
            ),
            const SizedBox(height: spaceXs),
            // Title or body preview
            Text(
              post.title ?? _bodyPreview(post.body),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: colorTextPrimary,
                fontSize: fontSizeSm,
                fontWeight: weightMedium,
                height: 1.3,
              ),
            ),
            // Reactions
            if (post.reactionCounts.isNotEmpty) ...[
              const SizedBox(height: spaceXs),
              Text(
                post.reactionCounts
                    .map((r) => '${r.emoji}${r.count > 1 ? ' ${r.count}' : ''}')
                    .join('  '),
                style: const TextStyle(fontSize: fontSizeXs),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _bodyPreview(String? body) {
    if (body == null || body.isEmpty) return 'Untitled';
    return body.length > 50 ? '${body.substring(0, 50)}...' : body;
  }

  static IconData _mediaIcon(MediaType type) {
    return switch (type) {
      MediaType.text => Icons.article_outlined,
      MediaType.image => Icons.image_outlined,
      MediaType.video => Icons.videocam_outlined,
      MediaType.audio => Icons.headphones_outlined,
      MediaType.link => Icons.link,
    };
  }

  static Color _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// ── Shared Chip ──

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final bool dot;

  const _Chip({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.dot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: spaceMd,
        vertical: spaceXs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: spaceXs),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: fontSizeSm),
          ),
        ],
      ),
    );
  }
}

class _MilestonesSection extends StatefulWidget {
  final List<ArtistMilestone> milestones;

  const _MilestonesSection({required this.milestones});

  @override
  State<_MilestonesSection> createState() => _MilestonesSectionState();
}

class _MilestonesSectionState extends State<_MilestonesSection> {
  static const _previewCount = 3;
  bool _expanded = false;

  static IconData _icon(String category) => milestoneCategoryIcon(category);

  @override
  Widget build(BuildContext context) {
    final all = widget.milestones;
    final visible = _expanded ? all : all.take(_previewCount).toList();
    final hasMore = all.length > _previewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visible.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon(m.category), size: 18, color: colorAccentGold),
                const SizedBox(width: spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.title,
                              style: const TextStyle(
                                color: colorTextPrimary,
                                fontSize: fontSizeSm,
                                fontWeight: weightMedium,
                              ),
                            ),
                          ),
                          Text(
                            m.date.substring(0, 7),
                            style: const TextStyle(
                              color: colorTextMuted,
                              fontSize: fontSizeXs,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      if (m.description != null) ...[
                        const SizedBox(height: spaceXxs),
                        Text(
                          m.description!,
                          style: const TextStyle(
                            color: colorTextSecondary,
                            fontSize: fontSizeXs,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasMore)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'See all ${all.length} milestones',
              style: const TextStyle(
                color: colorInteractive,
                fontSize: fontSizeSm,
              ),
            ),
          ),
      ],
    );
  }
}
