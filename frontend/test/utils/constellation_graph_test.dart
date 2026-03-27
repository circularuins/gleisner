import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/utils/constellation_graph.dart';

Post _makePost({
  required String id,
  List<PostConnection> outgoingConnections = const [],
  List<PostConnection> incomingConnections = const [],
}) {
  return Post(
    id: id,
    mediaType: MediaType.text,
    title: 'Post $id',
    importance: 0.5,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    author: const PostAuthor(id: 'a1', username: 'test'),
    outgoingConnections: outgoingConnections,
    incomingConnections: incomingConnections,
  );
}

PostConnection _conn(String id, String sourceId, String targetId) {
  return PostConnection(
    id: id,
    sourceId: sourceId,
    targetId: targetId,
    connectionType: 'reference',
  );
}

void main() {
  group('findConstellation', () {
    test('single post with no connections returns only itself', () {
      final posts = [_makePost(id: 'p1')];
      final result = findConstellation('p1', posts);
      expect(result, {'p1'});
    });

    test('two connected posts form a constellation', () {
      final conn = _conn('c1', 'p1', 'p2');
      final posts = [
        _makePost(id: 'p1', outgoingConnections: [conn]),
        _makePost(id: 'p2', incomingConnections: [conn]),
      ];
      final result = findConstellation('p1', posts);
      expect(result, {'p1', 'p2'});
    });

    test('traverses bidirectionally', () {
      final conn = _conn('c1', 'p1', 'p2');
      final posts = [
        _makePost(id: 'p1', outgoingConnections: [conn]),
        _makePost(id: 'p2', incomingConnections: [conn]),
      ];
      // Starting from p2 should also find p1
      final result = findConstellation('p2', posts);
      expect(result, {'p1', 'p2'});
    });

    test('chain of 3 posts forms single constellation', () {
      final c1 = _conn('c1', 'p1', 'p2');
      final c2 = _conn('c2', 'p2', 'p3');
      final posts = [
        _makePost(id: 'p1', outgoingConnections: [c1]),
        _makePost(
          id: 'p2',
          incomingConnections: [c1],
          outgoingConnections: [c2],
        ),
        _makePost(id: 'p3', incomingConnections: [c2]),
      ];
      final result = findConstellation('p1', posts);
      expect(result, {'p1', 'p2', 'p3'});
    });

    test('disconnected posts are not included', () {
      final conn = _conn('c1', 'p1', 'p2');
      final posts = [
        _makePost(id: 'p1', outgoingConnections: [conn]),
        _makePost(id: 'p2', incomingConnections: [conn]),
        _makePost(id: 'p3'), // disconnected
      ];
      final result = findConstellation('p1', posts);
      expect(result, {'p1', 'p2'});
      expect(result.contains('p3'), isFalse);
    });

    test('adding a connection expands the constellation', () {
      final c1 = _conn('c1', 'p1', 'p2');
      final posts = [
        _makePost(id: 'p1', outgoingConnections: [c1]),
        _makePost(id: 'p2', incomingConnections: [c1]),
        _makePost(id: 'p3'),
      ];

      // Before: p3 is not connected
      expect(findConstellation('p1', posts), {'p1', 'p2'});

      // Simulate adding connection p1 -> p3
      final c2 = _conn('c2', 'p1', 'p3');
      final updatedPosts = [
        _makePost(id: 'p1', outgoingConnections: [c1, c2]),
        _makePost(id: 'p2', incomingConnections: [c1]),
        _makePost(id: 'p3', incomingConnections: [c2]),
      ];
      expect(findConstellation('p1', updatedPosts), {'p1', 'p2', 'p3'});
    });

    test('removing a connection shrinks the constellation', () {
      final c1 = _conn('c1', 'p1', 'p2');
      final c2 = _conn('c2', 'p1', 'p3');
      final posts = [
        _makePost(id: 'p1', outgoingConnections: [c1, c2]),
        _makePost(id: 'p2', incomingConnections: [c1]),
        _makePost(id: 'p3', incomingConnections: [c2]),
      ];

      // Before: all connected
      expect(findConstellation('p1', posts), {'p1', 'p2', 'p3'});

      // Simulate removing connection p1 -> p3
      final updatedPosts = [
        _makePost(id: 'p1', outgoingConnections: [c1]),
        _makePost(id: 'p2', incomingConnections: [c1]),
        _makePost(id: 'p3'), // no connections
      ];
      expect(findConstellation('p1', updatedPosts), {'p1', 'p2'});
    });

    test('counterpart sync: source outgoing updated but target incoming stale', () {
      // This simulates the bug where local state updates source outgoing
      // but widget.allPosts has stale target incoming
      final c1 = _conn('c1', 'p1', 'p2');
      final posts = [
        // Source has the new connection
        _makePost(id: 'p1', outgoingConnections: [c1]),
        // Target does NOT have the incoming (stale data)
        _makePost(id: 'p2'),
      ];

      // Even with stale target, findConstellation should find both
      // because it reads connections from ALL posts' outgoing AND incoming
      final result = findConstellation('p1', posts);
      expect(result, {'p1', 'p2'});
    });

    test('counterpart sync: connection removed from source but target still has incoming', () {
      // This simulates the deletion bug: source outgoing removed
      // but target still has stale incoming
      final c1 = _conn('c1', 'p1', 'p2');
      final posts = [
        // Source: connection removed
        _makePost(id: 'p1'),
        // Target: still has stale incoming
        _makePost(id: 'p2', incomingConnections: [c1]),
      ];

      // findConstellation will STILL find both because target's incoming
      // references p1. This is the bug that _allPostsWithLocalConnections fixes.
      final result = findConstellation('p1', posts);
      // This shows why we need to sync counterpart: stale data causes
      // deleted connections to still appear
      expect(result, {'p1', 'p2'}); // BUG without counterpart sync

      // With proper sync (both sides cleaned up):
      final syncedPosts = [
        _makePost(id: 'p1'),
        _makePost(id: 'p2'), // incoming also removed
      ];
      final syncedResult = findConstellation('p1', syncedPosts);
      expect(syncedResult, {'p1'}); // Correct after sync
    });

    test('multiple outgoing connections from same post', () {
      final c1 = _conn('c1', 'p1', 'p2');
      final c2 = _conn('c2', 'p1', 'p3');
      final c3 = _conn('c3', 'p1', 'p4');
      final posts = [
        _makePost(id: 'p1', outgoingConnections: [c1, c2, c3]),
        _makePost(id: 'p2', incomingConnections: [c1]),
        _makePost(id: 'p3', incomingConnections: [c2]),
        _makePost(id: 'p4', incomingConnections: [c3]),
      ];
      final result = findConstellation('p1', posts);
      expect(result, {'p1', 'p2', 'p3', 'p4'});
    });
  });
}
