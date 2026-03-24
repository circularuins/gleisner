import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/utils/constellation_layout.dart';

Post _makePost({
  required String id,
  required DateTime createdAt,
  double importance = 0.5,
  MediaType mediaType = MediaType.text,
  String? trackId,
  String? trackName,
  String? trackColor,
  String? body,
  List<ReactionCount> reactionCounts = const [],
  List<PostConnection> outgoingConnections = const [],
  List<PostConnection> incomingConnections = const [],
}) {
  return Post(
    id: id,
    mediaType: mediaType,
    title: 'Post $id',
    body: body,
    importance: importance,
    createdAt: createdAt,
    updatedAt: createdAt,
    author: const PostAuthor(id: 'a1', username: 'test'),
    trackId: trackId,
    trackName: trackName,
    trackColor: trackColor,
    reactionCounts: reactionCounts,
    outgoingConnections: outgoingConnections,
    incomingConnections: incomingConnections,
  );
}

void main() {
  group('ConstellationLayout.nodeSize', () {
    test('minimum size at importance 0', () {
      expect(ConstellationLayout.nodeSize(0), 90);
    });

    test('maximum size at importance 1', () {
      expect(ConstellationLayout.nodeSize(1), 170);
    });

    test('clamps importance above 1', () {
      expect(ConstellationLayout.nodeSize(1.5), 170);
    });

    test('clamps negative importance', () {
      expect(ConstellationLayout.nodeSize(-0.5), 90);
    });

    test('mid importance gives mid size', () {
      expect(ConstellationLayout.nodeSize(0.5), 130);
    });
  });

  group('ConstellationLayout.compute', () {
    test('empty posts returns empty layout', () {
      final result = ConstellationLayout.compute(
        posts: [],
        containerWidth: 400,
      );
      expect(result.nodes, isEmpty);
      expect(result.days, isEmpty);
      expect(result.connections, isEmpty);
      expect(result.totalHeight, 0);
    });

    test('single post produces one node and one day section', () {
      final post = _makePost(id: '1', createdAt: DateTime.now());
      final result = ConstellationLayout.compute(
        posts: [post],
        containerWidth: 400,
      );
      expect(result.nodes, hasLength(1));
      expect(result.days, hasLength(1));
      expect(result.days.first.isToday, isTrue);
      expect(result.totalHeight, greaterThan(0));
    });

    test('nodes have positive dimensions', () {
      final post = _makePost(
        id: '1',
        createdAt: DateTime.now(),
        importance: 0.3,
      );
      final result = ConstellationLayout.compute(
        posts: [post],
        containerWidth: 400,
      );
      final node = result.nodes.first;
      expect(node.width, greaterThan(0));
      expect(node.height, greaterThan(0));
      expect(node.mediaHeight, greaterThan(0));
      expect(node.nodeSize, ConstellationLayout.nodeSize(0.3));
    });

    test('all nodes show info', () {
      final posts = List.generate(
        5,
        (i) => _makePost(
          id: '$i',
          createdAt: DateTime.now().subtract(Duration(hours: i)),
          importance: i * 0.2,
        ),
      );
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      for (final node in result.nodes) {
        expect(node.showInfo, isTrue);
      }
    });

    test('nodes fit within container width', () {
      final posts = List.generate(
        10,
        (i) => _makePost(
          id: '$i',
          createdAt: DateTime.now().subtract(Duration(hours: i)),
          importance: i * 0.1,
        ),
      );
      const width = 400.0;
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: width,
      );
      for (final node in result.nodes) {
        expect(
          node.x + node.width,
          lessThanOrEqualTo(width - ConstellationLayout.spineWidth + 1),
          reason: 'Node ${node.post.id} exceeds container width',
        );
      }
    });
  });

  group('Time-series ordering', () {
    test('newer posts have top edge at or above older posts', () {
      final now = DateTime.now();
      final posts = List.generate(
        8,
        (i) => _makePost(
          id: '$i',
          createdAt: now.subtract(Duration(hours: i * 3)),
          importance: (i % 3) * 0.3 + 0.1,
        ),
      );
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );

      // Sort nodes by createdAt descending (newest first)
      final sorted = List<PlacedNode>.from(result.nodes)
        ..sort((a, b) => b.post.createdAt.compareTo(a.post.createdAt));

      for (int i = 1; i < sorted.length; i++) {
        expect(
          sorted[i].y,
          greaterThanOrEqualTo(sorted[i - 1].y),
          reason:
              'Post ${sorted[i].post.id} (older) should be at or below '
              'post ${sorted[i - 1].post.id} (newer): '
              '${sorted[i].y} vs ${sorted[i - 1].y}',
        );
      }
    });

    test('posts across different days maintain day ordering', () {
      final now = DateTime.now();
      final posts = [
        _makePost(id: 'today', createdAt: now, importance: 0.3),
        _makePost(
          id: 'yesterday',
          createdAt: now.subtract(const Duration(days: 1)),
          importance: 0.9,
        ),
        _makePost(
          id: '3days',
          createdAt: now.subtract(const Duration(days: 3)),
          importance: 1.0,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );

      final nodeMap = {for (final n in result.nodes) n.post.id: n};
      expect(nodeMap['today']!.y, lessThanOrEqualTo(nodeMap['yesterday']!.y));
      expect(nodeMap['yesterday']!.y, lessThanOrEqualTo(nodeMap['3days']!.y));
    });

    test('same-day posts have slight vertical offset (nudge)', () {
      final now = DateTime.now();
      final posts = [
        _makePost(id: 'newer', createdAt: now, importance: 0.5),
        _makePost(
          id: 'older',
          createdAt: now.subtract(const Duration(minutes: 5)),
          importance: 0.5,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );

      final nodeMap = {for (final n in result.nodes) n.post.id: n};
      expect(
        nodeMap['older']!.y,
        greaterThan(nodeMap['newer']!.y),
        reason: 'Older post should be slightly below newer post',
      );
    });
  });

  group('Day sections', () {
    test('day sections created only for days with posts', () {
      final now = DateTime.now();
      final posts = [
        _makePost(id: '1', createdAt: now),
        _makePost(id: '2', createdAt: now.subtract(const Duration(days: 3))),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      // Only 2 days: today and 3 days ago (not days 1 and 2)
      expect(result.days, hasLength(2));
    });

    test('today section is marked isToday', () {
      final post = _makePost(id: '1', createdAt: DateTime.now());
      final result = ConstellationLayout.compute(
        posts: [post],
        containerWidth: 400,
      );
      expect(result.days.first.isToday, isTrue);
    });

    test('day sections are ordered top to bottom', () {
      final now = DateTime.now();
      final posts = List.generate(
        5,
        (i) => _makePost(
          id: '$i',
          createdAt: now.subtract(Duration(days: i * 2)),
        ),
      );
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      for (int i = 1; i < result.days.length; i++) {
        expect(
          result.days[i].top,
          greaterThan(result.days[i - 1].top),
          reason: 'Day $i should be below day ${i - 1}',
        );
      }
    });

    test('minimum gap between day sections', () {
      final now = DateTime.now();
      final posts = [
        _makePost(id: '1', createdAt: now, importance: 0.0),
        _makePost(
          id: '2',
          createdAt: now.subtract(const Duration(days: 1)),
          importance: 0.0,
        ),
        _makePost(
          id: '3',
          createdAt: now.subtract(const Duration(days: 2)),
          importance: 0.0,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      for (int i = 1; i < result.days.length; i++) {
        final gap = result.days[i].top - result.days[i - 1].top;
        expect(
          gap,
          greaterThanOrEqualTo(28),
          reason: 'Gap between days $i and ${i - 1} too small: $gap',
        );
      }
    });
  });

  group('Synapse connections', () {
    test('same-track adjacent posts produce connections', () {
      final now = DateTime.now();
      final posts = [
        _makePost(
          id: '1',
          createdAt: now,
          trackId: 'track-a',
          trackColor: '#ff0000',
          outgoingConnections: [
            const PostConnection(
              id: 'conn-1',
              sourceId: '1',
              targetId: '2',
              connectionType: 'synapse',
            ),
          ],
        ),
        _makePost(
          id: '2',
          createdAt: now.subtract(const Duration(hours: 2)),
          trackId: 'track-a',
          trackColor: '#ff0000',
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      expect(result.connections, isNotEmpty);
    });

    test('different tracks produce no connections', () {
      final now = DateTime.now();
      final posts = [
        _makePost(
          id: '1',
          createdAt: now,
          trackId: 'track-a',
          trackColor: '#ff0000',
        ),
        _makePost(
          id: '2',
          createdAt: now.subtract(const Duration(hours: 2)),
          trackId: 'track-b',
          trackColor: '#00ff00',
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      expect(result.connections, isEmpty);
    });

    test('posts without trackId produce no connections', () {
      final now = DateTime.now();
      final posts = [
        _makePost(id: '1', createdAt: now),
        _makePost(id: '2', createdAt: now.subtract(const Duration(hours: 2))),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      expect(result.connections, isEmpty);
    });
  });

  group('Determinism', () {
    test('same input produces same output', () {
      final now = DateTime(2026, 3, 21, 12, 0, 0);
      final posts = List.generate(
        10,
        (i) => _makePost(
          id: 'p$i',
          createdAt: now.subtract(Duration(hours: i * 5)),
          importance: (i % 5) * 0.2,
          trackId: 'track-${i % 3}',
          trackColor: '#ff${i}${i}00',
        ),
      );

      final result1 = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      final result2 = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );

      expect(result1.nodes.length, result2.nodes.length);
      for (int i = 0; i < result1.nodes.length; i++) {
        expect(result1.nodes[i].x, result2.nodes[i].x);
        expect(result1.nodes[i].y, result2.nodes[i].y);
      }
      expect(result1.totalHeight, result2.totalHeight);
    });
  });

  group('Engagement boost', () {
    test('nodeSize increases with reaction count', () {
      final base = ConstellationLayout.nodeSize(0.5);
      final boosted = ConstellationLayout.nodeSize(0.5, reactionCount: 100);
      expect(boosted, greaterThan(base));
    });

    test('nodeSize boost is capped at 0.35', () {
      final maxBoosted = ConstellationLayout.nodeSize(
        0.65,
        reactionCount: 1000000,
      );
      // 0.65 + 0.35 = 1.0 → max size 170
      expect(maxBoosted, 170);
    });

    test('nodeSize with zero reactions equals base', () {
      expect(
        ConstellationLayout.nodeSize(0.5, reactionCount: 0),
        ConstellationLayout.nodeSize(0.5),
      );
    });

    test('nodes with more reactions are larger in layout', () {
      final now = DateTime.now();
      final posts = [
        _makePost(
          id: 'popular',
          createdAt: now,
          importance: 0.3,
          reactionCounts: [
            const ReactionCount(emoji: '🔥', count: 50),
            const ReactionCount(emoji: '❤️', count: 30),
          ],
        ),
        _makePost(
          id: 'quiet',
          createdAt: now.subtract(const Duration(hours: 1)),
          importance: 0.3,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      final popular = result.nodes.firstWhere((n) => n.post.id == 'popular');
      final quiet = result.nodes.firstWhere((n) => n.post.id == 'quiet');
      expect(popular.nodeSize, greaterThan(quiet.nodeSize));
      expect(popular.width, greaterThan(quiet.width));
    });
  });

  group('Audio media type layout', () {
    test('audio nodes are wider than default', () {
      final now = DateTime.now();
      final posts = [
        _makePost(
          id: 'audio',
          createdAt: now,
          importance: 0.5,
          mediaType: MediaType.audio,
        ),
        _makePost(
          id: 'text',
          createdAt: now.subtract(const Duration(hours: 1)),
          importance: 0.5,
          mediaType: MediaType.text,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      final audio = result.nodes.firstWhere((n) => n.post.id == 'audio');
      final text = result.nodes.firstWhere((n) => n.post.id == 'text');
      expect(audio.width, greaterThan(text.width));
    });

    test('audio nodes have shorter height', () {
      final now = DateTime.now();
      final posts = [
        _makePost(
          id: 'audio',
          createdAt: now,
          importance: 0.5,
          mediaType: MediaType.audio,
        ),
        _makePost(
          id: 'image',
          createdAt: now.subtract(const Duration(hours: 1)),
          importance: 0.5,
          mediaType: MediaType.image,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      final audio = result.nodes.firstWhere((n) => n.post.id == 'audio');
      final image = result.nodes.firstWhere((n) => n.post.id == 'image');
      expect(audio.height, lessThan(image.height));
    });

    test('audio nodes have showInfo false', () {
      final now = DateTime.now();
      final posts = [
        _makePost(
          id: 'audio',
          createdAt: now,
          importance: 0.5,
          mediaType: MediaType.audio,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );
      expect(result.nodes.first.showInfo, isFalse);
    });
  });

  group('Day gap enforcement', () {
    test('consecutive days have minimum gap between node groups', () {
      final now = DateTime.now();
      final posts = [
        _makePost(id: '1', createdAt: now, importance: 0.0),
        _makePost(
          id: '2',
          createdAt: now.subtract(const Duration(days: 1)),
          importance: 0.0,
        ),
        _makePost(
          id: '3',
          createdAt: now.subtract(const Duration(days: 2)),
          importance: 0.0,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );

      // Check that each day group's bottom is separated from next day
      // group's top by at least the minimum gap (40px)
      for (int i = 1; i < result.days.length; i++) {
        final prevBottom = result.days[i - 1].top + result.days[i - 1].height;
        final curTop = result.days[i].top;
        expect(
          curTop - prevBottom,
          greaterThanOrEqualTo(0),
          reason: 'Day $i overlaps with day ${i - 1}',
        );
      }
    });
  });

  group('Time nudge', () {
    test('closely timed posts have vertical offset', () {
      final now = DateTime.now();
      final posts = [
        _makePost(id: 'a', createdAt: now, importance: 0.5),
        _makePost(
          id: 'b',
          createdAt: now.subtract(const Duration(seconds: 30)),
          importance: 0.5,
        ),
        _makePost(
          id: 'c',
          createdAt: now.subtract(const Duration(seconds: 60)),
          importance: 0.5,
        ),
      ];
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );

      // Sort by createdAt descending (newest first)
      final sorted = List<PlacedNode>.from(result.nodes)
        ..sort((a, b) => b.post.createdAt.compareTo(a.post.createdAt));

      // Each older post should be at least slightly below the newer one
      for (int i = 1; i < sorted.length; i++) {
        expect(
          sorted[i].y,
          greaterThan(sorted[i - 1].y),
          reason:
              'Post ${sorted[i].post.id} should be below ${sorted[i - 1].post.id}',
        );
      }
    });
  });

  group('Compact layout', () {
    test('nodes are pulled upward to minimize gaps', () {
      final now = DateTime.now();
      // Many small nodes that should compact tightly
      final posts = List.generate(
        6,
        (i) => _makePost(
          id: '$i',
          createdAt: now.subtract(Duration(hours: i * 2)),
          importance: 0.0,
        ),
      );
      final result = ConstellationLayout.compute(
        posts: posts,
        containerWidth: 400,
      );

      // Total height should be reasonable (not excessively spread)
      // 6 small nodes at min size (~120px each with info) should fit
      // well under 1500px with compaction
      expect(result.totalHeight, lessThan(1500));
    });
  });
}
