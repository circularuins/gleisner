// Widget tests for the `MarqueeTrackRail` UI.
//
// These cover the user-facing contract — chip rendering, tap callbacks,
// marquee → expand → marquee transitions, and the highlight pulse
// suppression under `MediaQuery.disableAnimations`. The marquee scroll
// animation itself is not asserted frame-by-frame (Flutter's test ticker
// makes that brittle); we verify only that the controller is started /
// stopped in the right modes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/models/track.dart';
import 'package:gleisner_web/widgets/timeline/marquee_track_rail.dart';

Track _track(String id, String name, [String color = '#888888']) =>
    Track(id: id, name: name, color: color, createdAt: DateTime(2026));

Post _post(String id, String trackId, DateTime createdAt) => Post(
  id: id,
  mediaType: MediaType.thought,
  importance: 0.5,
  createdAt: createdAt,
  updatedAt: createdAt,
  author: const PostAuthor(id: 'u1', username: 'tester'),
  trackId: trackId,
);

Widget _harness({
  required List<Track> tracks,
  required List<Post> posts,
  Set<String>? selectedTrackIds,
  bool allSelected = true,
  int shuffleSeed = 12345,
  double width = 360,
  void Function(String)? onToggleTrack,
  VoidCallback? onToggleAll,
  VoidCallback? onReshuffle,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(
        body: SizedBox(
          width: width,
          child: MarqueeTrackRail(
            tracks: tracks,
            posts: posts,
            selectedTrackIds:
                selectedTrackIds ?? tracks.map((t) => t.id).toSet(),
            allSelected: allSelected,
            shuffleSeed: shuffleSeed,
            onToggleTrack: onToggleTrack ?? (_) {},
            onToggleAll: onToggleAll ?? () {},
            onReshuffle: onReshuffle ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('MarqueeTrackRail', () {
    testWidgets('renders the "All" chip plus every track in static mode', (
      tester,
    ) async {
      final tracks = [_track('t1', 'Music'), _track('t2', 'Art')];
      await tester.pumpWidget(
        _harness(tracks: tracks, posts: const [], width: 600),
      );
      await tester.pump();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Art'), findsOneWidget);
    });

    testWidgets('tap on the "All" chip fires onToggleAll', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          tracks: [_track('t1', 'A')],
          posts: const [],
          width: 600,
          onToggleAll: () => taps++,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('All'));
      expect(taps, 1);
    });

    testWidgets('tap on a track chip fires onToggleTrack with the track id', (
      tester,
    ) async {
      String? toggledId;
      await tester.pumpWidget(
        _harness(
          tracks: [_track('t1', 'A'), _track('t2', 'B')],
          posts: const [],
          width: 600,
          onToggleTrack: (id) => toggledId = id,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('B'));
      expect(toggledId, 't2');
    });

    testWidgets('overflow → marquee mode wraps tracks in a Tooltip area', (
      tester,
    ) async {
      // 12 wide track labels at a narrow viewport guarantees overflow even
      // before TextPainter measures the exact pixel widths.
      final tracks = [
        for (var i = 0; i < 12; i++) _track('t$i', 'LongTrackName$i'),
      ];
      await tester.pumpWidget(
        _harness(tracks: tracks, posts: const [], width: 200),
      );
      await tester.pump();

      expect(find.byType(Tooltip), findsWidgets);
    });

    testWidgets('tapping the marquee area expands and reveals all tracks', (
      tester,
    ) async {
      final tracks = [
        for (var i = 0; i < 12; i++) _track('t$i', 'LongTrackName$i'),
      ];
      await tester.pumpWidget(
        _harness(tracks: tracks, posts: const [], width: 200),
      );
      await tester.pump();
      // Before tap: marquee viewport may not have laid out every chip on
      // screen depending on offset. After expand we assert all are present.
      await tester.tap(find.byType(Tooltip).first);
      await tester.pump();

      for (var i = 0; i < 12; i++) {
        expect(find.text('LongTrackName$i'), findsOneWidget);
      }
    });

    testWidgets('tapping a chip in the expanded view stays in expanded mode '
        '(so multiple tracks can be toggled before idle collapses)', (
      tester,
    ) async {
      final tracks = [
        for (var i = 0; i < 12; i++) _track('t$i', 'LongTrackName$i'),
      ];
      final toggled = <String>[];
      await tester.pumpWidget(
        _harness(
          tracks: tracks,
          posts: const [],
          width: 200,
          onToggleTrack: toggled.add,
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(Tooltip).first);
      await tester.pump();

      await tester.tap(find.text('LongTrackName3'));
      await tester.pump();
      await tester.tap(find.text('LongTrackName5'));
      await tester.pump();

      expect(toggled, ['t3', 't5']);
      // All chips still visible — rail did not collapse back to marquee.
      for (var i = 0; i < 12; i++) {
        expect(find.text('LongTrackName$i'), findsOneWidget);
      }
    });

    testWidgets('disableAnimations renders without throwing or hanging', (
      tester,
    ) async {
      final tracks = [
        for (var i = 0; i < 12; i++) _track('t$i', 'LongTrackName$i'),
      ];
      final posts = [
        _post('p1', 't0', DateTime.now().subtract(const Duration(hours: 2))),
      ];
      await tester.pumpWidget(
        _harness(
          tracks: tracks,
          posts: posts,
          width: 200,
          disableAnimations: true,
        ),
      );
      // Without reduced-motion, pumpAndSettle on an infinite marquee
      // would time out. Reduced-motion should let it complete because
      // the marquee never starts.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(MarqueeTrackRail), findsOneWidget);
    });

    testWidgets(
      'fresh tracks get a non-empty boxShadow; non-fresh tracks do not',
      (tester) async {
        final freshPost = _post(
          'p1',
          't1',
          DateTime.now().subtract(const Duration(hours: 1)),
        );
        await tester.pumpWidget(
          _harness(
            tracks: [_track('t1', 'A'), _track('t2', 'B')],
            posts: [freshPost],
            width: 600,
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // `find.byType(DecoratedBox)` is too lax — the base `_Chip`
        // also uses a DecoratedBox for its border, so the count is
        // never zero. We need to look specifically at DecoratedBoxes
        // that carry a non-empty `boxShadow`, which is the cue the
        // `_HighlightedChip` wrapper paints behind a fresh / active
        // chip. Exactly one chip is fresh (t1), so we expect exactly
        // one matching plate.
        final withShadow = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .where((d) {
              final dec = d.decoration;
              return dec is BoxDecoration &&
                  dec.boxShadow != null &&
                  dec.boxShadow!.isNotEmpty;
            })
            .toList();

        expect(
          withShadow,
          hasLength(1),
          reason: 'only t1 is fresh — only one highlighted plate expected',
        );
      },
    );
  });
}
