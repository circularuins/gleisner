import 'track.dart';

class Artist {
  final String id;
  final String artistUsername;
  final String? displayName;
  final String? bio;
  final String? tagline;
  final String? avatarUrl;
  final String? coverImageUrl;
  final int tunedInCount;
  final List<Track> tracks;

  const Artist({
    required this.id,
    required this.artistUsername,
    this.displayName,
    this.bio,
    this.tagline,
    this.avatarUrl,
    this.coverImageUrl,
    required this.tunedInCount,
    required this.tracks,
  });

  Artist withTrack(Track track) => Artist(
    id: id,
    artistUsername: artistUsername,
    displayName: displayName,
    bio: bio,
    tagline: tagline,
    avatarUrl: avatarUrl,
    coverImageUrl: coverImageUrl,
    tunedInCount: tunedInCount,
    tracks: [...tracks, track],
  );

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String,
      artistUsername: json['artistUsername'] as String,
      displayName: json['displayName'] as String?,
      bio: json['bio'] as String?,
      tagline: json['tagline'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      tunedInCount: json['tunedInCount'] as int,
      tracks:
          (json['tracks'] as List<dynamic>?)
              ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
