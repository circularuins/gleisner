import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/artist.dart';
import '../../models/post.dart' show ReactionCount;
import '../../theme/gleisner_tokens.dart';
import '../../utils/constellation_layout.dart';
import '../../utils/milestone_category.dart';
import 'milestone_detail_sheet.dart';

/// A diamond-shaped node card for artist milestones on the timeline.
/// Layout: [title text] [diamond icon] — right-aligned on the timeline.
class MilestoneNodeCard extends StatefulWidget {
  final PlacedNode node;
  final ArtistMilestone milestone;
  final VoidCallback? onTap;
  final Future<bool?> Function(String milestoneId, String emoji)?
  onToggleReaction;

  const MilestoneNodeCard({
    super.key,
    required this.node,
    required this.milestone,
    this.onTap,
    this.onToggleReaction,
  });

  @override
  State<MilestoneNodeCard> createState() => _MilestoneNodeCardState();
}

class _MilestoneNodeCardState extends State<MilestoneNodeCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestone;
    final diamondSize = widget.node.nodeSize;

    return GestureDetector(
      onTap:
          widget.onTap ??
          () => showMilestoneDetailSheet(
            context,
            milestone,
            onToggleReaction: widget.onToggleReaction,
          ),
      child: SizedBox(
        height: diamondSize,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left margin for diamond rotation overflow
            SizedBox(width: diamondSize * 0.1),
            // Diamond icon
            AnimatedBuilder(
              animation: _glowAnimation ?? const AlwaysStoppedAnimation(0),
              builder: (context, child) {
                final glowPulse = _glowAnimation?.value ?? 0.0;
                final glowOpacity = 0.2 + glowPulse * 0.15;
                return Transform.rotate(
                  angle: pi / 4,
                  child: Container(
                    width: diamondSize * 0.5,
                    height: diamondSize * 0.5,
                    decoration: BoxDecoration(
                      color: colorSurface1,
                      border: Border.all(
                        color: colorAccentGold.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(radiusSm),
                      boxShadow: [
                        BoxShadow(
                          color: colorAccentGold.withValues(alpha: glowOpacity),
                          blurRadius: 12 + glowPulse * 6,
                          spreadRadius: 2 + glowPulse * 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: -pi / 4,
                        child: Icon(
                          milestoneCategoryIcon(milestone.category),
                          color: colorAccentGold,
                          size: diamondSize * 0.24,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Title label
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(left: spaceSm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: const TextStyle(
                        color: colorAccentGold,
                        fontSize: fontSizeMd,
                        fontWeight: weightMedium,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                    ),
                    if (milestone.reactionCounts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: spaceXxs),
                        child: _ReactionBadge(counts: milestone.reactionCounts),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  final List<ReactionCount> counts;
  const _ReactionBadge({required this.counts});

  @override
  Widget build(BuildContext context) {
    final total = counts.fold(0, (sum, r) => sum + r.count);
    final topEmojis = counts.take(3).map((r) => r.emoji).join();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: spaceXs, vertical: 1),
      decoration: BoxDecoration(
        color: colorSurface2,
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(
          color: colorAccentGold.withValues(alpha: opacityBorder),
          width: 0.5,
        ),
      ),
      child: Text(
        '$topEmojis $total',
        style: const TextStyle(fontSize: fontSizeXs, color: colorTextMuted),
      ),
    );
  }
}
