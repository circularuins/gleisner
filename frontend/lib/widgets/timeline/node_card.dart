import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../models/timeline_item.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/constellation_layout.dart';
import '../../utils/reading_time.dart';
import 'post_detail_sheet.dart';
import 'seed_art_painter.dart';

/// Presentation-only flag: an image post that should render as a scattered
/// polaroid pile instead of a single full-bleed thumbnail.
extension _PostPilePresentation on Post {
  bool get isPhotoPile => mediaType == MediaType.image && imageUrls.length > 1;
}

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

    // Multi-image image posts render as a free-floating photo pile — no
    // surrounding frame, fill, or hard clip so individual photos can extend
    // past the rectangular node bounds for a casual "tossed photos" feel.
    final isPhotoPile = post.isPhotoPile;

    Widget card = GestureDetector(
      onTap: widget.onTap ?? () => showPostDetailSheet(context, post),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          // Photo piles supply their own track-color glow per tile so the
          // halo follows the scattered shape; non-pile nodes keep the
          // rectangular importance glow.
          boxShadow: isPhotoPile
              ? const []
              : [
                  BoxShadow(
                    color: trackColor.withValues(alpha: glowOpacity),
                    blurRadius: glowBlur,
                    spreadRadius: glowSpread,
                  ),
                ],
          border: isPhotoPile
              ? null
              : Border.all(
                  color: trackColor.withValues(alpha: opacityBorder),
                  width: 1,
                ),
          color: isPhotoPile ? Colors.transparent : colorSurface1,
        ),
        clipBehavior: isPhotoPile ? Clip.none : Clip.antiAlias,
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

    final pad = isLarge ? spaceMd : spaceSm;

    return Container(
      padding: EdgeInsets.all(pad),
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
    final urls = post.imageUrls;
    final hasImage = urls.isNotEmpty;
    final imageCount = urls.length;
    final showInfo = node.showInfo;
    final totalH = node.mediaHeight + (showInfo ? 30 : 0);
    final hasTitle = post.title != null && post.title!.isNotEmpty;

    final isPhotoPile = post.isPhotoPile;

    // The image fills the entire node — text overlays on top.
    // For photo piles, allow tiles to extend slightly past the node bounds.
    return SizedBox(
      width: node.width,
      height: totalH,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: isPhotoPile ? Clip.none : Clip.hardEdge,
        children: [
          // Background: scattered photo pile (multi) / single image / seed art
          if (isPhotoPile)
            _ScatteredPhotos(
              urls: urls,
              width: node.width,
              height: totalH,
              seed: post.id,
              trackColor: trackColor,
              fallbackSeed: seed,
              importance: post.importance,
            )
          else if (hasImage)
            Image.network(
              urls.first,
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

          // Multi-image count badge
          if (imageCount > 1)
            Positioned(
              top: spaceXs,
              right: spaceXs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: spaceXs,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library,
                      size: 10,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$imageCount',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: fontSizeXs,
                        fontWeight: weightSemibold,
                      ),
                    ),
                  ],
                ),
              ),
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

/// Multiple images stacked like a casually dropped photo pile.
/// Up to [_maxLayers] photos are rendered back-to-front with deterministic
/// rotation and offset derived from [seed], so layout is stable across rebuilds.
/// urls[0] is the top photo (least rotated, near-centered).
///
/// Stateful so the per-tile scatter (angle/offset) is computed once on
/// init/didUpdate rather than on every parent rebuild — the timeline can
/// rebuild this widget on every constellation pan/zoom frame.
class _ScatteredPhotos extends StatefulWidget {
  final List<String> urls;
  final double width;
  final double height;
  final String seed;
  final Color trackColor;
  final String fallbackSeed;
  final double importance;

  const _ScatteredPhotos({
    required this.urls,
    required this.width,
    required this.height,
    required this.seed,
    required this.trackColor,
    required this.fallbackSeed,
    required this.importance,
  });

  /// Cap visible layers — beyond this, the pile reads as "many" anyway and
  /// rendering extra Image.network widgets just costs memory.
  static const int _maxLayers = 4;

  @override
  State<_ScatteredPhotos> createState() => _ScatteredPhotosState();
}

class _ScatteredPhotosState extends State<_ScatteredPhotos> {
  /// Photo tile size as a fraction of the node's width/height. Smaller than
  /// the node so each tile reads as a discrete photograph and the scatter
  /// has room to extend past the node bounds.
  static const double _tileScale = 0.82;

  late List<_TileLayout> _layouts;
  late double _photoW;
  late double _photoH;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(_ScatteredPhotos old) {
    super.didUpdateWidget(old);
    if (old.seed != widget.seed ||
        old.width != widget.width ||
        old.height != widget.height ||
        !listEquals(old.urls, widget.urls)) {
      _recompute();
    }
  }

