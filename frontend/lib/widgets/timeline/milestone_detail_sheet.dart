import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/artist.dart';
import '../../providers/timeline_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/milestone_category.dart';
import '../../utils/month_names.dart';

const _reactionPresets = ['🔥', '❤️', '👏', '✨', '😍', '🎵', '💪', '🎸'];

/// Show the milestone detail bottom sheet.
///
/// Pass the milestone object directly so the sheet has a usable source of
/// truth even on the public timeline (`/@username`), where the data lives in
/// `publicTimelineProvider` rather than `timelineProvider`. When
/// `onToggleReaction` is non-null (authenticated path), the sheet additionally
/// watches `timelineProvider` for live reaction count / `myReactions` updates
/// after a toggle. Unauthenticated viewers don't toggle, so the snapshot
/// passed in is sufficient and we skip the provider watch entirely.
///
/// Previously the sheet looked up the milestone by id in `timelineProvider`,
/// which is unloaded on `/@username`, so the build returned
/// `SizedBox.shrink()` and the modal appeared to "not open" for unauthenticated
/// viewers.
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
      initialMilestone: milestone,
      onToggleReaction: onToggleReaction,
    ),
  );
}

class _MilestoneDetailSheet extends ConsumerWidget {
  final ArtistMilestone initialMilestone;
  final Future<bool?> Function(String milestoneId, String emoji)?
  onToggleReaction;

  const _MilestoneDetailSheet({
    required this.initialMilestone,
    this.onToggleReaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The passed `initialMilestone` is the source of truth. We always
    // `ref.watch(timelineProvider)` (Riverpod's rule against conditional
    // watches) and only consult its data on the authenticated path —
    // unauthenticated viewers run against `publicTimelineProvider` so the
    // `timelineProvider.artist` they read is always null and the live data
    // path harmlessly no-ops.
    final timelineArtist = ref.watch(timelineProvider).artist;
    final fresh = onToggleReaction != null
        ? timelineArtist?.milestones
              .where((m) => m.id == initialMilestone.id)
              .firstOrNull
        : null;
    final milestone = fresh ?? initialMilestone;

    final reactionCounts = milestone.reactionCounts;
    final myReactions = milestone.myReactions.toSet();

    final categoryLabel = milestoneCategoryName(context, milestone.category);
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
                      Text(
                        context.l10n.milestone,
                        style: const TextStyle(
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
                    _formatDate(context, milestone.date),
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
                                onToggleReaction!(milestone.id, r.emoji),
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
                          onTap: () => onToggleReaction!(milestone.id, emoji),
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

  static String _formatDate(BuildContext context, String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${monthFull(context, date.month)} ${date.day}, ${date.year}';
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
