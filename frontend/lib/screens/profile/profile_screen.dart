import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../graphql/client.dart';
import '../../models/artist.dart';
import '../../models/post.dart';
import '../../models/track.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discover_provider.dart';
import '../../providers/edit_artist_provider.dart';
import '../../providers/my_artist_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../edit_post/edit_post_screen.dart';
import 'edit_profile_sheet.dart';
import 'register_artist_wizard.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Load unassigned posts when profile is opened
    ref.read(unassignedPostsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    // Use myArtistProvider (own artist) instead of timelineProvider
    // which may hold another artist's data in fan mode
    final artist = ref.watch(myArtistProvider);
    final tuneInState = ref.watch(tuneInProvider);
    final unassignedState = ref.watch(unassignedPostsProvider);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: const Text('Profile', style: TextStyle(color: colorTextPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: colorTextSecondary),
            onPressed: () => _showEditSheet(context, user),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(spaceXl),
        children: [
          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: colorSurface2,
                child: Text(
                  user.username[0].toUpperCase(),
                  style: textTitle.copyWith(color: colorTextPrimary),
                ),
              ),
              const SizedBox(width: spaceLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName ?? user.username, style: textHeading),
                    const SizedBox(height: spaceXxs),
                    Text(
                      '@${user.username}',
                      style: textCaption.copyWith(color: colorTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: spaceLg),
            Text(
              user.bio!,
              style: textBody.copyWith(color: colorTextSecondary),
            ),
          ],

          // Meta: Joined + Tuned In
          const SizedBox(height: spaceMd),
          Wrap(
            spacing: spaceLg,
            children: [
              Text(
                'Joined ${_formatJoinDate(user.createdAt)}',
                style: textCaption.copyWith(color: colorTextMuted),
              ),
              if (tuneInState.tunedInArtists.isNotEmpty)
                Text(
                  '${tuneInState.tunedInArtists.length} Tuned In',
                  style: textCaption.copyWith(color: colorTextMuted),
                ),
            ],
          ),
          const SizedBox(height: spaceXxl),

          // Artist section
          if (artist != null) ...[
            // Registered artist info
            Container(
              padding: const EdgeInsets.all(spaceLg),
              decoration: BoxDecoration(
                color: colorSurface1,
                borderRadius: BorderRadius.circular(radiusLg),
                border: Border.all(color: colorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: colorAccentGold,
                      ),
                      const SizedBox(width: spaceSm),
                      Text(
                        'Artist',
                        style: textLabel.copyWith(color: colorAccentGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: spaceMd),
                  Text(
                    artist.displayName ?? artist.artistUsername,
                    style: textHeading,
                  ),
                  const SizedBox(height: spaceXxs),
                  Text(
                    '@${artist.artistUsername}',
                    style: textCaption.copyWith(color: colorTextMuted),
                  ),
                  if (artist.tracks.isNotEmpty) ...[
                    const SizedBox(height: spaceMd),
                    Text(
                      '${artist.tracks.length} track${artist.tracks.length == 1 ? '' : 's'}',
                      style: textCaption.copyWith(color: colorTextSecondary),
                    ),
                  ],
                  // Artist visibility toggle
                  const SizedBox(height: spaceMd),
                  Row(
                    children: [
                      Icon(
                        artist.profileVisibility == 'private'
                            ? Icons.lock_outline
                            : Icons.public,
                        size: 14,
                        color: colorTextMuted,
                      ),
                      const SizedBox(width: spaceXs),
                      Text(
                        artist.profileVisibility == 'private'
                            ? 'Private'
                            : 'Public',
                        style: textCaption.copyWith(color: colorTextMuted),
                      ),
                      const Spacer(),
                      Switch(
                        value: artist.profileVisibility == 'public',
                        activeColor: colorAccentGold,
                        onChanged: (isPublic) async {
                          final v = isPublic ? 'public' : 'private';
                          await ref
                              .read(editArtistProvider.notifier)
                              .updateArtist(profileVisibility: v);
                          ref.read(discoverProvider.notifier).loadInitial();
                        },
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: spaceSm),
                    child: Text(
                      artist.profileVisibility == 'private'
                          ? 'Your artist page is hidden from Discover and search. Only existing fans and direct links can access it.'
                          : 'Your artist page is visible in Discover and search. Anyone can view your profile and Tune In.',
                      style: textCaption.copyWith(
                        color: colorTextMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: spaceSm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/artist/${artist.artistUsername}'),
                      icon: const Icon(Icons.person, size: 16),
                      label: const Text('View Artist Page'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorAccentGold,
                        side: BorderSide(
                          color: colorAccentGold.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Become an artist CTA
            GestureDetector(
              onTap: () => _showRegisterSheet(context),
              child: Container(
                padding: const EdgeInsets.all(spaceLg),
                decoration: BoxDecoration(
                  color: colorSurface1,
                  borderRadius: BorderRadius.circular(radiusLg),
                  border: Border.all(
                    color: colorAccentGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorAccentGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(radiusMd),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: colorAccentGold,
                      ),
                    ),
                    const SizedBox(width: spaceLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Become an Artist', style: textHeading),
                          const SizedBox(height: spaceXxs),
                          Text(
                            'Start sharing your creative journey',
                            style: textCaption.copyWith(
                              color: colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: colorInteractiveMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Unassigned posts section (only if artist exists and has unassigned posts)
          if (artist != null && unassignedState.posts.isNotEmpty) ...[
            const SizedBox(height: spaceXxl),
            _buildUnassignedPostsSection(unassignedState.posts, artist.tracks),
          ],

          const SizedBox(height: spaceXxl),

          // Logout
          OutlinedButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              ref.invalidate(graphqlClientProvider);
              ref.invalidate(timelineProvider);
              ref.invalidate(myArtistProvider);
              ref.invalidate(tuneInProvider);
              ref.invalidate(discoverProvider);
              ref.invalidate(unassignedPostsProvider);
              await ref.read(tutorialProvider.notifier).reset();
              ref.invalidate(tutorialProvider);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedPostsSection(List<Post> posts, List<Track> tracks) {
    return Container(
      padding: const EdgeInsets.all(spaceLg),
      decoration: BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: colorTextMuted,
              ),
              const SizedBox(width: spaceSm),
              Text(
                'Unassigned Posts',
                style: textLabel.copyWith(color: colorTextSecondary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: spaceSm,
                  vertical: spaceXxs,
                ),
                decoration: BoxDecoration(
                  color: colorAccentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(radiusSm),
                ),
                child: Text(
                  '${posts.length}',
                  style: textCaption.copyWith(color: colorAccentGold),
                ),
              ),
            ],
          ),
          const SizedBox(height: spaceSm),
          Text(
            'These posts lost their track. Tap to reassign.',
            style: textCaption.copyWith(
              color: colorTextMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: spaceMd),
          ...posts.map((post) => _buildUnassignedPostTile(post)),
        ],
      ),
    );
  }

  Widget _buildUnassignedPostTile(Post post) {
    final artist = ref.read(myArtistProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: spaceSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(radiusMd),
        onTap: () => _openEditForUnassigned(post, artist),
        child: Container(
          padding: const EdgeInsets.all(spaceMd),
          decoration: BoxDecoration(
            color: colorSurface0,
            borderRadius: BorderRadius.circular(radiusMd),
            border: Border.all(color: colorBorder),
          ),
          child: Row(
            children: [
              Icon(
                _mediaTypeIcon(post.mediaType),
                size: 20,
                color: colorTextMuted,
              ),
              const SizedBox(width: spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title ?? post.body ?? '(Untitled)',
                      style: textBody.copyWith(color: colorTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: spaceXxs),
                    Text(
                      _formatDate(post.createdAt),
                      style: textMicro.copyWith(color: colorTextMuted),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: colorInteractiveMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditForUnassigned(Post post, Artist? artist) {
    if (artist == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditPostScreen(
          post: post,
          tracks: artist.tracks,
          onSaved: (updated) {
            // If the post was reassigned to a track, remove it from the list
            if (updated.trackId != null) {
              ref.read(unassignedPostsProvider.notifier).removePost(updated.id);
            }
          },
        ),
      ),
    );
  }

  static IconData _mediaTypeIcon(MediaType type) {
    switch (type) {
      case MediaType.text:
        return Icons.article_outlined;
      case MediaType.image:
        return Icons.image_outlined;
      case MediaType.video:
        return Icons.videocam_outlined;
      case MediaType.audio:
        return Icons.headphones_outlined;
      case MediaType.link:
        return Icons.link;
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _formatJoinDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showEditSheet(BuildContext context, User user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(
        initialDisplayName: user.displayName,
        initialBio: user.bio,
        initialAvatarUrl: user.avatarUrl,
        initialProfileVisibility: user.profileVisibility,
      ),
    );
  }

  void _showRegisterSheet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RegisterArtistWizard(
          onRegistered: (artistUsername) {
            // Reload artist data + navigate to timeline
            ref.read(timelineProvider.notifier).loadArtist(artistUsername);
            ref.read(myArtistProvider.notifier).load();
            context.go('/timeline');
          },
        ),
      ),
    );
  }
}
