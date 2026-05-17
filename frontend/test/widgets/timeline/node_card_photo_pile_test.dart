// Regression tests for the multi-image photo-pile rendering path in
// NodeCard. Single-image image posts must still render a single full-bleed
// thumbnail, multi-image posts must render one tile per image, and the
// `_maxLayers = 4` cap must hold for posts with more than four images.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/models/timeline_item.dart';
import 'package:gleisner_web/utils/constellation_layout.dart';
import 'package:gleisner_web/widgets/timeline/node_card.dart';

PostAuthor _author() => const PostAuthor(id: 'u1', username: 'test_user');

Post _imagePost({String id = 'p1', required int imageCount}) {
  return Post(
    id: id,
    mediaType: MediaType.image,
    importance: 0.4,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    author: _author(),
    trackColor: '#FF8B7355',
    media: List.generate(
      imageCount,
      (i) => PostMedia(
        id: 'm$i',
        mediaUrl: 'https://example.invalid/$id-$i.jpg',
        position: i,
      ),
    ),
  );
}

PlacedNode _nodeFor(Post post) => PlacedNode(
  item: PostItem(post),
  x: 0,
  y: 0,
  width: 160,
  height: 200,
  nodeSize: 160,
  mediaHeight: 140,
  showInfo: false,
);

Widget _host(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('NodeCard photo pile rendering', () {
    testWidgets('single-image post renders exactly one Image', (tester) async {
      final post = _imagePost(imageCount: 1);
      await tester.pumpWidget(_host(NodeCard(node: _nodeFor(post), index: 0)));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('multi-image post (3) renders one tile per image', (
      tester,
    ) async {
      final post = _imagePost(imageCount: 3);
      await tester.pumpWidget(_host(NodeCard(node: _nodeFor(post), index: 0)));
      await tester.pump();

      expect(find.byType(Image), findsNWidgets(3));
    });

    testWidgets('multi-image post (6) is capped at _maxLayers (4) tiles', (
      tester,
    ) async {
      final post = _imagePost(imageCount: 6);
      await tester.pumpWidget(_host(NodeCard(node: _nodeFor(post), index: 0)));
      await tester.pump();

      expect(find.byType(Image), findsNWidgets(4));
    });
  });
}
