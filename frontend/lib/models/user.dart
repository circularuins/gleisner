import '../utils/sentinel.dart';

class User {
  final String id;
  final String did;
  final String email;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final String profileVisibility;
  final String publicKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.did,
    required this.email,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.profileVisibility = 'public',
    required this.publicKey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      did: json['did'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      profileVisibility: json['profileVisibility'] as String? ?? 'public',
      publicKey: json['publicKey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  User copyWith({
    Object? displayName = sentinel,
    Object? bio = sentinel,
    Object? avatarUrl = sentinel,
    String? profileVisibility,
    DateTime? updatedAt,
  }) {
    return User(
      id: id,
      did: did,
      email: email,
      username: username,
      displayName: displayName == sentinel
          ? this.displayName
          : displayName as String?,
      bio: bio == sentinel ? this.bio : bio as String?,
      avatarUrl: avatarUrl == sentinel ? this.avatarUrl : avatarUrl as String?,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      publicKey: publicKey,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
