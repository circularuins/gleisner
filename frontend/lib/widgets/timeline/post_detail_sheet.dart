import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../models/track.dart' show parseHexColor;
import '../../utils/constellation_graph.dart';
import '../common/related_post_picker.dart';
import 'seed_art_painter.dart';

const _reactionPresets = ['🔥', '❤️', '👏', '✨', '😍', '🎵', '💪', '🎸'];

/// Show the post detail bottom sheet.
void showPostDetailSheet(
  BuildContext context,
  Post post, {
  Future<bool> Function(String postId, String emoji)? onToggleReaction,
  void Function(
    String postId,
    List<ReactionCount> counts,
    List<String> myReactions,
  )?
  onReactionsChanged,
  Future<PostConnection?> Function(String sourceId, String targetId)?
  onCreateConnection,
  Future<bool> Function(String connectionId)? onDeleteConnection,
  void Function(PostConnection conn)? onConnectionAdded,
  void Function(PostConnection conn)? onConnectionRemoved,
  void Function(Set<String> postIds)? onViewConstellation,
  List<Post> allPosts = const [],
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostDetailSheet(
      post: post,
      onToggleReaction: onToggleReaction,
      onReactionsChanged: onReactionsChanged,
      onCreateConnection: onCreateConnection,
      onDeleteConnection: onDeleteConnection,
      onConnectionAdded: onConnectionAdded,
      onConnectionRemoved: onConnectionRemoved,
      onViewConstellation: onViewConstellation,
      allPosts: allPosts,
    ),
  );
}

