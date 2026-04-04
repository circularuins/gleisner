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

    test('falls back to text on unknown mediaType', () {
      final json = {...validJson, 'mediaType': 'unknown'};
      final post = Post.fromJson(json);
      expect(post.mediaType, MediaType.text);
    });

    test('parses duration', () {
      final json = {...validJson, 'duration': 120};
      final post = Post.fromJson(json);
      expect(post.duration, 120);
    });

    test('handles null duration', () {
      final json = {...validJson, 'duration': null};
      final post = Post.fromJson(json);
      expect(post.duration, isNull);
    });
  });

  group('Post.formattedDuration', () {
    Post withDuration(int? d) => Post(
      id: '1',
      mediaType: MediaType.video,
      importance: 0.5,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      author: const PostAuthor(id: 'a', username: 'u'),
      duration: d,
    );

    test('returns null when duration is null', () {
      expect(withDuration(null).formattedDuration, isNull);
    });

    test('formats 0 seconds', () {
      expect(withDuration(0).formattedDuration, '0:00');
    });

    test('formats seconds only', () {
      expect(withDuration(45).formattedDuration, '0:45');
    });

    test('formats minutes and seconds', () {
      expect(withDuration(65).formattedDuration, '1:05');
    });

    test('formats exact minute', () {
      expect(withDuration(60).formattedDuration, '1:00');
    });

    test('formats hours', () {
      expect(withDuration(3661).formattedDuration, '1:01:01');
    });

    test('formats large duration', () {
      expect(withDuration(7200).formattedDuration, '2:00:00');
    });
  });

  group('Post.displayDate', () {
    test('returns eventAt when set', () {
      final eventAt = DateTime(2026, 1, 15, 14, 30);
      final post = Post.fromJson({
        ...validJson,
        'eventAt': eventAt.toIso8601String(),
      });
      expect(post.displayDate, eventAt);
    });

    test('returns createdAt when eventAt is null', () {
      final post = Post.fromJson(validJson);
      expect(post.eventAt, isNull);
      expect(post.displayDate, post.createdAt);
    });
  });
}
