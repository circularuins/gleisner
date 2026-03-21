import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../utils/constellation_layout.dart';
import 'post_detail_sheet.dart';
import 'seed_art_painter.dart';

/// Border radius by media type.
BorderRadius _borderForType(MediaType type) {
  return switch (type) {
    MediaType.text => BorderRadius.circular(8),
    MediaType.image => BorderRadius.circular(16),
    MediaType.video => const BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(4),
    ),
    MediaType.audio => BorderRadius.circular(999),
    MediaType.link => BorderRadius.circular(12),
  };
}

/// A single node in the constellation layout.
class NodeCard extends StatefulWidget {
  final PlacedNode node;
  final int index;
  final bool highlight;
  final bool focused;
  final VoidCallback? onTap;
  final Future<bool> Function(String postId, String emoji)? onToggleReaction;
  final VoidCallback? onOpenDetail;

  const NodeCard({
    super.key,
    required this.node,
    required this.index,
    this.highlight = false,
    this.focused = false,
    this.onTap,
    this.onToggleReaction,
    this.onOpenDetail,
  });

  @override
  State<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<NodeCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.highlight) _startAnimation();
  }

  @override
  void didUpdateWidget(NodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !oldWidget.highlight) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _controller?.dispose();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0.4), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeOut));
    _controller!.forward().then((_) {
      _controller?.dispose();
      _controller = null;
      _glowAnimation = null;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final post = node.post;
    final trackColor = post.trackDisplayColor;
    final importance = post.importance;
    final borderRadius = _borderForType(post.mediaType);

    final glowSpread = 4.0 + importance * 12;
    final glowBlur = 8.0 + importance * 16;
    final glowOpacity = 0.15 + importance * 0.25;

    Widget card = GestureDetector(
      onTap: widget.onTap ?? () => showPostDetailSheet(context, post),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: trackColor.withValues(alpha: glowOpacity),
              blurRadius: glowBlur,
              spreadRadius: glowSpread,
            ),
          ],
          border: Border.all(
            color: trackColor.withValues(alpha: 0.3),
            width: 1,
          ),
          color: const Color(0xFF0c0c12),
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildContent(node, trackColor),
      ),
    );

    // Wrap with reaction pills if present
    final reactions = post.reactionCounts;
    final myReactions = post.myReactions.toSet();
    if (reactions.isNotEmpty) {
      card = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card,
          const SizedBox(height: 4),
          Wrap(
            spacing: 3,
            runSpacing: 2,
            children: [
              ...reactions.take(3).map((r) {
                final isMine = myReactions.contains(r.emoji);
                return GestureDetector(
                  onTap: () => widget.onToggleReaction?.call(post.id, r.emoji),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isMine
                          ? trackColor.withValues(alpha: 0.15)
                          : const Color(0xFF151520),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMine
                            ? trackColor.withValues(alpha: 0.4)
                            : const Color(0xFF1a1a28),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.emoji, style: const TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          r.count >= 1000
                              ? '${(r.count / 1000).toStringAsFixed(1)}k'
                              : '${r.count}',
                          style: TextStyle(
                            color: isMine
                                ? trackColor
                                : const Color(0xFF8888a0),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (reactions.length > 3)
                GestureDetector(
                  onTap: widget.onOpenDetail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      '+${reactions.length - 3}',
                      style: const TextStyle(
                        color: Color(0xFF8888a0),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    // Focused state: elevated with brighter glow
    if (widget.focused) {
      card = Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: trackColor.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 6,
            ),
          ],
        ),
        child: card,
      );
    }

    if (_glowAnimation != null) {
      return AnimatedBuilder(
        animation: _glowAnimation!,
        builder: (context, child) {
          final v = _glowAnimation!.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: trackColor.withValues(alpha: 0.6 * v),
                  blurRadius: 30 + 20 * v,
                  spreadRadius: 8 + 16 * v,
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }

  Widget _buildContent(PlacedNode node, Color trackColor) {
    return switch (node.post.mediaType) {
      MediaType.text => _TextContent(node: node, trackColor: trackColor),
      MediaType.image => _ImageContent(node: node, trackColor: trackColor),
      MediaType.video => _VideoContent(node: node, trackColor: trackColor),
      MediaType.audio => _AudioContent(node: node, trackColor: trackColor),
      MediaType.link => _LinkContent(node: node, trackColor: trackColor),
    };
  }
}

// --- Text: body preview, no seed art ---
class _TextContent extends StatelessWidget {
  final PlacedNode node;
  final Color trackColor;
  const _TextContent({required this.node, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final post = node.post;
    // Limit height to node's media area; calculate max body lines from space
    final totalH = node.mediaHeight + 30; // same as layout infoH
    const headerH = 14.0; // track label
    const titleH = 30.0; // ~2 lines of title
    final bodyMaxH = totalH - headerH - (post.title != null ? titleH : 0) - 16;
    final bodyMaxLines = (bodyMaxH / 14).floor().clamp(1, 12);

    return SizedBox(
      height: totalH,
      child: Container(
        padding: const EdgeInsets.all(8),
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
            _TrackLabel(trackName: post.trackName, color: trackColor),
            if (post.title != null) ...[
              Text(
                post.title!,
                style: const TextStyle(
                  color: Color(0xFFeeeeee),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
            ],
            if (post.body != null)
              Expanded(
                child: Text(
                  post.body!,
                  style: TextStyle(
                    color: const Color(0xFFeeeeee).withValues(alpha: 0.7),
                    fontSize: 10,
                    height: 1.4,
                  ),
                  maxLines: bodyMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Image: seed art (future: real image) ---
class _ImageContent extends StatelessWidget {
  final PlacedNode node;
  final Color trackColor;
  const _ImageContent({required this.node, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final post = node.post;
    final seed = '${post.title ?? ''}${post.createdAt.toIso8601String()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SeedArtCanvas(
          width: node.width,
          height: node.mediaHeight,
          trackColor: trackColor,
          seed: seed,
        ),
        if (node.showInfo) _InfoBar(post: post, trackColor: trackColor),
      ],
    );
  }
}

// --- Video: seed art + play button + duration ---
class _VideoContent extends StatelessWidget {
  final PlacedNode node;
  final Color trackColor;
  const _VideoContent({required this.node, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final post = node.post;
    final seed = '${post.title ?? ''}${post.createdAt.toIso8601String()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SeedArtCanvas(
              width: node.width,
              height: node.mediaHeight,
              trackColor: trackColor,
              seed: seed,
            ),
            // Play button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            // Duration badge
            if (post.formattedDuration != null)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    post.formattedDuration!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (node.showInfo) _InfoBar(post: post, trackColor: trackColor),
      ],
    );
  }
}

// --- Audio: wave bars + play button ---
class _AudioContent extends StatelessWidget {
  final PlacedNode node;
  final Color trackColor;
  const _AudioContent({required this.node, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final post = node.post;
    final hasBody = post.body != null && post.body!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Wave bars as background
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: trackColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: trackColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CustomPaint(
                  size: Size(double.infinity, node.mediaHeight * 0.5),
                  painter: _WaveBarPainter(
                    color: trackColor.withValues(alpha: hasBody ? 0.25 : 0.5),
                    seed: '${post.title ?? ''}${post.id}',
                  ),
                ),
              ),
              if (post.formattedDuration != null) ...[
                const SizedBox(width: 6),
                Text(
                  post.formattedDuration!,
                  style: TextStyle(
                    color: trackColor.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          // Body text overlay on top of wave
          if (hasBody)
            Positioned(
              left: 38,
              right: post.formattedDuration != null ? 36 : 10,
              child: Text(
                post.body!,
                style: const TextStyle(
                  color: Color(0xFFeeeeee),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// --- Link: icon + domain ---
class _LinkContent extends StatelessWidget {
  final PlacedNode node;
  final Color trackColor;
  const _LinkContent({required this.node, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final post = node.post;
    final domain = post.mediaUrl != null
        ? Uri.tryParse(post.mediaUrl!)?.host ?? ''
        : '';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [trackColor.withValues(alpha: 0.04), const Color(0xFF0c0c12)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 14, color: trackColor),
              const SizedBox(width: 4),
              _TrackLabel(trackName: post.trackName, color: trackColor),
            ],
          ),
          const SizedBox(height: 4),
          if (post.title != null)
            Text(
              post.title!,
              style: const TextStyle(
                color: Color(0xFFeeeeee),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              post.body!,
              style: TextStyle(
                color: const Color(0xFFeeeeee).withValues(alpha: 0.6),
                fontSize: 10,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (domain.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              domain,
              style: TextStyle(
                color: trackColor.withValues(alpha: 0.6),
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// --- Shared widgets ---

class _TrackLabel extends StatelessWidget {
  final String? trackName;
  final Color color;
  const _TrackLabel({required this.trackName, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      (trackName ?? '').toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 8,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _InfoBar extends StatelessWidget {
  final Post post;
  final Color trackColor;
  const _InfoBar({required this.post, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrackLabel(trackName: post.trackName, color: trackColor),
          if (post.title != null)
            Text(
              post.title!,
              style: const TextStyle(
                color: Color(0xFFeeeeee),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// Simple wave bar visualizer (deterministic from seed).
class _WaveBarPainter extends CustomPainter {
  final Color color;
  final String seed;
  _WaveBarPainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    // Generate deterministic bar heights
    var h = 0;
    for (int i = 0; i < seed.length; i++) {
      h = ((h << 5) - h + seed.codeUnitAt(i)) & 0xFFFFFF;
    }

    final barCount = max(8, (size.width / 4).floor());
    final barWidth = size.width / barCount * 0.6;
    final gap = size.width / barCount;

    final paint = Paint()..color = color.withValues(alpha: 0.5);

    for (int i = 0; i < barCount; i++) {
      h = (h * 16807) % 2147483647;
      final frac = (h & 0x7FFFFFFF) / 0x7FFFFFFF;
      final barH = size.height * (0.2 + frac * 0.8);
      final x = i * gap;
      final y = (size.height - barH) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barH),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveBarPainter old) =>
      color != old.color || seed != old.seed;
}
