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
    );
  }
}
