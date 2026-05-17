// Regression tests for the multi-image photo-pile rendering path in
// NodeCard. Single-image image posts must still render a single full-bleed
// thumbnail, multi-image posts must render one tile per image, the
// `_maxLayers` cap must hold for posts with more than that many images, and
// the importance boundaries must not throw.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/models/timeline_item.dart';
import 'package:gleisner_web/utils/constellation_layout.dart';
import 'package:gleisner_web/widgets/timeline/node_card.dart';

PostAuthor _author() => const PostAuthor(id: 'u1', username: 'test_user');

/// Mirrors the private `_ScatteredPhotos._maxLayers` cap used by the
/// production widget. Kept here so the truncation assertion below names
/// the constraint instead of an opaque literal — keep these two in sync if
/// `_maxLayers` changes.
const int _expectedMaxLayers = 4;

Post _imagePost({
  String id = 'p1',
  required int imageCount,
  double importance = 0.4,
}) {
  return Post(
    id: id,
    mediaType: MediaType.image,
    importance: importance,
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

    testWidgets('multi-image post is capped at _maxLayers tiles', (
      tester,
    ) async {
      final post = _imagePost(imageCount: _expectedMaxLayers + 2);
      await tester.pumpWidget(_host(NodeCard(node: _nodeFor(post), index: 0)));
      await tester.pump();

      expect(find.byType(Image), findsNWidgets(_expectedMaxLayers));
    });

    // Boundary check: the glow / drop-shadow math in _PhotoTile scales with
    // `importance`. Exercise the 0.0 / 1.0 edges to catch regressions where
    // a coefficient flips negative or trips an alpha-out-of-range assertion.
    testWidgets('renders without crashing at importance boundaries', (
      tester,
    ) async {
      for (final imp in const [0.0, 1.0]) {
        final post = _imagePost(id: 'imp-$imp', imageCount: 3, importance: imp);
        await tester.pumpWidget(
          _host(NodeCard(node: _nodeFor(post), index: 0)),
        );
        await tester.pump();

        expect(find.byType(Image), findsNWidgets(3));
      }
    });
  });
}
