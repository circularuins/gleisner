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
  final double importance;
  final double? layoutX;
  final double? layoutY;
  final String? contentHash;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PostAuthor author;

  const Post({
    required this.id,
    required this.mediaType,
    this.title,
    this.body,
    this.mediaUrl,
    required this.importance,
    this.layoutX,
    this.layoutY,
    this.contentHash,
    required this.createdAt,
    required this.updatedAt,
    required this.author,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      mediaType: MediaType.values.byName(json['mediaType'] as String),
      title: json['title'] as String?,
      body: json['body'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      importance: (json['importance'] as num).toDouble(),
      layoutX: (json['layoutX'] as num?)?.toDouble(),
      layoutY: (json['layoutY'] as num?)?.toDouble(),
      contentHash: json['contentHash'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
    );
  }
}
