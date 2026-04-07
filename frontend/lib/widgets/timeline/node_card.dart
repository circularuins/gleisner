import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../models/timeline_item.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/constellation_layout.dart';
import 'post_detail_sheet.dart';
import 'seed_art_painter.dart';

/// Border radius by media type.
BorderRadius _borderForType(MediaType type) {
  return switch (type) {
    MediaType.text => BorderRadius.circular(radiusMd),
    MediaType.image => BorderRadius.circular(radiusXl),
    MediaType.video => const BorderRadius.only(
      topLeft: Radius.circular(radiusLg),
      topRight: Radius.circular(radiusLg),
      bottomLeft: Radius.circular(radiusSm),
      bottomRight: Radius.circular(radiusSm),
    ),
    MediaType.audio => BorderRadius.circular(radiusFull),
    MediaType.link => BorderRadius.circular(radiusLg),
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
    final post = (node.item as PostItem).post;
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
            color: trackColor.withValues(alpha: opacityBorder),
            width: 1,
          ),
          color: colorSurface1,
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildContent(node, trackColor),
      ),
    );

    // Draft badge overlay
    if (post.visibility == 'draft') {
      card = Stack(
        children: [
          Opacity(opacity: 0.6, child: card),
          Positioned(
            top: spaceXs,
            right: spaceXs,
            child: Container(
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
          ),
        ],
      );
    }

    // Wrap with reaction pills if present
    final reactions = post.reactionCounts;
    final myReactions = post.myReactions.toSet();
    if (reactions.isNotEmpty) {
      card = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card,
          const SizedBox(height: spaceXs),
          Wrap(
            spacing: 3,
            runSpacing: spaceXxs,
            children: [
              ...reactions.take(3).map((r) {
                final isMine = myReactions.contains(r.emoji);
                return GestureDetector(
                  onTap: () => widget.onToggleReaction?.call(post.id, r.emoji),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: spaceXs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isMine
                          ? trackColor.withValues(alpha: 0.15)
                          : colorSurface2,
                      borderRadius: BorderRadius.circular(radiusMd),
                      border: Border.all(
                        color: isMine
                            ? trackColor.withValues(alpha: 0.4)
                            : colorBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.emoji,
                          style: const TextStyle(fontSize: fontSizeXs),
                        ),
                        const SizedBox(width: spaceXxs),
                        Text(
                          r.count >= 1000
                              ? '${(r.count / 1000).toStringAsFixed(1)}k'
                              : '${r.count}',
                          style: TextStyle(
                            color: isMine ? trackColor : colorInteractive,
                            fontSize: fontSizeXs,
                            fontWeight: weightSemibold,
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
                      horizontal: spaceXs,
                      vertical: 1,
                    ),
                    child: Text(
                      '+${reactions.length - 3}',
                      style: const TextStyle(
                        color: colorInteractive,
                        fontSize: fontSizeXs,
                        fontWeight: weightSemibold,
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
              color: trackColor.withValues(alpha: opacityOverlay),
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
    return switch ((node.item as PostItem).post.mediaType) {
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
    final post = (node.item as PostItem).post;
    final totalH = node.mediaHeight + 30;
    final preview = post.plainTextPreview ?? '';
    final hasTitle = post.title != null && post.title!.isNotEmpty;
    final isShort = !hasTitle && preview.length < 100;

    return SizedBox(
      height: totalH,
      child: isShort
          ? _buildShortForm(post, preview, totalH)
          : _buildLongForm(post, preview, totalH),
    );
  }

  /// Short form: the text IS the visual. Large font, minimal chrome.
  /// Like a quote floating in space.
  Widget _buildShortForm(Post post, String preview, double totalH) {
    return Container(
      padding: const EdgeInsets.all(spaceMd),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: trackColor.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrackLabel(trackName: post.trackName, color: trackColor),
          const Spacer(),
          Text(
            preview,
            style: TextStyle(
              color: colorTextPrimary,
              fontSize: totalH > 120 ? fontSizeLg : fontSizeMd,
              height: 1.5,
              fontWeight: weightMedium,
            ),
            maxLines: (totalH / 24).floor().clamp(2, 6),
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  /// Long form: title-driven card with body preview and reading accent.
  Widget _buildLongForm(Post post, String preview, double totalH) {
    final bodyMaxLines = ((totalH - 50) / 14).floor().clamp(1, 8);
    final words = preview
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final readMin = (words / 200).ceil();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: trackColor.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(spaceMd, spaceSm, spaceSm, spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Track + reading time row
          Row(
            children: [
              _TrackLabel(trackName: post.trackName, color: trackColor),
              const Spacer(),
              if (words > 30)
                Text(
                  '$readMin min',
                  style: TextStyle(
                    color: colorTextMuted.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
            ],
          ),
          const SizedBox(height: spaceXs),
          // Title
          if (post.title != null && post.title!.isNotEmpty) ...[
            Text(
              post.title!,
              style: const TextStyle(
                color: colorTextPrimary,
                fontSize: fontSizeSm,
                fontWeight: weightBold,
                height: 1.3,
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: spaceXxs),
          ],
          // Body preview with fade
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.7, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: Text(
                preview,
                style: TextStyle(
                  color: colorTextPrimary.withValues(alpha: 0.6),
                  fontSize: fontSizeXs,
                  height: 1.5,
                ),
                maxLines: bodyMaxLines,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
        ],
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
    final post = (node.item as PostItem).post;
    final seed = '${post.title ?? ''}${post.createdAt.toIso8601String()}';
    final hasImage = post.mediaUrl != null && post.mediaUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              post.mediaUrl!,
              width: node.width,
              height: node.mediaHeight,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => SeedArtCanvas(
                width: node.width,
                height: node.mediaHeight,
                trackColor: trackColor,
                seed: seed,
                mediaType: MediaType.image,
              ),
            ),
          )
        else
          SeedArtCanvas(
            width: node.width,
            height: node.mediaHeight,
            trackColor: trackColor,
            seed: seed,
            mediaType: MediaType.image,
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
    final post = (node.item as PostItem).post;
    final seed = '${post.title ?? ''}${post.createdAt.toIso8601String()}';
    final hasThumbnail =
        post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (hasThumbnail)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  post.thumbnailUrl!,
                  width: node.width,
                  height: node.mediaHeight,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => SeedArtCanvas(
                    width: node.width,
                    height: node.mediaHeight,
                    trackColor: trackColor,
                    seed: seed,
                    mediaType: MediaType.video,
                  ),
                ),
              )
            else
              SeedArtCanvas(
                width: node.width,
                height: node.mediaHeight,
                trackColor: trackColor,
                seed: seed,
                mediaType: MediaType.video,
              ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: opacityOverlay),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            if (post.formattedDuration != null)
              Positioned(
                right: spaceXs,
                bottom: spaceXs,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: spaceXs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(radiusSm),
                  ),
                  child: Text(
                    post.formattedDuration!,
                    style: textMicro.copyWith(color: Colors.white),
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
    final post = (node.item as PostItem).post;
    final hasTitle = post.title != null && post.title!.isNotEmpty;
    final bodyPreview = post.plainTextPreview;
    final hasBody = bodyPreview != null && bodyPreview.isNotEmpty;
    final displayText = hasTitle ? post.title! : (hasBody ? bodyPreview : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: spaceXs),
      child: Stack(
        alignment: Alignment.center,
        children: [
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
              const SizedBox(width: spaceXs),
              Expanded(
                child: CustomPaint(
                  size: Size(double.infinity, node.mediaHeight * 0.5),
                  painter: _WaveBarPainter(
                    color: trackColor.withValues(
                      alpha: displayText != null ? 0.25 : 0.5,
                    ),
                    seed: '${post.title ?? ''}${post.id}',
                  ),
                ),
              ),
              if (post.formattedDuration != null) ...[
                const SizedBox(width: spaceXs),
                Text(
                  post.formattedDuration!,
                  style: TextStyle(
                    color: trackColor.withValues(alpha: 0.7),
                    fontSize: fontSizeXs,
                    fontWeight: weightSemibold,
                  ),
                ),
              ],
            ],
          ),
          if (displayText != null)
            Positioned(
              left: 38,
              right: post.formattedDuration != null ? 36 : 10,
              child: Text(
                displayText,
                style: const TextStyle(
                  color: colorTextPrimary,
                  fontSize: fontSizeXs,
                  fontWeight: weightMedium,
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
    final post = (node.item as PostItem).post;
    final domain = post.mediaUrl != null
        ? Uri.tryParse(post.mediaUrl!)?.host ?? ''
        : '';

    return Container(
      padding: const EdgeInsets.all(spaceSm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [trackColor.withValues(alpha: 0.04), colorSurface1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: fontSizeMd, color: trackColor),
              const SizedBox(width: spaceXs),
              _TrackLabel(trackName: post.trackName, color: trackColor),
            ],
          ),
          const SizedBox(height: spaceXs),
          if (post.title != null)
            Text(
              post.title!,
              style: const TextStyle(
                color: colorTextPrimary,
                fontSize: fontSizeSm,
                fontWeight: weightSemibold,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (post.plainTextPreview != null &&
              post.plainTextPreview!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              post.plainTextPreview!,
              style: TextStyle(
                color: colorTextPrimary.withValues(alpha: 0.6),
                fontSize: fontSizeXs,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (domain.isNotEmpty) ...[
            const SizedBox(height: spaceXxs),
            Text(
              domain,
              style: TextStyle(
                color: trackColor.withValues(alpha: 0.6),
                fontSize: fontSizeXs,
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
        fontSize: fontSizeXs,
        fontWeight: weightSemibold,
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
      padding: const EdgeInsets.symmetric(
        horizontal: spaceXs,
        vertical: spaceXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrackLabel(trackName: post.trackName, color: trackColor),
          if (post.title != null)
            Text(
              post.title!,
              style: const TextStyle(
                color: colorTextPrimary,
                fontSize: fontSizeSm,
                fontWeight: weightMedium,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else if (post.plainTextPreview != null &&
              post.plainTextPreview!.isNotEmpty)
            Text(
              post.plainTextPreview!,
              style: TextStyle(
                color: colorTextPrimary.withValues(alpha: 0.6),
                fontSize: fontSizeXs,
                height: 1.3,
              ),
              maxLines: 1,
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
    var h = 0;
    for (int i = 0; i < seed.length; i++) {
      h = ((h << 5) - h + seed.codeUnitAt(i)) & 0xFFFFFF;
    }

    final barCount = max(8, (size.width / 4).floor());
    final barWidth = size.width / barCount * 0.6;
    final gap = size.width / barCount;

    final paint = Paint()..color = color.withValues(alpha: opacityOverlay);

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
