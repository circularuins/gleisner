import 'artist.dart';
import 'post.dart';

/// A sealed type for items that can appear on the timeline.
sealed class TimelineItem {
  String get id;
  DateTime get displayDate;
  int get totalReactions;
}

/// A regular post on the timeline.
class PostItem implements TimelineItem {
  final Post post;
  const PostItem(this.post);

  @override
  String get id => post.id;

  @override
  DateTime get displayDate => post.displayDate;

  @override
  int get totalReactions => post.totalReactions;
}

/// An artist milestone (life event) on the timeline.
class MilestoneItem implements TimelineItem {
  final ArtistMilestone milestone;
  const MilestoneItem(this.milestone);

  @override
  String get id => 'milestone:${milestone.id}';

  @override
  DateTime get displayDate => milestone.displayDate;

  @override
  int get totalReactions => milestone.totalReactions;
}