class _PostDetailSheet extends StatefulWidget {
  final Post post;
  final Future<bool> Function(String postId, String emoji)? onToggleReaction;
  final void Function(
    String postId,
    List<ReactionCount> counts,
    List<String> myReactions,
  )?
  onReactionsChanged;
  final Future<PostConnection?> Function(String sourceId, String targetId)?
  onCreateConnection;
  final Future<bool> Function(String connectionId)? onDeleteConnection;
  final void Function(PostConnection conn)? onConnectionAdded;
  final void Function(PostConnection conn)? onConnectionRemoved;
  final void Function(Set<String> postIds)? onViewConstellation;
  final List<Post> allPosts;
  const _PostDetailSheet({
    required this.post,
    this.onToggleReaction,
    this.onReactionsChanged,
    this.onCreateConnection,
    this.onDeleteConnection,
    this.onConnectionAdded,
    this.onConnectionRemoved,
    this.onViewConstellation,
    this.allPosts = const [],
  });

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  late List<ReactionCount> _reactionCounts;
  late Set<String> _myReactions;
  late List<PostConnection> _outgoingConnections;
  late List<PostConnection> _incomingConnections;
  bool _isToggling = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _reactionCounts = List.from(widget.post.reactionCounts);
    _myReactions = Set.from(widget.post.myReactions);
    _outgoingConnections = List.from(widget.post.outgoingConnections);
    _incomingConnections = List.from(widget.post.incomingConnections);
  }

  Future<void> _toggleReaction(String emoji) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    try {
      final success =
          await widget.onToggleReaction?.call(widget.post.id, emoji) ?? false;

      if (!mounted) return;

      if (success) {
        final wasActive = _myReactions.contains(emoji);
        setState(() {
          if (wasActive) {
            _myReactions.remove(emoji);
            _updateCount(emoji, -1);
          } else {
            _myReactions.add(emoji);
            _updateCount(emoji, 1);
          }
        });
        widget.onReactionsChanged?.call(
          widget.post.id,
          List.from(_reactionCounts),
          _myReactions.toList(),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  void _updateCount(String emoji, int delta) {
    final idx = _reactionCounts.indexWhere((r) => r.emoji == emoji);
    if (idx >= 0) {
      final newCount = _reactionCounts[idx].count + delta;
      if (newCount <= 0) {
        _reactionCounts.removeAt(idx);
      } else {
        _reactionCounts[idx] = ReactionCount(emoji: emoji, count: newCount);
      }
    } else if (delta > 0) {
      _reactionCounts.add(ReactionCount(emoji: emoji, count: 1));
    }
    _reactionCounts.sort((a, b) => b.count.compareTo(a.count));
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final trackColor = post.trackDisplayColor;
    final seedString = '${post.title ?? ''}${post.createdAt.toIso8601String()}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0c0c12),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF444460),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _buildMediaArea(context, post, trackColor, seedString),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date
                    Text(
                      _formatDateTime(),
                      style: const TextStyle(
                        color: Color(0xFF9999b0),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Title
                    if (post.title != null) ...[
                      Text(
                        post.title!,
                        style: const TextStyle(
                          color: Color(0xFFf0f0f5),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Body
                    if (post.body != null) ...[
                      Text(
                        post.body!,
                        style: const TextStyle(
                          color: Color(0xFFccccdd),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              // Reactions — subtle, no divider above
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: _buildReactionsSection(trackColor),
              ),
              // Connections
              if (widget.allPosts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildConnectionsSection(trackColor),
                ),
              // Constellation
              if (widget.allPosts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildConstellationSection(trackColor),
                ),
              // Comments placeholder
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      color: const Color(0xFF1a1a28).withValues(alpha: 0.5),
                      height: 1,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Comments',
                      style: TextStyle(
                        color: Color(0xFF666688),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Coming soon',
                      style: TextStyle(color: Color(0xFF444466), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReactionsSection(Color trackColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing reactions (compact pills)
        if (_reactionCounts.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _reactionCounts.map((r) {
              final isActive = _myReactions.contains(r.emoji);
              return GestureDetector(
                onTap: () => _toggleReaction(r.emoji),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? trackColor.withValues(alpha: 0.12)
                        : const Color(0xFF131320),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive
                          ? trackColor.withValues(alpha: 0.3)
                          : const Color(0xFF1a1a28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r.emoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 4),
                      Text(
                        '${r.count}',
                        style: TextStyle(
                          color: isActive
                              ? trackColor
                              : const Color(0xFF9999b0),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        // Emoji picker (smaller, more subtle)
        Wrap(
          spacing: 2,
          runSpacing: 2,
          children: _reactionPresets.map((emoji) {
            final isActive = _myReactions.contains(emoji);
            return GestureDetector(
              onTap: () => _toggleReaction(emoji),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isActive
                      ? trackColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 16,
                    color: isActive ? null : const Color(0xFF666688),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConnectionsSection(Color trackColor) {
    final postMap = {for (final p in widget.allPosts) p.id: p};
    // Combine outgoing + incoming for display
    final connectedPosts =
        <({PostConnection conn, Post post, bool isOutgoing})>[];
    for (final c in _outgoingConnections) {
      final target = postMap[c.targetId];
      if (target != null) {
        connectedPosts.add((conn: c, post: target, isOutgoing: true));
      }
    }
    for (final c in _incomingConnections) {
      final source = postMap[c.sourceId];
      if (source != null) {
        connectedPosts.add((conn: c, post: source, isOutgoing: false));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: const Color(0xFF1a1a28).withValues(alpha: 0.5),
          height: 1,
        ),
        const SizedBox(height: 12),
        const Text(
          'Connections',
          style: TextStyle(
            color: Color(0xFF666688),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (connectedPosts.isNotEmpty)
          ...connectedPosts.map((entry) {
            final p = entry.post;
            final pColor = p.trackColor != null
                ? parseHexColor(p.trackColor)
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    entry.isOutgoing ? Icons.arrow_forward : Icons.arrow_back,
                    size: 14,
                    color: const Color(0xFF666688),
                  ),
                  const SizedBox(width: 6),
                  if (pColor != null)
                    Container(
                      width: 3,
                      height: 20,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: pColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _connectionLabel(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFccccdd),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _deleteConnection(entry.conn),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: Color(0xFF666688),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        GestureDetector(
          onTap: _isConnecting ? null : _addConnection,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  size: 16,
                  color: _isConnecting
                      ? const Color(0xFF444466)
                      : trackColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnecting ? 'Linking...' : 'Link post',
                  style: TextStyle(
                    color: _isConnecting
                        ? const Color(0xFF444466)
                        : trackColor.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addConnection() async {
    Post? selectedPost;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RelatedPostPicker(
        posts: widget.allPosts,
        excludePostId: widget.post.id,
        onSelected: (post) {
          selectedPost = post;
        },
      ),
    );
    if (selectedPost == null || !mounted) return;

    setState(() => _isConnecting = true);
    try {
      final conn = await widget.onCreateConnection?.call(
        widget.post.id,
        selectedPost!.id,
      );
      if (conn != null && mounted) {
        setState(() {
          _outgoingConnections.add(conn);
        });
        widget.onConnectionAdded?.call(conn);
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _deleteConnection(PostConnection conn) async {
    final success = await widget.onDeleteConnection?.call(conn.id) ?? false;
    if (success && mounted) {
      setState(() {
        _outgoingConnections.removeWhere((c) => c.id == conn.id);
        _incomingConnections.removeWhere((c) => c.id == conn.id);
      });
      widget.onConnectionRemoved?.call(conn);
    }
  }

  Widget _buildConstellationSection(Color trackColor) {
    final constellation = findConstellation(widget.post.id, widget.allPosts);
    // Hide if only self (no connections)
    if (constellation.length <= 1) return const SizedBox.shrink();

    final postMap = {for (final p in widget.allPosts) p.id: p};
    final members =
        constellation
            .where((id) => id != widget.post.id && postMap.containsKey(id))
            .map((id) => postMap[id]!)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: const Color(0xFF1a1a28).withValues(alpha: 0.5),
          height: 1,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Constellation · ${constellation.length} posts',
              style: const TextStyle(
                color: Color(0xFF666688),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onViewConstellation?.call(constellation);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: trackColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'View',
                    style: TextStyle(
                      color: trackColor.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...members.map((p) {
          final pColor = p.trackColor != null
              ? parseHexColor(p.trackColor)
              : null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (pColor != null)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: pColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _connectionLabel(p),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9999b0),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- Media area methods ---

  Widget _buildMediaArea(
    BuildContext context,
    Post post,
    Color trackColor,
    String seedString,
  ) {
    final width = MediaQuery.of(context).size.width;
    return switch (post.mediaType) {
      MediaType.text => _textMediaArea(post, trackColor),
      MediaType.image => _visualMediaArea(post, trackColor, seedString, width),
      MediaType.video => _videoMediaArea(post, trackColor, seedString, width),
      MediaType.audio => _audioMediaArea(post, trackColor),
      MediaType.link => _linkMediaArea(post, trackColor),
    };
  }

  /// Wrap a non-Stack media area with track tag + type badge.
  Widget _withBadges(Post post, Color trackColor, Widget child) {
    return Stack(
      children: [
        SizedBox(width: double.infinity, child: child),
        _trackTag(post, trackColor, positioned: true),
        _typeBadge(post),
      ],
    );
  }

  Widget _textMediaArea(Post post, Color trackColor) {
    return _withBadges(
      post,
      trackColor,
      Container(
        height: 160,
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              trackColor.withValues(alpha: 0.1),
              const Color(0xFF0c0c12),
              trackColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            if (post.body != null)
              Text(
                post.body!,
                style: const TextStyle(
                  color: Color(0xFFccccdd),
                  fontSize: 16,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _visualMediaArea(
    Post post,
    Color trackColor,
    String seedString,
    double width,
  ) {
    return Stack(
      children: [
        SeedArtCanvas(
          width: width,
          height: 220,
          trackColor: trackColor,
          seed: seedString,
        ),
        _trackTag(post, trackColor, positioned: true),
        _typeBadge(post),
      ],
    );
  }

  Widget _videoMediaArea(
    Post post,
    Color trackColor,
    String seedString,
    double width,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SeedArtCanvas(
          width: width,
          height: 220,
          trackColor: trackColor,
          seed: seedString,
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        _trackTag(post, trackColor, positioned: true),
        _typeBadge(post),
        if (post.formattedDuration != null)
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                post.formattedDuration!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _audioMediaArea(Post post, Color trackColor) {
    return _withBadges(
      post,
      trackColor,
      Container(
        height: 120,
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              trackColor.withValues(alpha: 0.08),
              const Color(0xFF0c0c12),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: trackColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: trackColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                if (post.formattedDuration != null)
                  Text(
                    post.formattedDuration!,
                    style: TextStyle(
                      color: trackColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkMediaArea(Post post, Color trackColor) {
    final domain = post.mediaUrl != null
        ? Uri.tryParse(post.mediaUrl!)?.host ?? ''
        : '';
    return _withBadges(
      post,
      trackColor,
      Container(
        height: 120,
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              trackColor.withValues(alpha: 0.06),
              const Color(0xFF0c0c12),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Row(
              children: [
                Icon(Icons.link_rounded, size: 20, color: trackColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.mediaUrl ?? '',
                    style: TextStyle(
                      color: trackColor.withValues(alpha: 0.8),
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (domain.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 28),
                child: Text(
                  domain,
                  style: TextStyle(
                    color: trackColor.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trackTag(Post post, Color trackColor, {bool positioned = false}) {
    final tag = post.trackName != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: trackColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              post.trackName!.toUpperCase(),
              style: TextStyle(
                color: trackColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          )
        : const SizedBox.shrink();
    if (positioned) return Positioned(top: 12, left: 12, child: tag);
    return tag;
  }

  Widget _typeBadge(Post post) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF151520),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1a1a28)),
        ),
        child: Text(
          post.mediaType.name.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF8888a0),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String _formatDateTime() {
    final local = widget.post.createdAt.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String _connectionLabel(Post p) {
    if (p.title != null && p.title!.isNotEmpty) return p.title!;
    if (p.body != null && p.body!.isNotEmpty) {
      return p.body!.substring(0, p.body!.length.clamp(0, 30));
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
