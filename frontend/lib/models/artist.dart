import 'genre.dart';
import 'post.dart' show ReactionCount;
import 'track.dart';

class ArtistLink {
  final String id;
  final String linkCategory;
  final String platform;
  final String url;
  final int position;

  const ArtistLink({
    required this.id,
    required this.linkCategory,
    required this.platform,
    required this.url,
    required this.position,
  });

  factory ArtistLink.fromJson(Map<String, dynamic> json) {
    return ArtistLink(
      id: json['id'] as String,
      linkCategory: json['linkCategory'] as String,
      platform: json['platform'] as String,
      url: json['url'] as String,
      position: json['position'] as int? ?? 0,
    );
  }
}

class ArtistMilestone {
  final String id;
  final String category;
  final String title;
  final String? description;
  final String date; // YYYY-MM-DD
  final int position;
  final List<ReactionCount> reactionCounts;
  final List<String> myReactions;

  const ArtistMilestone({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.date,
    required this.position,
    this.reactionCounts = const [],
    this.myReactions = const [],
  });

  /// Parse the date string to DateTime for timeline positioning.
  /// Uses noon (12:00) so milestones appear in the middle of the day
  /// rather than at midnight (which would place them at the bottom).
  DateTime get displayDate {
    final d = DateTime.parse(date);
    return DateTime(d.year, d.month, d.day, 12);
  }

  int get totalReactions => reactionCounts.fold(0, (sum, r) => sum + r.count);

  factory ArtistMilestone.fromJson(Map<String, dynamic> json) {
    return ArtistMilestone(
      id: json['id'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: json['date'] as String,
      position: json['position'] as int? ?? 0,
      reactionCounts:
          (json['reactionCounts'] as List<dynamic>?)
              ?.map((e) => ReactionCount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      myReactions:
          (json['myReactions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

/// A single day of artist posting activity (Idea 032).
/// `date` is a UTC date in ISO short form (`YYYY-MM-DD`). The `count`
/// reflects only posts the viewer is permitted to see.
class ActivityDay {
  final String date;
  final int count;

  const ActivityDay({required this.date, required this.count});

  /// Parse the date string to DateTime at noon UTC for layout
  /// positioning. Returns `null` for malformed input rather than
  /// throwing — every call site is on a hot UI path (heatmap layout,
  /// Phase 1 cell tap) where a [FormatException] would blank the
  /// artist page over what is, semantically, a decorative surface.
  /// Noon avoids the timezone-boundary off-by-one that would
  /// otherwise put a YYYY-MM-DD cell on the wrong day when the
  /// device clock crosses midnight relative to UTC.
  DateTime? get utcDateOrNull {
    final parts = date.split('-');
    if (parts.length < 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime.utc(y, m, d, 12);
  }

  factory ActivityDay.fromJson(Map<String, dynamic> json) {
    // Lenient casts (`num?` → `toInt()`, `String?`) so a malformed
    // response or a future field-type drift doesn't crash the entire
    // artist page. Days that fail to parse silently collapse to an
    // empty cell, which is the right UX trade-off for a decorative
    // surface (Idea 032). Empty-string dates are still emitted here
    // but filtered out at the widget level (see ActivityGrid's
    // `_buildCountMap`) so they never pollute lookup tables.
    return ActivityDay(
      date: (json['date'] as String?) ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Lenient ISO 8601 parser. Returns null on `FormatException` rather than
/// crashing the caller — used for optional timestamp fields that arrive on
/// the wire (createdAt, lastPostedAt) where a corrupt value should
/// degrade gracefully rather than blank the whole artist page.
DateTime? _tryParseUtc(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DateTime.parse(raw).toUtc();
  } on FormatException {
    return null;
  }
}

class Artist {
  final String id;
  final String artistUsername;
  final String? displayName;
  final String? bio;
  final String? tagline;
  final String? location;
  final int? activeSince;
  final String? avatarUrl;
  final String? coverImageUrl;
  final String profileVisibility;
  bool get isPrivate => profileVisibility == 'private';
  final int tunedInCount;
  final List<Track> tracks;
  final List<ArtistGenre> genres;
  final List<ArtistLink> links;
  final List<ArtistMilestone> milestones;
  // Idea 032 — activity heatmap surface. `createdAt` anchors the star
  // calendar to the artist's registration day so the leftmost column lines
  // up with the day the artist joined. Nullable because not every query
  // (e.g. `discoverArtistsQuery`) requests it; callers that need a
  // calendar (StarCalendar) treat null as "skip the grid" rather than
  // backfilling a sentinel epoch date which would render as 52 weeks of
  // empty cells.
  final DateTime? createdAt;
  final List<ActivityDay> activitySeries;
  final DateTime? lastPostedAt;

  const Artist({
    required this.id,
    required this.artistUsername,
    this.displayName,
    this.bio,
    this.tagline,
    this.location,
    this.activeSince,
    this.avatarUrl,
    this.coverImageUrl,
    this.profileVisibility = 'public',
    required this.tunedInCount,
    required this.tracks,
    this.genres = const [],
    this.links = const [],
    this.milestones = const [],
    this.createdAt,
    this.activitySeries = const [],
    this.lastPostedAt,
  });

  Artist withTrack(Track track) => Artist(
    id: id,
    artistUsername: artistUsername,
    displayName: displayName,
    bio: bio,
    tagline: tagline,
    location: location,
    activeSince: activeSince,
    avatarUrl: avatarUrl,
    coverImageUrl: coverImageUrl,
    profileVisibility: profileVisibility,
    tunedInCount: tunedInCount,
    tracks: [...tracks, track],
    genres: genres,
    links: links,
    milestones: milestones,
    createdAt: createdAt,
    activitySeries: activitySeries,
    lastPostedAt: lastPostedAt,
  );

  Artist copyWithMilestones(List<ArtistMilestone> newMilestones) => Artist(
    id: id,
    artistUsername: artistUsername,
    displayName: displayName,
    bio: bio,
    tagline: tagline,
    location: location,
    activeSince: activeSince,
    avatarUrl: avatarUrl,
    coverImageUrl: coverImageUrl,
    profileVisibility: profileVisibility,
    tunedInCount: tunedInCount,
    tracks: tracks,
    genres: genres,
    links: links,
    milestones: newMilestones,
    createdAt: createdAt,
    activitySeries: activitySeries,
    lastPostedAt: lastPostedAt,
  );

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String,
      artistUsername: json['artistUsername'] as String,
      displayName: json['displayName'] as String?,
      bio: json['bio'] as String?,
      tagline: json['tagline'] as String?,
      location: json['location'] as String?,
      activeSince: json['activeSince'] as int?,
      avatarUrl: json['avatarUrl'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      profileVisibility: json['profileVisibility'] as String? ?? 'public',
      tunedInCount: json['tunedInCount'] as int,
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      genres:
          (json['genres'] as List<dynamic>?)
              ?.map((g) => ArtistGenre.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      links:
          (json['links'] as List<dynamic>?)
              ?.map((l) => ArtistLink.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      milestones:
          (json['milestones'] as List<dynamic>?)
              ?.map((m) => ArtistMilestone.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      // Both timestamps go through `_tryParseUtc` so a malformed wire
      // value (corrupt cache, future schema drift) returns null rather
      // than throwing FormatException and blanking the artist page.
      createdAt: _tryParseUtc(json['createdAt'] as String?),
      activitySeries:
          (json['activitySeries'] as List<dynamic>?)
              ?.map((a) => ActivityDay.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
      lastPostedAt: _tryParseUtc(json['lastPostedAt'] as String?),
    );
  }
}