  void _recompute() {
    final visible = widget.urls.take(_ScatteredPhotos._maxLayers).toList();
    final count = visible.length;
    _photoW = widget.width * _tileScale;
    _photoH = widget.height * _tileScale;

    final layouts = <_TileLayout>[];
    // i=0 → front (urls[0], on top). i=count-1 → back. Add back first so
    // Stack paint order places urls[0] last (= on top).
    for (int i = count - 1; i >= 0; i--) {
      final depth = count > 1 ? i / (count - 1) : 0.0;
      final r = Random('${widget.seed}#$i'.hashCode);

      // Rotation grows with depth: ~±2.5° front, ~±10° back.
      final angleSign = r.nextBool() ? 1.0 : -1.0;
      final angle =
          angleSign * (0.04 + depth * 0.14) * (0.7 + r.nextDouble() * 0.3);

      // Offset grows with depth: front near center, back scattered far enough
      // to extend past the node bounds.
      final dxSign = r.nextBool() ? 1.0 : -1.0;
      final dySign = r.nextBool() ? 1.0 : -1.0;
      final dx =
          dxSign *
          (widget.width * 0.03 + widget.width * 0.13 * depth) *
          (0.65 + r.nextDouble() * 0.35);
      final dy =
          dySign *
          (widget.height * 0.025 + widget.height * 0.10 * depth) *
          (0.65 + r.nextDouble() * 0.35);

      layouts.add(
        _TileLayout(
          url: visible[i],
          angle: angle,
          dx: dx,
          dy: dy,
          depth: depth,
        ),
      );
    }
    _layouts = layouts;
  }

