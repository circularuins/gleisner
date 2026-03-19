class User {
  final String id;
  final String did;
  final String email;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
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
      publicKey: json['publicKey'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
