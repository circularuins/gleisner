import 'package:flutter/material.dart';

import '../../models/post.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final Color trackColor;

  const PostCard({super.key, required this.post, required this.trackColor});

  IconData get _mediaIcon => switch (post.mediaType) {
    MediaType.text => Icons.article_outlined,
    MediaType.image => Icons.image_outlined,
    MediaType.video => Icons.videocam_outlined,
    MediaType.audio => Icons.audiotrack_outlined,
    MediaType.link => Icons.link,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = 0.8 + (post.importance * 0.2);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: trackColor.withAlpha(77), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_mediaIcon, size: 18, color: trackColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.title ?? '(Untitled)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16 * scale,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (post.body != null && post.body!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                post.body!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(179),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  post.author.displayName ?? post.author.username,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }
}