  @override
  Widget build(BuildContext context) {
    // cacheWidth/cacheHeight are derived from the runtime device pixel ratio
    // (rather than a fixed 2x) so Retina-class displays get sharp tiles and
    // DPR=1 displays don't pay for over-decoded buffers. They live in build()
    // rather than _recompute() because DPR can change without seed/url/size
    // changes (e.g., window dragged between monitors).
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (_photoW * dpr).ceil();
    final cacheH = (_photoH * dpr).ceil();

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        for (final layout in _layouts)
          Center(
            child: Transform.translate(
              offset: Offset(layout.dx, layout.dy),
              child: Transform.rotate(
                angle: layout.angle,
                child: _PhotoTile(
                  url: layout.url,
                  width: _photoW,
                  height: _photoH,
                  cacheWidth: cacheW,
                  cacheHeight: cacheH,
                  isFront: layout.depth == 0.0,
                  depth: layout.depth,
                  importance: widget.importance,
                  trackColor: widget.trackColor,
                  fallbackSeed: widget.fallbackSeed,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cached transform + identity for a single tile in [_ScatteredPhotos].
class _TileLayout {
  final String url;
  final double angle;
  final double dx;
  final double dy;

  /// 0.0 = front (on top), 1.0 = back.
  final double depth;

  const _TileLayout({
    required this.url,
    required this.angle,
    required this.dx,
    required this.dy,
    required this.depth,
  });
}

/// A single tile in [_ScatteredPhotos]. Renders as a polaroid-style frame:
/// off-white paper border around the image, with both a black drop shadow
/// (depth) and a track-colored halo (importance signal). The halo replaces
/// the rectangular boxShadow that normally lives on the parent NodeCard so
/// the importance glow follows the scattered pile rather than the node rect.
/// Each tile has per-photo aging — varied paper yellowing, a sepia tint, and
/// a faint crease + vignette via [_PaperWearPainter].
class _PhotoTile extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final int cacheWidth;
  final int cacheHeight;
  final bool isFront;
  final double depth; // 0.0 = front, 1.0 = back
  final double importance;
  final Color trackColor;
  final String fallbackSeed;

  const _PhotoTile({
    required this.url,
    required this.width,
    required this.height,
    required this.cacheWidth,
    required this.cacheHeight,
    required this.isFront,
    required this.depth,
    required this.importance,
    required this.trackColor,
    required this.fallbackSeed,
  });

  @override
  Widget build(BuildContext context) {
    // Polaroid paper border thickness — scales with photo size, min 4 px.
    final borderThickness = max(4.0, width * 0.045);

    // Per-photo aging factor from a stable hash of the URL. Some tiles look
    // fresh, others heavily yellowed.
    final agingT = ((url.hashCode & 0xFF) / 255.0);
    final paperColor = Color.lerp(colorPaperWhite, colorPaperAged, agingT)!;
    final tintAlpha = 0.04 + agingT * 0.10;

    // Track-color halo: brightest on the front tile, fades with depth so the
    // collective halo concentrates near the top of the pile.
    final glowStrength = 1.0 - depth * 0.6;
    final glowSpread = (3.0 + importance * 12.0) * glowStrength;
    final glowBlur = (10.0 + importance * 18.0) * glowStrength;
    final glowAlpha = (0.20 + importance * 0.30) * glowStrength;

    // Black depth shadow: front tile floats higher off the canvas.
    final dropBlur = isFront ? 18.0 : 10.0;
    final dropAlpha = isFront ? 0.55 : 0.4;
    final dropDy = isFront ? 4.0 : 2.0;

    // RepaintBoundary cuts the repaint chain so timeline-wide rebuilds (pan,
    // hover, neighbor reactions) don't traverse Transform.translate +
    // Transform.rotate + the wear painter on every frame.
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        padding: EdgeInsets.all(borderThickness),
        decoration: BoxDecoration(
          color: paperColor,
          borderRadius: BorderRadius.circular(radiusSm),
          boxShadow: [
            // Track-color halo behind the tile.
            BoxShadow(
              color: trackColor.withValues(alpha: glowAlpha),
              blurRadius: glowBlur,
              spreadRadius: glowSpread,
            ),
            // Black drop shadow for elevation.
            BoxShadow(
              color: Colors.black.withValues(alpha: dropAlpha),
              blurRadius: dropBlur,
              offset: Offset(0, dropDy),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // BoxFit.contain preserves the source aspect ratio so the photo
            // is shown whole — any unused tile area becomes additional paper
            // border, the same way a real polaroid frames an off-aspect print.
            // The downstream sepia / wear overlays still cover the full tile,
            // which reads as "the paper is aged too", not as misalignment.
            Image.network(
              url,
              fit: BoxFit.contain,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: colorSurface2);
              },
              errorBuilder: (_, _, _) => SeedArtCanvas(
                width: width - borderThickness * 2,
                height: height - borderThickness * 2,
                trackColor: trackColor,
                seed: fallbackSeed,
                mediaType: MediaType.image,
              ),
            ),
            // Sepia / dustiness wash over the image — alpha varies per tile.
            IgnorePointer(
              child: Container(
                color: colorPaperAgingTint.withValues(alpha: tintAlpha),
              ),
            ),
            // Faint crease + vignette baked from a per-tile seed.
            IgnorePointer(
              child: CustomPaint(painter: _PaperWearPainter(seed: url)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle wear overlay for [_PhotoTile]: 1–2 faint crease lines and a soft
/// vignette at the corners. Stable per [seed] so the wear is the same across
/// rebuilds for a given photo.
///
/// ⚠ When adding fields here, also extend the constructor and
/// [shouldRepaint] to compare them — otherwise tiles may render with stale
/// wear after a rebuild. See `frontend-implementation.md` —
/// "CustomPainter フィールド追加チェックリスト".
class _PaperWearPainter extends CustomPainter {
  final String seed;

  const _PaperWearPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed.hashCode);
    final rect = Offset.zero & size;

    // Vignette — soft darkening towards the corners.
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.85,
        colors: const [Color(0x00000000), Color(0x26000000)],
        stops: const [0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);

    // Primary crease: long thin highlight at a random angle.
    final p1 = Offset(
      r.nextDouble() * size.width,
      r.nextDouble() * size.height,
    );
    final angle = r.nextDouble() * 2 * pi;
    final len =
        (size.width + size.height) * 0.4 + r.nextDouble() * size.width * 0.3;
    final p2 = Offset(p1.dx + cos(angle) * len, p1.dy + sin(angle) * len);
    final creasePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 0.7 + r.nextDouble() * 0.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, creasePaint);

    // Occasional shorter dark companion crease for a real fold feel.
    if (r.nextDouble() > 0.5) {
      final p3 = Offset(
        r.nextDouble() * size.width,
        r.nextDouble() * size.height,
      );
      final angle2 = angle + pi / 2 + (r.nextDouble() * 0.5 - 0.25);
      final len2 = size.width * 0.35 + r.nextDouble() * size.width * 0.2;
      final p4 = Offset(p3.dx + cos(angle2) * len2, p3.dy + sin(angle2) * len2);
      final paint2 = Paint()
        ..color = Colors.black.withValues(alpha: 0.07)
        ..strokeWidth = 0.5 + r.nextDouble() * 0.3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p3, p4, paint2);
    }
  }

  @override
  bool shouldRepaint(_PaperWearPainter old) => old.seed != seed;
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
            displayTitle,
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
