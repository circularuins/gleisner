import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../models/track.dart' show parseHexColor;

/// Bottom sheet picker for selecting a related post.
class RelatedPostPicker extends StatefulWidget {
  final List<Post> posts;
  final String? excludePostId;
  final ValueChanged<Post> onSelected;

  const RelatedPostPicker({
    super.key,
    required this.posts,
    this.excludePostId,
    required this.onSelected,
  });

  @override
  State<RelatedPostPicker> createState() => _RelatedPostPickerState();
}

class _RelatedPostPickerState extends State<RelatedPostPicker> {
  String _query = '';
  String? _filterTrackId;

  List<Post> get _filteredPosts {
    var posts = widget.posts.where((p) => p.id != widget.excludePostId);

    if (_filterTrackId != null) {
      posts = posts.where((p) => p.trackId == _filterTrackId);
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      posts = posts.where(
        (p) =>
            (p.title?.toLowerCase().contains(q) ?? false) ||
            (p.body?.toLowerCase().contains(q) ?? false),
      );
    }

    return posts.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Set<String> get _trackIds {
    return widget.posts
        .where((p) => p.trackId != null)
        .map((p) => p.trackId!)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredPosts;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select related post',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search posts...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),

            // Track filter chips
            if (_trackIds.length > 1)
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _TrackFilterChip(
                      label: 'All',
                      color: null,
                      isSelected: _filterTrackId == null,
                      onTap: () => setState(() => _filterTrackId = null),
                    ),
                    ..._trackIds.map((tid) {
                      final post = widget.posts.firstWhere(
                        (p) => p.trackId == tid,
                      );
                      return _TrackFilterChip(
                        label: post.trackName ?? 'Unknown',
                        color: post.trackColor,
                        isSelected: _filterTrackId == tid,
                        onTap: () => setState(() => _filterTrackId = tid),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Post list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No posts found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(128),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final post = filtered[index];
                        return _PostListTile(
                          post: post,
                          onTap: () {
                            widget.onSelected(post);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TrackFilterChip extends StatelessWidget {
  final String label;
  final String? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TrackFilterChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = color != null ? parseHexColor(color) : null;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        avatar: trackColor != null
            ? CircleAvatar(backgroundColor: trackColor, radius: 6)
            : null,
        selected: isSelected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: isSelected
              ? (trackColor ?? theme.colorScheme.primary)
              : theme.colorScheme.outline.withAlpha(80),
        ),
      ),
    );
  }
}

class _PostListTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _PostListTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = post.trackColor != null
        ? parseHexColor(post.trackColor)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: trackColor != null
            ? Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        title: Text(
          _postLabel(post),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: Text(
          '${post.trackName ?? ''} · ${_formatDate(post.createdAt)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
        ),
        trailing: Icon(
          _mediaTypeIcon(post.mediaType),
          size: 16,
          color: theme.colorScheme.onSurface.withAlpha(100),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}';
  }

  static IconData _mediaTypeIcon(MediaType type) {
    return switch (type) {
      MediaType.text => Icons.article,
      MediaType.image => Icons.image,
      MediaType.video => Icons.videocam,
      MediaType.audio => Icons.audiotrack,
      MediaType.link => Icons.link,
    };
  }

  static String _postLabel(Post p) {
    if (p.title != null && p.title!.isNotEmpty) return p.title!;
    if (p.body != null && p.body!.isNotEmpty) {
      return p.body!.substring(0, p.body!.length.clamp(0, 50));
    }
    final icon = switch (p.mediaType) {
      MediaType.image => '📷',
      MediaType.video => '🎬',
      MediaType.audio => '🎵',
      MediaType.link => '🔗',
      MediaType.text => '📝',
    };
    final date = p.createdAt.toLocal();
    final dateStr = '${date.month}/${date.day}';
    final track = p.trackName ?? '';
    return '$icon ${p.mediaType.name[0].toUpperCase()}${p.mediaType.name.substring(1)} · $track · $dateStr';
  }
}
