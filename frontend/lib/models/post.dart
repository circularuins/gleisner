import 'dart:ui';

import 'track.dart';

class PostAuthor {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  const PostAuthor({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

enum MediaType { text, image, video, audio, link }

class Post {
  final String id;
  final MediaType mediaType;
  final String? title;
  final String? body;
  final String? mediaUrl;
  final int? duration;
  final double importance;
  final double? layoutX;
  final double? layoutY;
  final String? contentHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PostAuthor author;
  final String? trackId;
  final String? trackName;
  final String? trackColor;

  const Post({
    required this.id,
    required this.mediaType,
    this.title,
    this.body,
    this.mediaUrl,
    this.duration,
    required this.importance,
    this.layoutX,
    this.layoutY,
    this.contentHash,
    required this.createdAt,
    required this.updatedAt,
    required this.author,
    this.trackId,
    this.trackName,
    this.trackColor,
  });

  Color get trackDisplayColor => parseHexColor(trackColor);

  /// Format duration as "m:ss" or "h:mm:ss". Returns null if no duration.
  String? get formattedDuration {
    if (duration == null) return null;
    final d = duration!;
    final h = d ~/ 3600;
    final m = (d % 3600) ~/ 60;
    final s = d % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    final track = json['track'] as Map<String, dynamic>?;
    return Post(
      id: json['id'] as String,
      mediaType: _parseMediaType(json['mediaType'] as String),
      title: json['title'] as String?,
      body: json['body'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      importance: (json['importance'] as num).toDouble(),
      layoutX: (json['layoutX'] as num?)?.toDouble(),
      layoutY: (json['layoutY'] as num?)?.toDouble(),
      contentHash: json['contentHash'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      trackId: track?['id'] as String?,
      trackName: track?['name'] as String?,
      trackColor: track?['color'] as String?,
    );
  }
}

MediaType _parseMediaType(String value) {
  for (final type in MediaType.values) {
    if (type.name == value) return type;
  }
  return MediaType.text;
}
