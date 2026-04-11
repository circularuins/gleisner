import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../models/timeline_item.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/constellation_layout.dart';
import '../../utils/reading_time.dart';
import 'post_detail_sheet.dart';
import 'seed_art_painter.dart';

/// Border radius by media type.
BorderRadius _borderForType(MediaType type) {
  return switch (type) {
    MediaType.thought => BorderRadius.circular(radiusXl),
    MediaType.article => BorderRadius.circular(radiusMd),
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
      MediaType.thought => _ThoughtContent(node: node, trackColor: trackColor),
      MediaType.article => _TextContent(node: node, trackColor: trackColor),
      MediaType.image => _ImageContent(node: node, trackColor: trackColor),
      MediaType.video => _VideoContent(node: node, trackColor: trackColor),
      MediaType.audio => _AudioContent(node: node, trackColor: trackColor),
      MediaType.link => _LinkContent(node: node, trackColor: trackColor),
    };
  }
}

// --- Thought: bubble with body text, no title ---
class _ThoughtContent extends StatelessWidget {
  final PlacedNode node;
  final Color trackColor;

  const _ThoughtContent({required this.node, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final post = (node.item as PostItem).post;
    final preview = post.plainTextPreview ?? '';
    final isLarge = node.nodeSize > 110;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Bubble body
        Container(
          padding: EdgeInsets.all(isLarge ? spaceMd : spaceSm),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                trackColor.withValues(alpha: 0.06),
                trackColor.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(radiusXl),
            border: Border.all(
              color: trackColor.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Center(
            child: Text(
              preview,
              style: TextStyle(
                color: colorTextPrimary.withValues(alpha: 0.85),
                fontSize: isLarge ? fontSizeSm : fontSizeXs,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
              maxLines: isLarge ? 5 : 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Bubble tail (small circles below bottom-left)
        Positioned(
          bottom: -6,
          left: isLarge ? spaceMd : spaceSm,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: trackColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: trackColor.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -12,
          left: isLarge ? spaceSm : spaceXs,
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: trackColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
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
          Expanded(
            child: Center(
              child: Text(
                preview,
                style: TextStyle(
                  color: colorTextPrimary,
                  fontSize: totalH > 120 ? fontSizeLg : fontSizeMd,
                  height: 1.5,
                  fontWeight: weightMedium,
                ),
                maxLines: ((totalH - 30) / 24).floor().clamp(2, 5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Long form: title-driven card with body preview and reading accent.
  Widget _buildLongForm(Post post, String preview, double totalH) {
    final bodyMaxLines = ((totalH - 50) / 14).floor().clamp(1, 8);
    final readMin = estimateReadingMinutes(preview);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: trackColor.withValues(alpha: 0.5), width: 3),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(spaceMd, spaceSm, spaceSm, spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Track + reading time row
          Row(
            children: [
              Flexible(
                child: _TrackLabel(
                  trackName: post.trackName,
                  color: trackColor,
                ),
              ),
              if (readMin > 0) ...[
                const SizedBox(width: spaceXs),
                Text(
                  '$readMin min',
                  style: TextStyle(
                    color: colorTextMuted.withValues(alpha: 0.5),
                    fontSize: 9,
                  ),
                ),
              ],
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
    final showInfo = node.showInfo;
    final totalH = node.mediaHeight + (showInfo ? 30 : 0);
    final hasTitle = post.title != null && post.title!.isNotEmpty;

    // The image fills the entire node — text overlays on top
    return SizedBox(
      width: node.width,
      height: totalH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: image or seed art
          if (hasImage)
            Image.network(
              post.mediaUrl!,
              width: node.width,
              height: totalH,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: colorSurface2);
              },
              errorBuilder: (_, _, _) => SeedArtCanvas(
                width: node.width,
                height: totalH,
                trackColor: trackColor,
                seed: seed,
                mediaType: MediaType.image,
              ),
            )
          else
            SeedArtCanvas(
              width: node.width,
              height: totalH,
              trackColor: trackColor,
              seed: seed,
              mediaType: MediaType.image,
            ),

          // Bottom gradient for text legibility
          if (showInfo && (hasTitle || post.trackName != null))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: totalH * 0.5,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xAA000000)],
                  ),
                ),
              ),
            ),

          // Overlay text: track label + title at bottom
          if (showInfo)
            Positioned(
              left: spaceSm,
              right: spaceSm,
              bottom: spaceSm,
              child: _OverlayInfo(post: post, trackColor: trackColor),
            ),
        ],
      ),
    );
  }
}

// --- Video: thumbnail fills node, play button + duration + overlay info ---
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
    final showInfo = node.showInfo;
    final totalH = node.mediaHeight + (showInfo ? 30 : 0);
    final hasTitle = post.title != null && post.title!.isNotEmpty;

    return SizedBox(
      width: node.width,
      height: totalH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail or seed art
          if (hasThumbnail)
            Image.network(
              post.thumbnailUrl!,
              width: node.width,
              height: totalH,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: colorSurface2);
              },
              errorBuilder: (_, _, _) => SeedArtCanvas(
                width: node.width,
                height: totalH,
                trackColor: trackColor,
                seed: seed,
                mediaType: MediaType.video,
              ),
            )
          else
            SeedArtCanvas(
              width: node.width,
              height: totalH,
              trackColor: trackColor,
              seed: seed,
              mediaType: MediaType.video,
            ),

          // Play button — center
          Center(
            child: Container(
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
          ),

          // Bottom gradient for overlay text
          if (showInfo && (hasTitle || post.trackName != null))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: totalH * 0.5,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xAA000000)],
                  ),
                ),
              ),
            ),

          // Duration badge — top-right
          if (post.formattedDuration != null)
            Positioned(
              right: spaceXs,
              top: spaceXs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: spaceXs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(radiusSm),
                ),
                child: Text(
                  post.formattedDuration!,
                  style: textMicro.copyWith(color: Colors.white),
                ),
              ),
            ),

          // Overlay text: track label + title at bottom
          if (showInfo)
            Positioned(
              left: spaceSm,
              right: spaceSm,
              bottom: spaceSm,
              child: _OverlayInfo(post: post, trackColor: trackColor),
            ),
        ],
      ),
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

