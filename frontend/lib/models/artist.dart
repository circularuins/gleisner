import 'genre.dart';
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
  final int tunedInCount;
  final List<Track> tracks;
  final List<ArtistGenre> genres;
  final List<ArtistLink> links;

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
    required this.tunedInCount,
    required this.tracks,
    this.genres = const [],
    this.links = const [],
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
    tunedInCount: tunedInCount,
    tracks: [...tracks, track],
    genres: genres,
    links: links,
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
    );
  }
}
