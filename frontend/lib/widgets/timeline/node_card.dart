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
class NodeCard extends StatelessWidget {
  final PlacedNode node;
  final int index;

  const NodeCard({super.key, required this.node, required this.index});

  @override
  Widget build(BuildContext context) {
    final trackColor = node.post.trackDisplayColor;
    final importance = node.post.importance;
    final borderRadius = _borderRadii[index % _borderRadii.length];

    // Glow intensity based on importance
    final glowSpread = 4.0 + importance * 12;
    final glowBlur = 8.0 + importance * 16;
    final glowOpacity = 0.15 + importance * 0.25;

    final seedString =
        '${node.post.title ?? ''}${node.post.createdAt.toIso8601String()}';

    return GestureDetector(
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
  }
}
