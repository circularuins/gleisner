import 'package:flutter_test/flutter_test.dart';

import 'package:gleisner_web/providers/tune_in_provider.dart';

/// Pure logic tests for Timeline mode switching behavior.
/// These test the decision logic extracted from _TimelineScreenState,
/// without needing Widget/Provider infrastructure.

// ── Extracted logic functions (mirror _TimelineScreenState behavior) ──

/// Determines if the current view is the user's own timeline.
bool isOwnTimeline({
  required String? viewingArtistUsername,
  required String? ownArtistUsername,
}) {
  return viewingArtistUsername == null ||
      (ownArtistUsername != null && viewingArtistUsername == ownArtistUsername);
}

/// Decides what to show on initial load.
/// Returns (artistUsername to load, isOwn).
({String? artistToLoad, bool isOwn}) decideInitialTimeline({
  required String? ownArtistUsername,
  required List<TunedInArtist> tunedInArtists,
}) {
  if (ownArtistUsername != null) {
    return (artistToLoad: ownArtistUsername, isOwn: true);
  }
  if (tunedInArtists.isNotEmpty) {
    return (artistToLoad: tunedInArtists.first.artistUsername, isOwn: false);
  }
  return (artistToLoad: null, isOwn: true); // empty state
}

/// Decides what to show after Tune Out.
/// Returns the artistUsername to switch to, or null for empty state.
String? decideAfterTuneOut({
  required List<TunedInArtist> remainingArtists,
  required String? ownArtistUsername,
}) {
  if (remainingArtists.isNotEmpty) {
    return remainingArtists.first.artistUsername;
  }
  return ownArtistUsername; // null for fan-only → empty state
}

/// Decides whether the detail sheet should show mutation UI.
({bool showReactions, bool showConnections}) detailSheetPermissions({
  required String? viewingArtistUsername,
  required String? ownArtistUsername,
  required bool isAuthenticated,
}) {
  final isOwn = isOwnTimeline(
    viewingArtistUsername: viewingArtistUsername,
    ownArtistUsername: ownArtistUsername,
  );
  return (
    showReactions: isAuthenticated, // always for authenticated users
    showConnections: isOwn, // only on own timeline
  );
}

// ── Helpers ──

TunedInArtist _artist(String id, String username) {
  return TunedInArtist(
    id: id,
    artistUsername: username,
    tunedInCount: 0,
    tunedInAt: DateTime(2026),
  );
}

// ── Tests ──

