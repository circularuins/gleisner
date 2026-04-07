import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;
import '../../models/post.dart';
import '../../models/track.dart' show parseHexColor;
import '../../theme/gleisner_tokens.dart';
import '../../utils/constellation_graph.dart';
import '../common/connection_type_picker.dart';
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
  Future<PostConnection?> Function(
    String sourceId,
    String targetId,
    ConnectionType connectionType,
  )?
  onCreateConnection,
  Future<bool> Function(String connectionId)? onDeleteConnection,
  void Function(PostConnection conn)? onConnectionAdded,
  void Function(PostConnection conn)? onConnectionRemoved,
  void Function(Set<String> postIds)? onViewConstellation,
  Future<PostConstellation?> Function(String postId, String name)?
  onNameConstellation,
  VoidCallback? onEdit,
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
      onNameConstellation: onNameConstellation,
      onEdit: onEdit,
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
  final Future<PostConnection?> Function(
    String sourceId,
    String targetId,
    ConnectionType connectionType,
  )?
  onCreateConnection;
  final Future<bool> Function(String connectionId)? onDeleteConnection;
  final void Function(PostConnection conn)? onConnectionAdded;
  final void Function(PostConnection conn)? onConnectionRemoved;
  final void Function(Set<String> postIds)? onViewConstellation;
  final Future<PostConstellation?> Function(String postId, String name)?
  onNameConstellation;
  final VoidCallback? onEdit;
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
    this.onNameConstellation,
    this.onEdit,
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
  List<Post>? _cachedSyncedPosts;

  // Quill resources for delta body rendering (disposed in dispose())
  QuillController? _quillController;
  FocusNode? _quillFocusNode;
  ScrollController? _quillScrollController;

  /// Returns allPosts with connections synced to local state (cached).
  ///
  /// Why this is needed: this sheet maintains optimistic local state for
  /// connections (_outgoingConnections / _incomingConnections) to enable
  /// instant UI feedback. However, widget.allPosts is immutable (passed
  /// once at sheet creation via showModalBottomSheet — never updated).
  /// This getter creates a view where:
  /// 1. The current post's connections are replaced with local state
  /// 2. Counterpart posts (targets of outgoing, sources of incoming) have
  ///    their connections synced to match, so findConstellation graph
  ///    traversal sees a consistent bidirectional graph.
  List<Post> get _allPostsWithLocalConnections {
    if (_cachedSyncedPosts != null) return _cachedSyncedPosts!;
    final postId = widget.post.id;
    // Index local connections by counterpart ID for O(1) lookup
    final outByTarget = <String, List<PostConnection>>{};
    for (final c in _outgoingConnections) {
      outByTarget.putIfAbsent(c.targetId, () => []).add(c);
    }
    final inBySource = <String, List<PostConnection>>{};
    for (final c in _incomingConnections) {
      inBySource.putIfAbsent(c.sourceId, () => []).add(c);
    }
    final localConnIds = {
      ..._outgoingConnections.map((c) => c.id),
      ..._incomingConnections.map((c) => c.id),
    };

    final result = widget.allPosts.map((p) {
      if (p.id == postId) {
        return p.copyWith(
          outgoingConnections: _outgoingConnections,
          incomingConnections: _incomingConnections,
        );
      }

      // Sync counterpart: add missing connections, remove stale ones
      final incomingIds = {for (final c in p.incomingConnections) c.id};
      final outgoingIds = {for (final c in p.outgoingConnections) c.id};
      var incoming = p.incomingConnections;
      var outgoing = p.outgoingConnections;
      bool changed = false;

      // Add connections from local outgoing that target this post
      final toAddIncoming = outByTarget[p.id]
          ?.where((c) => !incomingIds.contains(c.id))
          .toList();
      if (toAddIncoming != null && toAddIncoming.isNotEmpty) {
        incoming = [...incoming, ...toAddIncoming];
        changed = true;
      }
      // Add connections from local incoming that source from this post
      final toAddOutgoing = inBySource[p.id]
          ?.where((c) => !outgoingIds.contains(c.id))
          .toList();
      if (toAddOutgoing != null && toAddOutgoing.isNotEmpty) {
        outgoing = [...outgoing, ...toAddOutgoing];
        changed = true;
      }

      // Remove connections to/from current post that no longer exist locally
      final filteredIn = incoming
          .where((c) => c.sourceId != postId || localConnIds.contains(c.id))
          .toList();
      final filteredOut = outgoing
          .where((c) => c.targetId != postId || localConnIds.contains(c.id))
          .toList();
      if (filteredIn.length != incoming.length ||
          filteredOut.length != outgoing.length) {
        incoming = filteredIn;
        outgoing = filteredOut;
        changed = true;
      }

      if (!changed) return p;
      return p.copyWith(
        outgoingConnections: outgoing,
        incomingConnections: incoming,
      );
    }).toList();
    _cachedSyncedPosts = result;
    return result;
  }

  @override
  void initState() {
    super.initState();
    _reactionCounts = List.from(widget.post.reactionCounts);
    _myReactions = Set.from(widget.post.myReactions);
    _outgoingConnections = List.from(widget.post.outgoingConnections);
    _incomingConnections = List.from(widget.post.incomingConnections);
    // Initialize Quill resources for delta posts
    if (widget.post.bodyFormat == BodyFormat.delta &&
        widget.post.bodyDelta != null) {
      _quillController = QuillController(
        document: Document.fromJson(widget.post.bodyDelta!),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      _quillFocusNode = FocusNode();
      _quillScrollController = ScrollController();
    }
  }

  @override
  void dispose() {
    _quillController?.dispose();
    _quillFocusNode?.dispose();
    _quillScrollController?.dispose();
    super.dispose();
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
          decoration: BoxDecoration(
            color: colorSurface1,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(radiusSheet),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: spaceSm, bottom: spaceXs),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorInteractive,
                    borderRadius: BorderRadius.circular(spaceXxs),
                  ),
                ),
              ),
              _buildMediaArea(context, post, trackColor, seedString),
              // Content — layout varies by media type
              Padding(
                padding: const EdgeInsets.fromLTRB(20, spaceLg, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildContentSection(post),
                ),
              ),
              // Reactions — subtle, no divider above
              Padding(
                padding: const EdgeInsets.fromLTRB(20, spaceXs, 20, 0),
                child: _buildReactionsSection(trackColor),
              ),
              // Connections
              if (widget.allPosts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, spaceMd, 20, 0),
                  child: _buildConnectionsSection(trackColor),
                ),
              // Constellation
              if (widget.allPosts.isNotEmpty)
                Padding(
                  key: ValueKey(
                    'constellation-${_outgoingConnections.map((c) => c.id).join(',')}-${_incomingConnections.map((c) => c.id).join(',')}',
                  ),
                  padding: const EdgeInsets.fromLTRB(20, spaceMd, 20, 0),
                  child: _buildConstellationSection(trackColor),
                ),
              // Comments placeholder
              Padding(
                padding: const EdgeInsets.fromLTRB(20, spaceLg, 20, spaceXxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      color: colorBorder.withValues(alpha: opacityOverlay),
                      height: 1,
                    ),
                    const SizedBox(height: spaceMd),
                    Text('Comments', style: textLabel),
                    const SizedBox(height: spaceXs),
                    const Text(
                      'Coming soon',
                      style: TextStyle(
                        color: colorInteractiveMuted,
                        fontSize: fontSizeSm,
                      ),
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

  /// Build content section with media-type-aware layout.
  /// Image type: title first, then date + caption (Instagram-like).
  /// Text type: date first, then large title + reading time + body.
  /// Other types: date first, then title + body (default).
  List<Widget> _buildContentSection(Post post) {
    final isVisual =
        post.mediaType == MediaType.image || post.mediaType == MediaType.video;
    final isText = post.mediaType == MediaType.text;

    final dateRow = _buildDateRow(post);
    final titleWidget = post.title != null
        ? Text(
            post.title!,
            style: isText
                ? const TextStyle(
                    color: colorTextPrimary,
                    fontSize: 24,
                    fontWeight: weightBold,
                    height: 1.3,
                    letterSpacing: -0.3,
                  )
                : isVisual
                ? const TextStyle(
                    color: colorTextPrimary,
                    fontSize: 20,
                    fontWeight: weightSemibold,
                    height: 1.3,
                  )
                : textTitle,
          )
        : null;
    final bodyWidget = _buildBodyWidget(post);

    if (isVisual) {
      // Image/Video: title → caption → date (compact, media is the hero)
      return [
        if (titleWidget != null) ...[
          titleWidget,
          const SizedBox(height: spaceSm),
        ],
        if (bodyWidget != null) ...[
          bodyWidget,
          const SizedBox(height: spaceMd),
        ],
        dateRow,
        const SizedBox(height: spaceSm),
      ];
    }

    // Text & other types: date → title → body
    return [
      dateRow,
      const SizedBox(height: spaceMd),
      if (titleWidget != null) ...[
        titleWidget,
        if (isText && post.plainTextPreview != null) ...[
          const SizedBox(height: spaceSm),
          Text(
            _readingTime(post.plainTextPreview!),
            style: TextStyle(
              color: colorTextMuted.withValues(alpha: 0.6),
              fontSize: fontSizeSm,
            ),
          ),
        ],
        SizedBox(height: isText ? spaceLg : spaceSm),
      ],
      if (bodyWidget != null) ...[bodyWidget, const SizedBox(height: spaceLg)],
    ];
  }

  Widget _buildDateRow(Post post) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                _formatDateTime(),
                style: const TextStyle(
                  color: colorTextMuted,
                  fontSize: fontSizeSm,
                ),
              ),
              if (post.visibility == 'draft') ...[
                const SizedBox(width: spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: spaceXs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colorTextMuted.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(radiusSm),
                  ),
                  child: const Text(
                    'DRAFT',
                    style: TextStyle(
                      color: colorSurface0,
                      fontSize: fontSizeXs,
                      fontWeight: weightSemibold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.onEdit != null)
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: colorTextMuted,
            ),
            onPressed: widget.onEdit,
            tooltip: 'Edit post',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget? _buildBodyWidget(Post post) {
    if (_quillController != null) {
      return QuillEditor(
        controller: _quillController!,
        focusNode: _quillFocusNode!,
        scrollController: _quillScrollController!,
        config: QuillEditorConfig(
          showCursor: false,
          scrollable: false,
          expands: false,
          padding: EdgeInsets.zero,
          customStyles: _readingStyles(),
        ),
      );
    }
    if (post.body != null) {
      return Text(
        post.body!,
        style: post.mediaType == MediaType.text
            ? const TextStyle(
                color: colorTextSecondary,
                fontSize: fontSizeMd,
                height: 1.8,
              )
            : const TextStyle(
                color: colorTextSecondary,
                fontSize: fontSizeMd,
                height: 1.5,
              ),
      );
    }
    return null;
  }

  Widget _buildReactionsSection(Color trackColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing reactions (compact pills)
        if (_reactionCounts.isNotEmpty) ...[
          Wrap(
            spacing: spaceXs,
            runSpacing: spaceXs,
            children: _reactionCounts.map((r) {
              final canInteract = widget.onToggleReaction != null;
              final isActive = canInteract && _myReactions.contains(r.emoji);
              return GestureDetector(
                onTap: canInteract ? () => _toggleReaction(r.emoji) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: spaceSm,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? trackColor.withValues(alpha: opacitySubtle)
                        : colorSurface2,
                    borderRadius: BorderRadius.circular(radiusXl),
                    border: Border.all(
                      color: isActive
                          ? trackColor.withValues(alpha: opacityBorder)
                          : colorBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.emoji,
                        style: const TextStyle(fontSize: fontSizeLg),
                      ),
                      const SizedBox(width: spaceXs),
                      Text(
                        '${r.count}',
                        style: TextStyle(
                          color: isActive ? trackColor : colorTextMuted,
                          fontSize: fontSizeMd,
                          fontWeight: weightSemibold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: spaceSm),
        ],
        // Emoji picker — only shown when reactions are interactive
        if (widget.onToggleReaction != null)
          Wrap(
            spacing: spaceXxs,
            runSpacing: spaceXxs,
            children: _reactionPresets.map((emoji) {
              final isActive = _myReactions.contains(emoji);
              return GestureDetector(
                onTap: () => _toggleReaction(emoji),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? trackColor.withValues(alpha: opacitySubtle)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: fontSizeLg,
                      color: isActive ? null : colorInteractiveMuted,
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
          color: colorBorder.withValues(alpha: opacityOverlay),
          height: 1,
        ),
        const SizedBox(height: spaceMd),
        Text('Connections', style: textLabel),
        const SizedBox(height: spaceSm),
        if (connectedPosts.isNotEmpty)
          Wrap(
            spacing: spaceSm,
            runSpacing: spaceSm,
            children: connectedPosts.map((entry) {
              final p = entry.post;
              final pColor = p.trackColor != null
                  ? parseHexColor(p.trackColor)
                  : colorInteractiveMuted;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: spaceSm,
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
                      entry.conn.connectionType.icon,
                      size: 12,
                      color: colorTextMuted,
                    ),
                    const SizedBox(width: spaceXxs),
                    Icon(
                      entry.isOutgoing ? Icons.arrow_forward : Icons.arrow_back,
                      size: 12,
                      color: pColor,
                    ),
                    const SizedBox(width: spaceXxs),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pColor,
                      ),
                    ),
                    const SizedBox(width: spaceXxs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        _connectionLabel(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: colorTextSecondary,
                          fontSize: fontSizeSm,
                        ),
                      ),
                    ),
                    if (widget.onDeleteConnection != null) ...[
                      const SizedBox(width: spaceXxs),
                      GestureDetector(
                        onTap: () => _deleteConnection(entry.conn),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: colorInteractiveMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        if (widget.onCreateConnection != null)
          GestureDetector(
            onTap: _isConnecting ? null : _addConnection,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: spaceXs),
              child: Row(
                children: [
                  Icon(
                    Icons.add,
                    size: fontSizeLg,
                    color: _isConnecting
                        ? colorInteractiveMuted
                        : trackColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: spaceXs),
                  Text(
                    _isConnecting ? 'Linking...' : 'Link post',
                    style: TextStyle(
                      color: _isConnecting
                          ? colorInteractiveMuted
                          : trackColor.withValues(alpha: 0.7),
                      fontSize: fontSizeMd,
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
    // Step 1: Pick connection type
    final type = await showConnectionTypePicker(context);
    if (type == null || !mounted) return;

    // Step 2: Pick target post
    Post? selectedPost;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RelatedPostPicker(
        posts: widget.allPosts,
        excludePostIds: {
          widget.post.id,
          ..._outgoingConnections.map((c) => c.targetId),
          ..._incomingConnections.map((c) => c.sourceId),
        },
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
        type,
      );
      if (conn != null && mounted) {
        setState(() {
          _outgoingConnections = [..._outgoingConnections, conn];
          _cachedSyncedPosts = null;
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
        _outgoingConnections = _outgoingConnections
            .where((c) => c.id != conn.id)
            .toList();
        _incomingConnections = _incomingConnections
            .where((c) => c.id != conn.id)
            .toList();
        _cachedSyncedPosts = null;
      });
      widget.onConnectionRemoved?.call(conn);
    }
  }

  void _showNameDialog(
    Color trackColor,
    PostConstellation? existing,
    Set<String> constellationIds,
  ) {
    final controller = TextEditingController(text: existing?.name ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorBorder,
          title: Text(
            existing != null
                ? 'Rename constellation'
                : 'Name this constellation',
            style: const TextStyle(
              color: colorTextPrimary,
              fontSize: fontSizeXl,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            style: const TextStyle(color: colorTextPrimary),
            decoration: InputDecoration(
              hintText: 'e.g., Initial impulse',
              hintStyle: TextStyle(
                color: colorInteractiveMuted.withValues(alpha: opacityOverlay),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: trackColor.withValues(alpha: opacityBorder),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: trackColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(dialogContext);
                await widget.onNameConstellation?.call(widget.post.id, name);
                if (mounted) {
                  Navigator.pop(context);
                  widget.onViewConstellation?.call(constellationIds);
                }
              },
              child: Text('Save', style: TextStyle(color: trackColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConstellationSection(Color trackColor) {
    final currentAllPosts = _allPostsWithLocalConnections;
    final constellationIds = findConstellation(widget.post.id, currentAllPosts);
    if (constellationIds.length <= 1) return const SizedBox.shrink();

    final postMap = {for (final p in currentAllPosts) p.id: p};
    final members =
        constellationIds
            .where((id) => id != widget.post.id && postMap.containsKey(id))
            .map((id) => postMap[id]!)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final namedConstellation =
        widget.post.constellation ??
        members
            .where((p) => p.constellation != null)
            .map((p) => p.constellation!)
            .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: colorBorder.withValues(alpha: opacityOverlay),
          height: 1,
        ),
        const SizedBox(height: spaceMd),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showNameDialog(
                  trackColor,
                  namedConstellation,
                  constellationIds,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (namedConstellation != null)
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              namedConstellation.name,
                              style: TextStyle(
                                color: trackColor,
                                fontSize: fontSizeMd,
                                fontWeight: weightSemibold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: spaceSm),
                          Icon(
                            Icons.edit,
                            size: fontSizeLg,
                            color: trackColor.withValues(alpha: opacityOverlay),
                          ),
                        ],
                      ),
                    Text(
                      namedConstellation != null
                          ? '${constellationIds.length} posts'
                          : 'Constellation · ${constellationIds.length} posts',
                      style: const TextStyle(
                        color: colorInteractiveMuted,
                        fontSize: fontSizeSm,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (namedConstellation == null)
              GestureDetector(
                onTap: () =>
                    _showNameDialog(trackColor, null, constellationIds),
                child: Padding(
                  padding: const EdgeInsets.only(right: spaceMd),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit,
                        size: fontSizeMd,
                        color: trackColor.withValues(alpha: opacityOverlay),
                      ),
                      const SizedBox(width: spaceXs),
                      Text(
                        'Name',
                        style: TextStyle(
                          color: trackColor.withValues(alpha: opacityOverlay),
                          fontSize: fontSizeSm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onViewConstellation?.call(constellationIds);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: fontSizeMd,
                    color: trackColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: spaceXs),
                  Text(
                    'View',
                    style: TextStyle(
                      color: trackColor.withValues(alpha: 0.7),
                      fontSize: fontSizeMd,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: spaceSm),
        Wrap(
          spacing: spaceSm,
          runSpacing: spaceSm,
          children: members.map((p) {
            final pColor = p.trackColor != null
                ? parseHexColor(p.trackColor)
                : colorInteractiveMuted;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: spaceSm,
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
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pColor,
                    ),
                  ),
                  const SizedBox(width: spaceXxs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      _connectionLabel(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: colorTextMuted,
                        fontSize: fontSizeSm,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
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
      MediaType.image => _visualMediaArea(
        context,
        post,
        trackColor,
        seedString,
        width,
      ),
      MediaType.video => _videoMediaArea(post, trackColor, seedString, width),
      MediaType.audio => _audioMediaArea(post, trackColor),
      MediaType.link => _linkMediaArea(post, trackColor),
    };
  }

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
    // Minimal header for text posts — no preview duplication.
    // The body content below is the hero, not the header area.
    return Stack(
      children: [
        Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: trackColor.withValues(alpha: 0.15)),
            ),
          ),
        ),
        _trackTag(post, trackColor, positioned: true),
      ],
    );
  }

  Widget _visualMediaArea(
    BuildContext context,
    Post post,
    Color trackColor,
    String seedString,
    double width,
  ) {
    final hasImage = post.mediaUrl != null && post.mediaUrl!.isNotEmpty;
    // Instagram-style: image takes generous vertical space
    final imageHeight = (width * 0.85).clamp(280.0, 420.0);
    return Stack(
      children: [
        // Image — receives tap for fullscreen
        if (hasImage)
          GestureDetector(
            onTap: () => _openImageFullScreen(context, post.mediaUrl!),
            child: Image.network(
              post.mediaUrl!,
              width: width,
              height: imageHeight,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: width,
                  height: imageHeight,
                  color: colorSurface2,
                );
              },
              errorBuilder: (_, _, _) => SeedArtCanvas(
                width: width,
                height: imageHeight,
                trackColor: trackColor,
                seed: seedString,
                mediaType: MediaType.image,
              ),
            ),
          )
        else
          SeedArtCanvas(
            width: width,
            height: imageHeight,
            trackColor: trackColor,
            seed: seedString,
            mediaType: MediaType.image,
          ),
        // Bottom gradient — don't block scroll
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 100,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    colorSurface1.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Track tag — bottom-left
        Positioned(
          left: spaceMd,
          bottom: spaceMd,
          child: _trackTag(post, trackColor, positioned: false),
        ),
        // Fullscreen hint — bottom-right
        if (hasImage)
          Positioned(
            right: spaceMd,
            bottom: spaceMd,
            child: IgnorePointer(
              child: Icon(
                Icons.fullscreen_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _videoMediaArea(
    Post post,
    Color trackColor,
    String seedString,
    double width,
  ) {
    final hasUrl = post.mediaUrl != null && post.mediaUrl!.isNotEmpty;
    final videoHeight = (width * 0.56).clamp(200.0, 360.0); // 16:9 ratio
    if (hasUrl) {
      return Stack(
        children: [
          SizedBox(
            width: width,
            height: videoHeight,
            child: _VideoPlayer(url: post.mediaUrl!),
          ),
          // Bottom gradient — don't block scroll/player controls
          Positioned(
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
                      Colors.transparent,
                      colorSurface1.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: spaceMd,
            bottom: spaceMd,
            child: _trackTag(post, trackColor, positioned: false),
          ),
        ],
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        SeedArtCanvas(
          width: width,
          height: videoHeight,
          trackColor: trackColor,
          seed: seedString,
          mediaType: MediaType.video,
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
        Positioned(
          left: spaceMd,
          bottom: spaceMd,
          child: _trackTag(post, trackColor, positioned: false),
        ),
        if (post.formattedDuration != null)
          Positioned(
            right: spaceMd,
            bottom: spaceMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: spaceXs,
                vertical: spaceXxs,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(radiusSm),
              ),
              child: Text(
                post.formattedDuration!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: fontSizeSm,
                  fontWeight: weightSemibold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _audioMediaArea(Post post, Color trackColor) {
    final hasUrl = post.mediaUrl != null && post.mediaUrl!.isNotEmpty;
    if (hasUrl) {
      return _withBadges(
        post,
        trackColor,
        Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [trackColor.withValues(alpha: 0.08), colorSurface1],
            ),
          ),
          child: _AudioPlayer(url: post.mediaUrl!, trackColor: trackColor),
        ),
      );
    }
    return _withBadges(
      post,
      trackColor,
      Container(
        height: 120,
        padding: const EdgeInsets.fromLTRB(spaceLg, 40, spaceLg, spaceLg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [trackColor.withValues(alpha: 0.08), colorSurface1],
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
                    size: spaceXl,
                  ),
                ),
                const SizedBox(width: spaceMd),
                if (post.formattedDuration != null)
                  Text(
                    post.formattedDuration!,
                    style: TextStyle(
                      color: trackColor,
                      fontSize: fontSizeMd,
                      fontWeight: weightSemibold,
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
        padding: const EdgeInsets.fromLTRB(spaceLg, 40, spaceLg, spaceLg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [trackColor.withValues(alpha: 0.06), colorSurface1],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Row(
              children: [
                Icon(Icons.link_rounded, size: 20, color: trackColor),
                const SizedBox(width: spaceSm),
                Expanded(
                  child: Text(
                    post.mediaUrl ?? '',
                    style: TextStyle(
                      color: trackColor.withValues(alpha: 0.8),
                      fontSize: fontSizeMd,
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
                padding: const EdgeInsets.only(top: spaceXs, left: 28),
                child: Text(
                  domain,
                  style: TextStyle(
                    color: trackColor.withValues(alpha: opacityOverlay),
                    fontSize: fontSizeXs,
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
            padding: const EdgeInsets.symmetric(
              horizontal: spaceSm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: trackColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            child: Text(
              post.trackName!.toUpperCase(),
              style: TextStyle(
                color: trackColor,
                fontSize: fontSizeXs,
                fontWeight: weightBold,
                letterSpacing: 0.5,
              ),
            ),
          )
        : const SizedBox.shrink();
    if (positioned) {
      return Positioned(top: spaceMd, left: spaceMd, child: tag);
    }
    return tag;
  }

  Widget _typeBadge(Post post) {
    return Positioned(
      top: spaceMd,
      right: spaceMd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: spaceXs,
          vertical: spaceXxs,
        ),
        decoration: BoxDecoration(
          color: colorSurface2,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: colorBorder),
        ),
        child: Text(
          post.mediaType.name.toUpperCase(),
          style: textMicro.copyWith(color: colorInteractive),
        ),
      ),
    );
  }

  String _formatDateTime() {
    final local = widget.post.createdAt.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String _readingTime(String text) {
    // CJK characters (Japanese, Chinese, Korean)
    final cjk = RegExp(r'[\u3000-\u9fff\uf900-\ufaff]');
    final cjkCount = cjk.allMatches(text).length;
    final nonCjk = text.replaceAll(cjk, ' ');
    final wordCount = nonCjk
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    // ~200 wpm English, ~400 cpm CJK
    final minutes = ((wordCount / 200) + (cjkCount / 400)).ceil();
    return minutes <= 1 ? '1 min read' : '$minutes min read';
  }

  static DefaultStyles _readingStyles() {
    const lineSpacing = VerticalSpacing(0, 0);
    return DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextSecondary,
          fontSize: fontSizeMd,
          height: 1.8,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(6, 6),
        lineSpacing,
        null,
      ),
      h1: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextPrimary,
          fontSize: fontSizeTitle,
          fontWeight: weightBold,
          height: 1.4,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(20, 10),
        lineSpacing,
        null,
      ),
      h2: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextPrimary,
          fontSize: fontSizeXl,
          fontWeight: weightSemibold,
          height: 1.4,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(16, 8),
        lineSpacing,
        null,
      ),
      h3: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextPrimary,
          fontSize: fontSizeLg,
          fontWeight: weightMedium,
          height: 1.4,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(12, 6),
        lineSpacing,
        null,
      ),
      quote: DefaultTextBlockStyle(
        TextStyle(
          color: colorTextMuted,
          fontSize: fontSizeMd,
          fontStyle: FontStyle.italic,
          height: 1.7,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(10, 10),
        lineSpacing,
        BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorAccentGold.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
      ),
      code: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextSecondary,
          fontSize: fontSizeSm,
          fontFamily: 'monospace',
          height: 1.5,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(10, 10),
        lineSpacing,
        BoxDecoration(
          color: colorSurface2,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      bold: const TextStyle(fontWeight: weightBold, color: colorTextPrimary),
      italic: const TextStyle(fontStyle: FontStyle.italic),
      link: TextStyle(
        color: colorAccentGold,
        decoration: TextDecoration.underline,
        decorationColor: colorAccentGold.withValues(alpha: 0.4),
      ),
    );
  }

  static String _connectionLabel(Post p) {
    if (p.title != null && p.title!.isNotEmpty) return p.title!;
    final preview = p.plainTextPreview;
    if (preview != null && preview.isNotEmpty) {
      return preview.substring(0, preview.length.clamp(0, 30));
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

// ── Video Player ──

class _VideoPlayer extends StatefulWidget {
  final String url;
  const _VideoPlayer({required this.url});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  final GlobalKey _videoKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _showControls = true);
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        _controller.seekTo(Duration.zero);
      }
      _controller.play();
      _autoHideControls();
    }
  }

  void _onTapVideo() {
    if (_controller.value.isPlaying) {
      setState(() => _showControls = !_showControls);
      if (_showControls) _autoHideControls();
    } else {
      _togglePlayPause();
    }
  }

  void _autoHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleFullScreen() {
    final doc = web.document;
    if (doc.fullscreenElement != null) {
      doc.exitFullscreen();
    } else {
      // Find the <video> element created by video_player_web and
      // request fullscreen on it directly (not the whole page).
      final videos = doc.querySelectorAll('video');
      if (videos.length > 0) {
        final video = videos.item(videos.length - 1) as web.HTMLVideoElement;
        video.requestFullscreen().toDart.catchError((_) => null);
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final showOverlay = _showControls || !_controller.value.isPlaying;
    return SizedBox(
      height: 220,
      child: ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTapVideo,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(color: Colors.black),
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
              if (showOverlay)
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controller.value.position >= _controller.value.duration
                          ? Icons.replay_rounded
                          : _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              if (showOverlay)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: spaceSm,
                      vertical: spaceXxs,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _fmt(_controller.value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: spaceXs),
                        Expanded(
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: colorAccentGold,
                              bufferedColor: colorAccentGold.withValues(
                                alpha: 0.3,
                              ),
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        const SizedBox(width: spaceXs),
                        Text(
                          _fmt(_controller.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: spaceXs),
                        GestureDetector(
                          onTap: _toggleFullScreen,
                          child: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Audio Player ──

class _AudioPlayer extends StatefulWidget {
  final String url;
  final Color trackColor;
  const _AudioPlayer({required this.url, required this.trackColor});

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
    _controller.addListener(_onControllerUpdate);
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(spaceLg, 40, spaceLg, spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (!_initialized) return;
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.trackColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _initialized && _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: widget.trackColor,
                    size: spaceXl,
                  ),
                ),
              ),
              const SizedBox(width: spaceMd),
              if (_initialized)
                Expanded(
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: widget.trackColor,
                      bufferedColor: widget.trackColor.withValues(alpha: 0.3),
                      backgroundColor: colorBorder,
                    ),
                  ),
                )
              else
                const Expanded(child: LinearProgressIndicator()),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Image Full Screen ──

void _openImageFullScreen(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullScreenImage(url: imageUrl),
    ),
  );
}

class _FullScreenImage extends StatefulWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  State<_FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<_FullScreenImage>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _zoomAnimation;
  double _dragOffsetY = 0;
  bool _isDragging = false;

  bool get _isZoomed {
    final scale = _transformController.value.getMaxScaleOnAxis();
    return scale > 1.05;
  }

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _transformController.value = _zoomAnimation!.value;
          }
        });
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      // Reset to identity
      _zoomAnimation =
          Matrix4Tween(
            begin: _transformController.value,
            end: Matrix4.identity(),
          ).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut),
          );
    } else {
      // Zoom to 2x at center
      final s = MediaQuery.of(context).size;
      final zoomed = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(-s.width / 2, -s.height / 2)
        // ignore: deprecated_member_use
        ..scale(2.0)
        // ignore: deprecated_member_use
        ..translate(s.width / 2, s.height / 2);
      _zoomAnimation =
          Matrix4Tween(begin: _transformController.value, end: zoomed).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut),
          );
    }
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        onVerticalDragStart: _isZoomed
            ? null
            : (_) {
                _isDragging = true;
              },
        onVerticalDragUpdate: _isZoomed
            ? null
            : (details) {
                setState(() {
                  _dragOffsetY += details.delta.dy;
                });
              },
        onVerticalDragEnd: _isZoomed
            ? null
            : (details) {
                final velocity = details.primaryVelocity?.abs() ?? 0;
                if (_dragOffsetY.abs() > 100 || velocity > 800) {
                  _isDragging = false;
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _dragOffsetY = 0;
                    _isDragging = false;
                  });
                }
              },
        child: AnimatedContainer(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _dragOffsetY, 0),
          color: Colors.black.withValues(
            alpha: (1 - (_dragOffsetY.abs() / 300)).clamp(0.3, 1),
          ),
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white54,
                      strokeWidth: 2,
                    ),
                  );
                },
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
