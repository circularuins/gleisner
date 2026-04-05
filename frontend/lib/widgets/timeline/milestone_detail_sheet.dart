import 'package:flutter/material.dart';

import '../../models/artist.dart';
import '../../models/post.dart' show ReactionCount;
import '../../theme/gleisner_tokens.dart';
import '../../utils/milestone_category.dart';

const _reactionPresets = ['🔥', '❤️', '👏', '✨', '😍', '🎵', '💪', '🎸'];

/// Show the milestone detail bottom sheet.
void showMilestoneDetailSheet(
  BuildContext context,
  ArtistMilestone milestone, {
  Future<bool> Function(String milestoneId, String emoji)? onToggleReaction,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MilestoneDetailSheet(
      milestone: milestone,
      onToggleReaction: onToggleReaction,
    ),
  );
}

class _MilestoneDetailSheet extends StatefulWidget {
  final ArtistMilestone milestone;
  final Future<bool> Function(String milestoneId, String emoji)?
  onToggleReaction;

  const _MilestoneDetailSheet({required this.milestone, this.onToggleReaction});

  @override
  State<_MilestoneDetailSheet> createState() => _MilestoneDetailSheetState();
}

class _MilestoneDetailSheetState extends State<_MilestoneDetailSheet> {
  late List<ReactionCount> _reactionCounts;
  late Set<String> _myReactions;

  @override
  void initState() {
    super.initState();
    _reactionCounts = List.from(widget.milestone.reactionCounts);
    _myReactions = Set.from(widget.milestone.myReactions);
  }

  Future<void> _toggleReaction(String emoji) async {
    final milestoneId = widget.milestone.id;
    final success =
        await widget.onToggleReaction?.call(milestoneId, emoji) ?? false;
    if (!success) return;

    // Determine add/remove based on current local state
    final wasAdded = !_myReactions.contains(emoji);

    setState(() {
      final counts = List<ReactionCount>.from(_reactionCounts);
      if (wasAdded) {
        _myReactions.add(emoji);
        final idx = counts.indexWhere((c) => c.emoji == emoji);
        if (idx >= 0) {
          counts[idx] = ReactionCount(
            emoji: emoji,
            count: counts[idx].count + 1,
          );
        } else {
          counts.add(ReactionCount(emoji: emoji, count: 1));
        }
      } else {
        _myReactions.remove(emoji);
        final idx = counts.indexWhere((c) => c.emoji == emoji);
        if (idx >= 0) {
          final n = counts[idx].count - 1;
          if (n <= 0) {
            counts.removeAt(idx);
          } else {
            counts[idx] = ReactionCount(emoji: emoji, count: n);
          }
        }
      }
      counts.sort((a, b) => b.count.compareTo(a.count));
      _reactionCounts = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestone;
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
                      // Milestone indicator
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
                  if (widget.onToggleReaction != null) ...[
                    const SizedBox(height: spaceXl),
                    const Divider(color: colorBorder, height: 1),
                    const SizedBox(height: spaceLg),
                    // Existing reactions
                    if (_reactionCounts.isNotEmpty) ...[
                      Wrap(
                        spacing: spaceSm,
                        runSpacing: spaceSm,
                        children: _reactionCounts.map((r) {
                          final isOwn = _myReactions.contains(r.emoji);
                          return GestureDetector(
                            onTap: () => _toggleReaction(r.emoji),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: spaceSm,
                                vertical: spaceXs,
                              ),
                              decoration: BoxDecoration(
                                color: isOwn
                                    ? colorAccentGold.withValues(
                                        alpha: opacitySubtle,
                                      )
                                    : colorSurface2,
                                borderRadius: BorderRadius.circular(radiusFull),
                                border: Border.all(
                                  color: isOwn
                                      ? colorAccentGold.withValues(
                                          alpha: opacityBorder,
                                        )
                                      : colorBorder,
                                ),
                              ),
                              child: Text(
                                '${r.emoji} ${r.count}',
                                style: const TextStyle(
                                  fontSize: fontSizeSm,
                                  color: colorTextSecondary,
                                ),
                              ),
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
                        final isOwn = _myReactions.contains(emoji);
                        return GestureDetector(
                          onTap: () => _toggleReaction(emoji),
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

  String _formatDate(String dateStr) {
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
