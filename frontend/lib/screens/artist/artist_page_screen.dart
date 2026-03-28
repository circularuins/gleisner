import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/artist.dart';
import '../../models/post.dart';
import '../../providers/artist_page_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/my_artist_provider.dart';
import '../../providers/pending_artist_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../widgets/timeline/post_detail_sheet.dart';
import '../unassigned_posts/unassigned_posts_screen.dart';
import 'edit_artist_about_sheet.dart';
import 'edit_artist_genres_sheet.dart';
import 'edit_artist_links_sheet.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(artistPageProvider.notifier).loadArtist(widget.username);
      ref.read(unassignedPostsProvider.notifier).load();
    });
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
          : CustomScrollView(
              slivers: [
                // Cover image
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: colorSurface0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: colorTextPrimary),
                    onPressed: () => context.pop(),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: _CoverPainter(seed: artist.artistUsername),
                        ),
                        // Gradient fade at bottom
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 60,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00000000), colorSurface0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: spaceXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: spaceLg),
                        // Avatar
                        _GenerativeAvatar(
                          seed: artist.artistUsername,
                          size: 72,
                        ),
                        const SizedBox(height: spaceMd),

                        // Header: name + username + tuned in count
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                artist.displayName ?? artist.artistUsername,
                                style: const TextStyle(
                                  color: colorTextPrimary,
                                  fontSize: fontSizeTitle,
                                  fontWeight: weightBold,
                                ),
                              ),
                            ),
                            if (artist.profileVisibility == 'private') ...[
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
                                    .read(pendingArtistProvider.notifier)
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
                                      _showEditGenresSheet(context, artist),
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
                                      _showEditAboutSheet(context, artist),
                                ),
                              ],
                            ),
                          // Location + Active since
                          if (artist.location != null ||
                              artist.activeSince != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: spaceSm),
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
                                      style: TextStyle(color: colorTextMuted),
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
                              padding: const EdgeInsets.only(bottom: spaceSm),
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
                                      _showEditLinksSheet(context, artist),
                                ),
                              ],
                            ),
                          if (artist.links.isNotEmpty)
                            _LinksSection(links: artist.links),
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
                                      _showEditTracksSheet(context, artist),
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
                                bgColor: track.displayColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderColor: track.displayColor.withValues(
                                  alpha: 0.3,
                                ),
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
                                        (MediaQuery.of(context).size.width -
                                            spaceXl * 2 -
                                            spaceSm) /
                                        2,
                                    child: _RecentPostCard(
                                      post: p,
                                      onTap: () =>
                                          showPostDetailSheet(context, p),
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
                            borderRadius: BorderRadius.circular(radiusMd),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => UnassignedPostsScreen(
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
                                borderRadius: BorderRadius.circular(radiusMd),
                                border: Border.all(color: colorBorder),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: spaceSm,
                                      vertical: spaceXxs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorAccentGold.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(
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
                          onPressed: () =>
                              context.push('/@${artist.artistUsername}'),
                          icon: const Icon(Icons.grid_view, size: 16),
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
              ],
            ),
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
    final musicLinks = links.where((l) => l.linkCategory == 'music').toList();
    final snsLinks = links
        .where((l) => l.linkCategory == 'social' || l.linkCategory == 'video')
        .toList();
    final otherLinks = links
        .where(
          (l) =>
              l.linkCategory != 'music' &&
              l.linkCategory != 'social' &&
              l.linkCategory != 'video',
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (musicLinks.isNotEmpty) ...[
          const Text(
            'MUSIC',
            style: TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeXs,
              fontWeight: weightSemibold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: spaceSm),
          Wrap(
            spacing: spaceSm,
            runSpacing: spaceSm,
            children: musicLinks.map((l) => _LinkChip(link: l)).toList(),
          ),
          const SizedBox(height: spaceMd),
        ],
        if (snsLinks.isNotEmpty) ...[
          const Text(
            'SNS',
            style: TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeXs,
              fontWeight: weightSemibold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: spaceSm),
          Wrap(
            spacing: spaceSm,
            runSpacing: spaceSm,
            children: snsLinks.map((l) => _LinkChip(link: l)).toList(),
          ),
          const SizedBox(height: spaceMd),
        ],
        if (otherLinks.isNotEmpty) ...[
          Wrap(
            spacing: spaceSm,
            runSpacing: spaceSm,
            children: otherLinks.map((l) => _LinkChip(link: l)).toList(),
          ),
        ],
      ],
    );
  }
}

class _LinkChip extends StatelessWidget {
  final ArtistLink link;

  const _LinkChip({required this.link});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Icon(_platformIcon(link.platform), size: 14, color: colorInteractive),
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
    );
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

// ── Generative Cover ──

class _CoverPainter extends CustomPainter {
  final String seed;

  _CoverPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);
    final hue1 = rng.next() * 360;
    final hue2 = hue1 + 30 + rng.next() * 60;
    final color1 = HSLColor.fromAHSL(1, hue1, 0.4, 0.15).toColor();
    final color2 = HSLColor.fromAHSL(1, hue2 % 360, 0.5, 0.12).toColor();

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ).createShader(Offset.zero & size),
    );

    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final x = rng.next() * size.width;
      final y = rng.next() * size.height;
      final r = 15 + rng.next() * 40;
      final hue = (hue1 + rng.next() * 120) % 360;
      paint.color = HSLColor.fromAHSL(0.12, hue, 0.5, 0.4).toColor();
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.seed != seed;
}

// ── Generative Avatar ──

class _GenerativeAvatar extends StatelessWidget {
  final String seed;
  final double size;

  const _GenerativeAvatar({required this.seed, required this.size});

  @override
  Widget build(BuildContext context) {
    final rng = DeterministicRng(seed);
    final hue = rng.next() * 360;
    final color = HSLColor.fromAHSL(1, hue, 0.5, 0.3).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: colorSurface0, width: 3),
      ),
      child: Center(
        child: Text(
          seed.isNotEmpty ? seed[0].toUpperCase() : '?',
          style: TextStyle(
            color: colorTextPrimary,
            fontSize: size * 0.35,
            fontWeight: weightBold,
          ),
        ),
      ),
    );
  }
}
