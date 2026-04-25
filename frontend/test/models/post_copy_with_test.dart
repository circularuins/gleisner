import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/models/post.dart';

Post _makeTestPost() {
  final now = DateTime(2026, 1, 1);
  return Post(
    id: 'p1',
    mediaType: MediaType.thought,
    title: 'Original Title',
    body: 'Original Body',
    mediaUrl: 'https://example.com',
    duration: 120,
    importance: 0.5,
    visibility: 'public',
    layoutX: 10,
    layoutY: 20,
    contentHash: 'abc123',
    createdAt: now,
    updatedAt: now,
    author: const PostAuthor(id: 'a1', username: 'test'),
    trackId: 't1',
    trackName: 'Track 1',
    trackColor: '#ff0000',
    reactionCounts: const [ReactionCount(emoji: '🔥', count: 3)],
    myReactions: const ['🔥'],
    outgoingConnections: const [
      PostConnection(
        id: 'c1',
        sourceId: 'p1',
        targetId: 'p2',
        connectionType: ConnectionType.reference,
      ),
    ],
    incomingConnections: const [],
  );
}

void main() {
  group('Post.copyWith', () {
    test('returns identical post when no args provided', () {
      final post = _makeTestPost();
      final copy = post.copyWith();

      expect(copy.id, post.id);
      expect(copy.title, post.title);
      expect(copy.body, post.body);
      expect(copy.mediaUrl, post.mediaUrl);
      expect(copy.duration, post.duration);
      expect(copy.importance, post.importance);
      expect(copy.visibility, post.visibility);
      expect(copy.layoutX, post.layoutX);
      expect(copy.layoutY, post.layoutY);
      expect(copy.contentHash, post.contentHash);
      expect(copy.trackId, post.trackId);
      expect(copy.trackName, post.trackName);
      expect(copy.trackColor, post.trackColor);
      expect(copy.reactionCounts, post.reactionCounts);
      expect(copy.myReactions, post.myReactions);
      expect(copy.outgoingConnections, post.outgoingConnections);
      expect(copy.incomingConnections, post.incomingConnections);
      expect(copy.constellation, post.constellation);
    });

    test('updates specified fields', () {
      final post = _makeTestPost();
      final copy = post.copyWith(
        title: 'New Title',
        importance: 0.9,
        visibility: 'draft',
      );

      expect(copy.title, 'New Title');
      expect(copy.importance, 0.9);
      expect(copy.visibility, 'draft');
      // Other fields unchanged
      expect(copy.body, post.body);
      expect(copy.id, post.id);
    });

    test('sets nullable field to null explicitly', () {
      final post = _makeTestPost();
      expect(post.title, isNotNull);

      final copy = post.copyWith(title: null);
      expect(copy.title, isNull);
    });

    test('preserves null field when not specified', () {
      final post = _makeTestPost();
      final withoutTitle = post.copyWith(title: null);
      expect(withoutTitle.title, isNull);

      // copyWith without title arg should preserve null
      final copy = withoutTitle.copyWith(body: 'New Body');
      expect(copy.title, isNull);
      expect(copy.body, 'New Body');
    });

    test('updates outgoingConnections', () {
      final post = _makeTestPost();
      expect(post.outgoingConnections.length, 1);

      final newConn = const PostConnection(
        id: 'c2',
        sourceId: 'p1',
        targetId: 'p3',
        connectionType: ConnectionType.reference,
      );
      final copy = post.copyWith(
        outgoingConnections: [...post.outgoingConnections, newConn],
      );
      expect(copy.outgoingConnections.length, 2);
      // Original unchanged
      expect(post.outgoingConnections.length, 1);
    });

    test('updates reactionCounts and myReactions', () {
      final post = _makeTestPost();
      final copy = post.copyWith(
        reactionCounts: const [
          ReactionCount(emoji: '🔥', count: 5),
          ReactionCount(emoji: '❤️', count: 2),
        ],
        myReactions: const ['🔥', '❤️'],
      );

      expect(copy.reactionCounts.length, 2);
      expect(copy.myReactions.length, 2);
      expect(copy.reactionCounts[0].count, 5);
    });

    test('sets constellation to null', () {
      final post = _makeTestPost();
      final withConstellation = post.copyWith(
        constellation: const PostConstellation(
          id: 'const1',
          name: 'Test',
          anchorPostId: 'p1',
        ),
      );
      expect(withConstellation.constellation, isNotNull);

      final cleared = withConstellation.copyWith(constellation: null);
      expect(cleared.constellation, isNull);
    });

    test(
      'immutable fields (id, mediaType, createdAt, author) are preserved',
      () {
        final post = _makeTestPost();
        final copy = post.copyWith(title: 'Changed');

        expect(copy.id, post.id);
        expect(copy.mediaType, post.mediaType);
        expect(copy.createdAt, post.createdAt);
        expect(copy.author.id, post.author.id);
      },
    );
  });
}