// --- Link: OGP thumbnail or icon + domain ---
class _LinkContent extends StatelessWidget {
  final PlacedNode node;
  final Color trackColor;
  const _LinkContent({required this.node, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    final post = (node.item as PostItem).post;
    final hasOgImage = post.ogImage != null && post.ogImage!.isNotEmpty;
    final domain = post.mediaUrl != null
        ? Uri.tryParse(post.mediaUrl!)?.host ?? ''
        : '';
    final displayTitle = post.title ?? post.ogTitle;
    final showInfo = node.showInfo;
    final totalH = node.mediaHeight + (showInfo ? 30 : 0);

    // OGP image available: full-bleed thumbnail (like image nodes)
    if (hasOgImage) {
      return SizedBox(
        width: node.width,
        height: totalH,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              post.ogImage!,
              width: node.width,
              height: totalH,
              fit: BoxFit.cover,
              cacheWidth: (node.width * 2).toInt(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: colorSurface2);
              },
              errorBuilder: (_, _, _) => Container(color: colorSurface2),
            ),
            // Bottom gradient
            if (showInfo)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: totalH * 0.5,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xAA000000)],
                    ),
                  ),
                ),
              ),
            // Link icon badge
            Positioned(
              top: spaceXs,
              left: spaceXs,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(radiusSm),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  size: 12,
                  color: Colors.white70,
                ),
              ),
            ),
            // Overlay info
            if (showInfo)
              Positioned(
                left: spaceSm,
                right: spaceSm,
                bottom: spaceSm,
                child: _OverlayInfo(post: post, trackColor: trackColor),
              ),
          ],
        ),
      );
    }

    // No OGP image: text-based card
    return _LinkFallback(post: post, trackColor: trackColor, domain: domain);
  }
}

class _LinkFallback extends StatelessWidget {
  final Post post;
  final Color trackColor;
  final String domain;
  const _LinkFallback({
    required this.post,
    required this.trackColor,
    required this.domain,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = post.title ?? post.ogTitle;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: trackColor.withValues(alpha: 0.5), width: 3),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [trackColor.withValues(alpha: 0.08), colorSurface1],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(spaceSm, spaceSm, spaceSm, spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Domain row
          if (domain.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 10,
                  color: trackColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: spaceXs),
                Flexible(
                  child: Text(
                    domain,
                    style: TextStyle(
                      color: trackColor.withValues(alpha: 0.5),
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: spaceXs),
          ],
          if (displayTitle != null)
            Text(
              displayTitle,
              style: const TextStyle(
                color: colorTextPrimary,
                fontSize: fontSizeMd,
                fontWeight: weightSemibold,
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

/// Shared overlay for image/video nodes: track label + title on gradient.
class _OverlayInfo extends StatelessWidget {
  final Post post;
  final Color trackColor;
  const _OverlayInfo({required this.post, required this.trackColor});

  @override
  Widget build(BuildContext context) {
    // For link posts, prefer ogTitle over post.title
    final displayTitle = post.mediaType == MediaType.link
        ? (post.title ?? post.ogTitle)
        : post.title;
    final hasTitle = displayTitle != null && displayTitle.isNotEmpty;
    final isLink = post.mediaType == MediaType.link;
    final domain = isLink && post.mediaUrl != null
        ? Uri.tryParse(post.mediaUrl!)?.host
        : null;
    // For links: show domain instead of track name (track color already visible via glow)
    final label = isLink ? domain : post.trackName?.toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLink)
                Padding(
                  padding: const EdgeInsets.only(right: spaceXxs),
                  child: Icon(
                    Icons.link_rounded,
                    size: 9,
                    color: trackColor.withValues(alpha: 0.8),
                  ),
                ),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: trackColor.withValues(alpha: 0.9),
                    fontSize: 9,
                    fontWeight: weightSemibold,
                    letterSpacing: isLink ? 0 : 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (hasTitle) ...[
          const SizedBox(height: 1),
          Text(
            displayTitle!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: fontSizeSm,
              fontWeight: weightMedium,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
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
