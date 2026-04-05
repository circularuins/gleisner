import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/artist.dart';
import '../../models/post.dart' show ReactionCount;
import '../../providers/timeline_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/milestone_category.dart';

const _reactionPresets = ['🔥', '❤️', '👏', '✨', '😍', '🎵', '💪', '🎸'];

/// Show the milestone detail bottom sheet.
/// The sheet watches [timelineProvider] for live reaction state —
/// no local state duplication.
void showMilestoneDetailSheet(
  BuildContext context,
  ArtistMilestone milestone, {
  Future<bool?> Function(String milestoneId, String emoji)? onToggleReaction,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MilestoneDetailSheet(
      milestoneId: milestone.id,
      onToggleReaction: onToggleReaction,
    ),
  );
}

class _MilestoneDetailSheet extends ConsumerWidget {
  final String milestoneId;
  final Future<bool?> Function(String milestoneId, String emoji)?
  onToggleReaction;

  const _MilestoneDetailSheet({
    required this.milestoneId,
    this.onToggleReaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch provider for live updates — single source of truth
    final artist = ref.watch(timelineProvider).artist;
    final milestone = artist?.milestones
        .where((m) => m.id == milestoneId)
        .firstOrNull;

    if (milestone == null) {
      return const SizedBox.shrink();
    }

    final reactionCounts = milestone.reactionCounts;
    final myReactions = milestone.myReactions.toSet();

    final categoryLabel = milestoneCategories
        .firstWhere(
          (c) => c.$1 == milestone.category,
          orElse: () => ('other', 'Other', Icons.star_outline),
        )
        .$2;
    final categoryIcon = milestoneCategoryIcon(milestone.category);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: colorSurface1,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: spaceSm),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorInteractiveMuted,
                  borderRadius: BorderRadius.circular(radiusFull),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(spaceLg),
                children: [
                  // Category chip
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: spaceSm,
                          vertical: spaceXs,
                        ),
                        decoration: BoxDecoration(
                          color: colorAccentGold.withValues(
                            alpha: opacitySubtle,
                          ),
                          borderRadius: BorderRadius.circular(radiusFull),
                          border: Border.all(
                            color: colorAccentGold.withValues(
                              alpha: opacityBorder,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              categoryIcon,
                              color: colorAccentGold,
                              size: fontSizeMd,
                            ),
                            const SizedBox(width: spaceXs),
                            Text(
                              categoryLabel,
                              style: const TextStyle(
                                color: colorAccentGold,
                                fontSize: fontSizeSm,
                                fontWeight: weightMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Milestone',
                        style: TextStyle(
                          color: colorTextMuted,
                          fontSize: fontSizeSm,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: spaceMd),
                  // Title
                  Text(
                    milestone.title,
                    style: const TextStyle(
                      color: colorTextPrimary,
                      fontSize: fontSizeTitle,
                      fontWeight: weightBold,
                    ),
                  ),
                  const SizedBox(height: spaceSm),
                  // Date
                  Text(
                    _formatDate(milestone.date),
                    style: const TextStyle(
                      color: colorTextMuted,
                      fontSize: fontSizeMd,
                    ),
                  ),
                  // Description
                  if (milestone.description != null &&
                      milestone.description!.isNotEmpty) ...[
                    const SizedBox(height: spaceLg),
                    Text(
                      milestone.description!,
                      style: const TextStyle(
                        color: colorTextSecondary,
                        fontSize: fontSizeMd,
                        height: 1.5,
                      ),
                    ),
                  ],
                  // Reactions section
                  if (onToggleReaction != null) ...[
                    const SizedBox(height: spaceXl),
                    const Divider(color: colorBorder, height: 1),
                    const SizedBox(height: spaceLg),
                    // Existing reactions
                    if (reactionCounts.isNotEmpty) ...[
                      Wrap(
                        spacing: spaceSm,
                        runSpacing: spaceSm,
                        children: reactionCounts.map((r) {
                          final isOwn = myReactions.contains(r.emoji);
                          return GestureDetector(
                            onTap: () =>
                                onToggleReaction!(milestoneId, r.emoji),
                            child: _ReactionPill(
                              emoji: r.emoji,
                              count: r.count,
                              isOwn: isOwn,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: spaceMd),
                    ],
                    // Preset reaction buttons
                    Wrap(
                      spacing: spaceSm,
                      runSpacing: spaceSm,
                      children: _reactionPresets.map((emoji) {
                        final isOwn = myReactions.contains(emoji);
                        return GestureDetector(
                          onTap: () => onToggleReaction!(milestoneId, emoji),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isOwn
                                  ? colorAccentGold.withValues(
                                      alpha: opacitySubtle,
                                    )
                                  : colorSurface2,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isOwn
                                    ? colorAccentGold.withValues(
                                        alpha: opacityBorder,
                                      )
                                    : colorBorder,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: fontSizeLg),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _ReactionPill extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isOwn;

  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: spaceSm,
        vertical: spaceXs,
      ),
      decoration: BoxDecoration(
        color: isOwn
            ? colorAccentGold.withValues(alpha: opacitySubtle)
            : colorSurface2,
        borderRadius: BorderRadius.circular(radiusFull),
        border: Border.all(
          color: isOwn
              ? colorAccentGold.withValues(alpha: opacityBorder)
              : colorBorder,
        ),
      ),
      child: Text(
        '$emoji $count',
        style: const TextStyle(fontSize: fontSizeSm, color: colorTextSecondary),
      ),
    );
  }
}