void main() {
  group('isOwnTimeline', () {
    test('true when viewingArtistUsername is null (default)', () {
      expect(
        isOwnTimeline(viewingArtistUsername: null, ownArtistUsername: 'me'),
        isTrue,
      );
    });

    test('true when viewing own artist', () {
      expect(
        isOwnTimeline(viewingArtistUsername: 'me', ownArtistUsername: 'me'),
        isTrue,
      );
    });

    test('false when viewing another artist', () {
      expect(
        isOwnTimeline(viewingArtistUsername: 'other', ownArtistUsername: 'me'),
        isFalse,
      );
    });

    test('false for fan-only user viewing an artist', () {
      expect(
        isOwnTimeline(viewingArtistUsername: 'other', ownArtistUsername: null),
        isFalse,
      );
    });

    test('true for fan-only user with null viewing (empty state)', () {
      expect(
        isOwnTimeline(viewingArtistUsername: null, ownArtistUsername: null),
        isTrue,
      );
    });
  });

  group('decideInitialTimeline', () {
    test('artist user → loads own timeline', () {
      final result = decideInitialTimeline(
        ownArtistUsername: 'my_artist',
        tunedInArtists: [_artist('a1', 'artist1')],
      );
      expect(result.artistToLoad, 'my_artist');
      expect(result.isOwn, isTrue);
    });

    test('fan-only with tuned-in → loads first tuned-in artist', () {
      final result = decideInitialTimeline(
        ownArtistUsername: null,
        tunedInArtists: [_artist('a1', 'artist1'), _artist('a2', 'artist2')],
      );
      expect(result.artistToLoad, 'artist1');
      expect(result.isOwn, isFalse);
    });

    test('fan-only with no tuned-in → empty state', () {
      final result = decideInitialTimeline(
        ownArtistUsername: null,
        tunedInArtists: [],
      );
      expect(result.artistToLoad, isNull);
      expect(result.isOwn, isTrue);
    });

    test('artist user with no tuned-in → still loads own', () {
      final result = decideInitialTimeline(
        ownArtistUsername: 'my_artist',
        tunedInArtists: [],
      );
      expect(result.artistToLoad, 'my_artist');
      expect(result.isOwn, isTrue);
    });
  });

  group('decideAfterTuneOut', () {
    test('remaining artists → switch to first remaining', () {
      final result = decideAfterTuneOut(
        remainingArtists: [_artist('a2', 'artist2'), _artist('a3', 'artist3')],
        ownArtistUsername: 'me',
      );
      expect(result, 'artist2');
    });

    test('no remaining + artist user → switch to own', () {
      final result = decideAfterTuneOut(
        remainingArtists: [],
        ownArtistUsername: 'me',
      );
      expect(result, 'me');
    });

    test('no remaining + fan-only → null (empty state)', () {
      final result = decideAfterTuneOut(
        remainingArtists: [],
        ownArtistUsername: null,
      );
      expect(result, isNull);
    });

    test('sequential tune out: 3 → 2 → 1 → 0 (artist user)', () {
      var artists = [
        _artist('a1', 'artist1'),
        _artist('a2', 'artist2'),
        _artist('a3', 'artist3'),
      ];

      // Tune out artist1 → switch to artist2
      artists = artists.where((a) => a.id != 'a1').toList();
      expect(
        decideAfterTuneOut(remainingArtists: artists, ownArtistUsername: 'me'),
        'artist2',
      );

      // Tune out artist2 → switch to artist3
      artists = artists.where((a) => a.id != 'a2').toList();
      expect(
        decideAfterTuneOut(remainingArtists: artists, ownArtistUsername: 'me'),
        'artist3',
      );

      // Tune out artist3 → switch to own
      artists = artists.where((a) => a.id != 'a3').toList();
      expect(
        decideAfterTuneOut(remainingArtists: artists, ownArtistUsername: 'me'),
        'me',
      );
    });

    test('sequential tune out: 3 → 2 → 1 → 0 (fan-only)', () {
      var artists = [
        _artist('a1', 'artist1'),
        _artist('a2', 'artist2'),
        _artist('a3', 'artist3'),
      ];

      artists = artists.where((a) => a.id != 'a1').toList();
      expect(
        decideAfterTuneOut(remainingArtists: artists, ownArtistUsername: null),
        'artist2',
      );

      artists = artists.where((a) => a.id != 'a2').toList();
      expect(
        decideAfterTuneOut(remainingArtists: artists, ownArtistUsername: null),
        'artist3',
      );

      artists = artists.where((a) => a.id != 'a3').toList();
      expect(
        decideAfterTuneOut(remainingArtists: artists, ownArtistUsername: null),
        isNull,
      );
    });
  });

  group('detailSheetPermissions', () {
    test('own timeline: reactions + connections', () {
      final p = detailSheetPermissions(
        viewingArtistUsername: null,
        ownArtistUsername: 'me',
        isAuthenticated: true,
      );
      expect(p.showReactions, isTrue);
      expect(p.showConnections, isTrue);
    });

    test('fan mode: reactions only, no connections', () {
      final p = detailSheetPermissions(
        viewingArtistUsername: 'other',
        ownArtistUsername: 'me',
        isAuthenticated: true,
      );
      expect(p.showReactions, isTrue);
      expect(p.showConnections, isFalse);
    });

    test('fan-only viewing artist: reactions only', () {
      final p = detailSheetPermissions(
        viewingArtistUsername: 'other',
        ownArtistUsername: null,
        isAuthenticated: true,
      );
      expect(p.showReactions, isTrue);
      expect(p.showConnections, isFalse);
    });

    test('unauthenticated: nothing', () {
      final p = detailSheetPermissions(
        viewingArtistUsername: 'other',
        ownArtistUsername: null,
        isAuthenticated: false,
      );
      expect(p.showReactions, isFalse);
      expect(p.showConnections, isFalse);
    });
  });
}
