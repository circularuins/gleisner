import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/post.dart';
import '../../models/track.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/timeline/post_detail_sheet.dart';
import '../edit_post/edit_post_screen.dart';

class UnassignedPostsScreen extends ConsumerWidget {
  final List<Track> tracks;

  const UnassignedPostsScreen({super.key, required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(unassignedPostsProvider);

    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: const Text(
          'Unassigned Posts',
          style: TextStyle(color: colorTextPrimary),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: colorAccentGold),
            )
          : state.posts.isEmpty
          ? const Center(
              child: Text(
                'No unassigned posts',
                style: TextStyle(color: colorTextMuted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(spaceLg),
              itemCount: state.posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: spaceSm),
              itemBuilder: (context, index) {
                final post = state.posts[index];
                return _PostTile(
                  post: post,
                  onTap: () => _openDetail(context, ref, post),
                );
              },
            ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, Post post) {
    showPostDetailSheet(
      context,
      post,
      allPosts: ref.read(unassignedPostsProvider).posts,
      onEdit: () {
        // Close the detail sheet first, then open edit screen
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EditPostScreen(
              post: post,
              tracks: tracks,
              onSaved: (updated) {
                if (updated.trackId != null) {
                  ref
                      .read(unassignedPostsProvider.notifier)
                      .removePost(updated.id);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _PostTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(spaceMd),
        decoration: BoxDecoration(
          color: colorSurface1,
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
                    style: const TextStyle(
                      color: colorTextPrimary,
                      fontSize: fontSizeMd,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: spaceXxs),
                  Text(
                    _formatDate(post.createdAt),
                    style: const TextStyle(
                      color: colorTextMuted,
                      fontSize: fontSizeXs,
                    ),
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
    );
  }

  static IconData _mediaTypeIcon(MediaType type) {
    return switch (type) {
      MediaType.text => Icons.article_outlined,
      MediaType.image => Icons.image_outlined,
      MediaType.video => Icons.videocam_outlined,
      MediaType.audio => Icons.headphones_outlined,
      MediaType.link => Icons.link,
    };
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
}
