import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../utils/sentinel.dart';
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

class ReactionCount {
  final String emoji;
  final int count;

  const ReactionCount({required this.emoji, required this.count});

  factory ReactionCount.fromJson(Map<String, dynamic> json) {
    return ReactionCount(
      emoji: json['emoji'] as String,
      count: json['count'] as int,
    );
  }
}

class PostConstellation {
  final String id;
  final String name;
  final String anchorPostId;

  const PostConstellation({
    required this.id,
    required this.name,
    required this.anchorPostId,
  });

  factory PostConstellation.fromJson(Map<String, dynamic> json) {
    return PostConstellation(
      id: json['id'] as String,
      name: json['name'] as String,
      anchorPostId: json['anchorPostId'] as String,
    );
  }
}

/// The four connection types supported by Gleisner.
///
/// Each type has a distinct motion signature when visualized as
/// travelling dots on the timeline (see ADR 024).
enum ConnectionType {
  reference,
  evolution,
  remix,
  reply;

  /// Parse from a backend string. Falls back to [reference] for unknown values.
  static ConnectionType fromString(String value) {
    return switch (value) {
      'reference' => ConnectionType.reference,
      'evolution' => ConnectionType.evolution,
      'remix' => ConnectionType.remix,
      'reply' => ConnectionType.reply,
      _ => () {
          debugPrint('[ConnectionType] Unknown value "$value", '
              'falling back to reference');
          return ConnectionType.reference;
        }(),
    };
  }
}

class PostConnection {
  final String id;
  final String sourceId;
  final String targetId;
  final ConnectionType connectionType;

  const PostConnection({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.connectionType,
  });

  factory PostConnection.fromJson(Map<String, dynamic> json) {
    return PostConnection(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      targetId: json['targetId'] as String,
      connectionType:
          ConnectionType.fromString(json['connectionType'] as String),
    );
  }
}

class Post {
  final String id;
  final MediaType mediaType;
  final String? title;
  final String? body;
  final String? mediaUrl;
  final int? duration;
  final double importance;
  final String visibility;
  final double? layoutX;
  final double? layoutY;
  final String? contentHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PostAuthor author;
  final String? trackId;
  final String? trackName;
  final String? trackColor;
  final List<ReactionCount> reactionCounts;
  final List<String> myReactions;
  final List<PostConnection> outgoingConnections;
  final List<PostConnection> incomingConnections;
  final PostConstellation? constellation;

  const Post({
    required this.id,
    required this.mediaType,
    this.title,
    this.body,
    this.mediaUrl,
    this.duration,
    required this.importance,
    this.visibility = 'public',
    this.layoutX,
    this.layoutY,
    this.contentHash,
    required this.createdAt,
    required this.updatedAt,
    required this.author,
    this.trackId,
    this.trackName,
    this.trackColor,
    this.reactionCounts = const [],
    this.myReactions = const [],
    this.outgoingConnections = const [],
    this.incomingConnections = const [],
    this.constellation,
  });

  Post copyWith({
    Object? title = sentinel,
    Object? body = sentinel,
    Object? mediaUrl = sentinel,
    Object? duration = sentinel,
    double? importance,
    String? visibility,
    Object? layoutX = sentinel,
    Object? layoutY = sentinel,
    Object? contentHash = sentinel,
    Object? trackId = sentinel,
    Object? trackName = sentinel,
    Object? trackColor = sentinel,
    List<ReactionCount>? reactionCounts,
    List<String>? myReactions,
    List<PostConnection>? outgoingConnections,
    List<PostConnection>? incomingConnections,
    Object? constellation = sentinel,
  }) {
    return Post(
      id: id,
      mediaType: mediaType,
      title: title == sentinel ? this.title : title as String?,
      body: body == sentinel ? this.body : body as String?,
      mediaUrl: mediaUrl == sentinel ? this.mediaUrl : mediaUrl as String?,
      duration: duration == sentinel ? this.duration : duration as int?,
      importance: importance ?? this.importance,
      visibility: visibility ?? this.visibility,
      layoutX: layoutX == sentinel ? this.layoutX : layoutX as double?,
      layoutY: layoutY == sentinel ? this.layoutY : layoutY as double?,
      contentHash: contentHash == sentinel
          ? this.contentHash
          : contentHash as String?,
      createdAt: createdAt,
      updatedAt: updatedAt,
      author: author,
      trackId: trackId == sentinel ? this.trackId : trackId as String?,
      trackName: trackName == sentinel ? this.trackName : trackName as String?,
      trackColor: trackColor == sentinel
          ? this.trackColor
          : trackColor as String?,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      myReactions: myReactions ?? this.myReactions,
      outgoingConnections: outgoingConnections ?? this.outgoingConnections,
      incomingConnections: incomingConnections ?? this.incomingConnections,
      constellation: constellation == sentinel
          ? this.constellation
          : constellation as PostConstellation?,
    );
  }

  Color get trackDisplayColor => parseHexColor(trackColor);

  /// Total reaction count across all emoji types.
  int get totalReactions => reactionCounts.fold(0, (sum, r) => sum + r.count);

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
      visibility: json['visibility'] as String? ?? 'public',
      layoutX: (json['layoutX'] as num?)?.toDouble(),
      layoutY: (json['layoutY'] as num?)?.toDouble(),
      contentHash: json['contentHash'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      trackId: track?['id'] as String?,
      trackName: track?['name'] as String?,
      trackColor: track?['color'] as String?,
      reactionCounts:
          (json['reactionCounts'] as List<dynamic>?)
              ?.map((r) => ReactionCount.fromJson(r as Map<String, dynamic>))
              .toList() ??
          const [],
      myReactions:
          (json['myReactions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      outgoingConnections:
          (json['outgoingConnections'] as List<dynamic>?)
              ?.map((c) => PostConnection.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      incomingConnections:
          (json['incomingConnections'] as List<dynamic>?)
              ?.map((c) => PostConnection.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      constellation: json['constellation'] != null
          ? PostConstellation.fromJson(
              json['constellation'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

MediaType _parseMediaType(String value) {
  for (final type in MediaType.values) {
    if (type.name == value) return type;
  }
  return MediaType.text;
}
