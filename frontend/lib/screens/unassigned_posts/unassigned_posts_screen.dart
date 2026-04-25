import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/post.dart';
import '../../models/track.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../widgets/timeline/post_detail_sheet.dart';
import '../edit_post/edit_post_screen.dart';
import '../../l10n/l10n.dart';
import '../../utils/month_names.dart';

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
        title: Text(
          context.l10n.unassignedPosts,
          style: const TextStyle(color: colorTextPrimary),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: colorAccentGold),
            )
          : state.posts.isEmpty
          ? Center(
              child: Text(
                context.l10n.noUnassignedPosts,
                style: const TextStyle(color: colorTextMuted),
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
                  tracks: tracks,
                  onTap: () => _openDetail(context, ref, post),
                  onAssign: (trackId) =>
                      _assignToTrack(context, ref, post.id, trackId),
                );
              },
            ),
    );
  }

  Future<void> _assignToTrack(
    BuildContext context,
    WidgetRef ref,
    String postId,
    String trackId,
  ) async {
    final result = await ref
        .read(unassignedPostsProvider.notifier)
        .updatePost(id: postId, trackId: trackId);
    if (result == null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.failedAssignPost)));
    }
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
  final List<Track> tracks;
  final VoidCallback onTap;
  final ValueChanged<String> onAssign;

  const _PostTile({
    required this.post,
    required this.tracks,
    required this.onTap,
    required this.onAssign,
  });

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
                    _formatDate(context, post.createdAt),
                    style: const TextStyle(
                      color: colorTextMuted,
                      fontSize: fontSizeXs,
                    ),
                  ),
                ],
              ),
            ),
            if (tracks.isNotEmpty)
              TextButton(
                onPressed: () => _showTrackPicker(context),
                style: TextButton.styleFrom(
                  foregroundColor: colorAccentGold,
                  padding: const EdgeInsets.symmetric(horizontal: spaceSm),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(context.l10n.assign),
              )
            else
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

  void _showTrackPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: spaceLg),
            Text(context.l10n.assignToTrack, style: textHeading),
            const SizedBox(height: spaceMd),
            ...tracks.map(
              (track) => ListTile(
                leading: CircleAvatar(
                  radius: 12,
                  backgroundColor: _parseColor(track.color),
                ),
                title: Text(
                  track.name,
                  style: const TextStyle(color: colorTextPrimary),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  final trackId = track.id;
                  Navigator.pop(context);
                  // onAssign triggers async work — trackId captured before pop
                  onAssign(trackId);
                },
              ),
            ),
            const SizedBox(height: spaceMd),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    // Fallback to muted interactive color when hex is malformed
    return value != null ? Color(0xFF000000 | value) : colorInteractiveMuted;
  }

  static IconData _mediaTypeIcon(MediaType type) {
    return switch (type) {
      MediaType.thought => Icons.chat_bubble_outline,
      MediaType.article => Icons.description_outlined,
      MediaType.image => Icons.image_outlined,
      MediaType.video => Icons.videocam_outlined,
      MediaType.audio => Icons.headphones_outlined,
      MediaType.link => Icons.link,
    };
  }

  static String _formatDate(BuildContext context, DateTime date) {
    return '${monthShort(context, date.month)} ${date.day}, ${date.year}';
  }
}
