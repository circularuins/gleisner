import 'package:flutter/material.dart';

import '../../utils/constellation_layout.dart';
import 'post_detail_sheet.dart';
import 'seed_art_painter.dart';

/// Border radius variations based on node index.
const _borderRadii = [
  BorderRadius.all(Radius.circular(16)),
  BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(8),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(20),
  ),
  BorderRadius.all(Radius.circular(12)),
  BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(20),
    bottomLeft: Radius.circular(20),
    bottomRight: Radius.circular(8),
  ),
];

/// A single node in the constellation layout.
class NodeCard extends StatefulWidget {
  final PlacedNode node;
  final int index;
  final bool highlight;

  const NodeCard({
    super.key,
    required this.node,
    required this.index,
    this.highlight = false,
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
    _controller!.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final trackColor = node.post.trackDisplayColor;
    final importance = node.post.importance;
    final borderRadius = _borderRadii[widget.index % _borderRadii.length];

    final glowSpread = 4.0 + importance * 12;
    final glowBlur = 8.0 + importance * 16;
    final glowOpacity = 0.15 + importance * 0.25;

    final seedString =
        '${node.post.title ?? ''}${node.post.createdAt.toIso8601String()}';

    Widget card = GestureDetector(
      onTap: () => showPostDetailSheet(context, node.post),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SeedArtCanvas(
              width: node.width,
              height: node.mediaHeight,
              trackColor: trackColor,
              seed: seedString,
            ),
            if (node.showInfo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (node.post.trackName ?? '').toUpperCase(),
                      style: TextStyle(
                        color: trackColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (node.post.title != null)
                      Text(
                        node.post.title!,
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
              ),
          ],
        ),
      ),
    );

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
}
