import 'dart:math';

import '../models/post.dart';
import '../models/track.dart';

/// Per-track activity statistics derived from a slice of recent posts.
///
/// Used by `MarqueeTrackRail` to drive the highlight pulse (fresh) and
/// halo (active) cues.
class TrackActivity {
  /// True when the track has at least one post in the last 24 hours.
  /// Drives the "fresh" white-pulse highlight.
  final bool isFresh;

  /// Number of posts attributed to this track within the last 7 days.
  /// Tracks with [weekPostCount] >= 5 receive the colored halo.
  final int weekPostCount;

  const TrackActivity({required this.isFresh, required this.weekPostCount});

  bool get isActive => weekPostCount >= 5;

  static const empty = TrackActivity(isFresh: false, weekPostCount: 0);
}

/// Compute per-track activity from the currently loaded slice of posts.
///
/// Returns a map keyed by `trackId`. Tracks with no posts in the lookback
/// window are absent from the map (callers should treat absence as
/// [TrackActivity.empty]).
///
/// `now` defaults to [DateTime.now] — tests inject a fixed reference time.
///
/// TODO(phase-1): the input `posts` is the paginated slice currently held
/// by `TimelineState`. With Phase 0 data volume (tens of posts per
/// artist) this is acceptable. When `fetchMore` lands or the timeline
/// starts trimming aggressively, callers should switch to a dedicated
/// activity query so the highlight does not depend on scroll position.
Map<String, TrackActivity> computeTrackActivity(
  List<Post> posts, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final freshThreshold = reference.subtract(const Duration(hours: 24));
  final weekThreshold = reference.subtract(const Duration(days: 7));

  final freshTrackIds = <String>{};
  final weekCounts = <String, int>{};

  for (final post in posts) {
    final trackId = post.trackId;
    if (trackId == null) continue;
    final date = post.createdAt;
    if (!date.isAfter(weekThreshold)) continue;
    weekCounts[trackId] = (weekCounts[trackId] ?? 0) + 1;
    if (date.isAfter(freshThreshold)) freshTrackIds.add(trackId);
  }

  return {
    for (final entry in weekCounts.entries)
      entry.key: TrackActivity(
        isFresh: freshTrackIds.contains(entry.key),
        weekPostCount: entry.value,
      ),
  };
}

/// Return a new list with [tracks] shuffled deterministically by [seed].
///
/// Used to vary the marquee order each time the timeline is reloaded
/// (`pull-to-refresh`, foreground resume) without losing the ability to
/// regenerate the exact same order in widget tests. The expanded view
/// reuses the same shuffled order so chips do not reflow when the user
/// swaps between marquee and expanded modes — original design also
/// shipped a `sortByWeekActivity` helper for an activity-descending
/// expanded view, but manual QA showed the reflow was distracting and
/// the helper was retired (see PR #444 discussion).
List<Track> shuffleTracks(List<Track> tracks, int seed) {
  if (tracks.isEmpty) return const [];
  final result = List<Track>.from(tracks);
  result.shuffle(Random(seed));
  return result;
}
