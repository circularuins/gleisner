import 'package:flutter_test/flutter_test.dart';

import 'package:gleisner_web/models/post.dart';

void main() {
  final validJson = {
    'id': 'post-1',
    'mediaType': 'text',
    'title': 'Hello',
    'body': 'World',
    'mediaUrl': null,
    'importance': 0.5,
    'layoutX': 1.0,
    'layoutY': 2.0,
    'contentHash': 'abc123',
    'createdAt': '2026-03-01T00:00:00Z',
    'updatedAt': '2026-03-01T00:00:00Z',
    'author': {
      'id': 'user-1',
      'username': 'alice',
      'displayName': 'Alice',
      'avatarUrl': null,
    },
  };

  group('Post.fromJson', () {
    test('parses valid JSON', () {
      final post = Post.fromJson(validJson);

      expect(post.id, 'post-1');
      expect(post.mediaType, MediaType.text);
      expect(post.title, 'Hello');
      expect(post.body, 'World');
      expect(post.importance, 0.5);
      expect(post.layoutX, 1.0);
      expect(post.layoutY, 2.0);
      expect(post.contentHash, 'abc123');
      expect(post.author.username, 'alice');
    });

    test('handles null optional fields', () {
      final json = {
        ...validJson,
        'title': null,
        'body': null,
        'mediaUrl': null,
        'layoutX': null,
        'layoutY': null,
        'contentHash': null,
      };

      final post = Post.fromJson(json);

      expect(post.title, isNull);
      expect(post.body, isNull);
      expect(post.mediaUrl, isNull);
      expect(post.layoutX, isNull);
      expect(post.layoutY, isNull);
      expect(post.contentHash, isNull);
    });

    test('parses all media types', () {
      for (final type in MediaType.values) {
        final json = {...validJson, 'mediaType': type.name};
        final post = Post.fromJson(json);
        expect(post.mediaType, type);
      }
    });

    test('throws on unknown mediaType', () {
      final json = {...validJson, 'mediaType': 'unknown'};
      expect(() => Post.fromJson(json), throwsArgumentError);
    });
  });
}
