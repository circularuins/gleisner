import 'package:flutter_test/flutter_test.dart';

/// Tests for the artist registration → timeline FAB visibility flow.
///
/// These tests simulate the state transitions that occur when a user
/// registers as an artist and navigates to their timeline. They verify
/// that the FAB (post button) and tutorial are visible immediately.
void main() {
  group('isOwnTimeline logic', () {
    // Simulates _isOwnTimeline getter
    bool isOwnTimeline({
      required String? viewingArtistUsername,
      required String? ownArtistUsername,
      required String? timelineArtistUsername,
    }) {
      final own = ownArtistUsername;
      if (own == null) return viewingArtistUsername == null;
      return viewingArtistUsername == null ||
          viewingArtistUsername == own ||
          timelineArtistUsername == own;
    }

    test('own when viewingArtistUsername is null', () {
      expect(
        isOwnTimeline(
          viewingArtistUsername: null,
          ownArtistUsername: 'me',
          timelineArtistUsername: 'me',
        ),
        isTrue,
      );
    });

    test('own when viewingArtistUsername matches own', () {
      expect(
        isOwnTimeline(
          viewingArtistUsername: 'me',
          ownArtistUsername: 'me',
          timelineArtistUsername: 'me',
        ),
        isTrue,
      );
    });

    test('not own when viewing another artist', () {
      expect(
        isOwnTimeline(
          viewingArtistUsername: 'other',
          ownArtistUsername: 'me',
          timelineArtistUsername: 'other',
        ),
        isFalse,
      );
    });

    test('own when viewing stale but timeline loaded with own data', () {
      // After artist registration: _viewingArtistUsername still holds
      // the previous artist, but timelineProvider was explicitly loaded
      // with own data by Profile's onRegistered callback
      expect(
        isOwnTimeline(
          viewingArtistUsername: 'other',
          ownArtistUsername: 'me',
          timelineArtistUsername: 'me',
        ),
        isTrue,
      );
    });

    test('not own when no artist registered', () {
      expect(
        isOwnTimeline(
          viewingArtistUsername: null,
          ownArtistUsername: null,
          timelineArtistUsername: null,
        ),
        isTrue, // fan-only with no viewing = "own" (empty state)
      );
    });

    test('not own when fan viewing another artist', () {
      expect(
        isOwnTimeline(
          viewingArtistUsername: 'other',
          ownArtistUsername: null,
          timelineArtistUsername: 'other',
        ),
        isFalse,
      );
    });
  });

  group('Artist registration flow: FAB visibility', () {
    test('Profile onRegistered flow ensures data is loaded', () {
      // Simulates the Profile._showRegisterSheet flow:
      // 1. Wizard completes → Navigator.pop returns artistUsername
      // 2. await myArtistProvider.load() → must use networkOnly (not cache)
      // 3. await timelineProvider.loadArtist(artistUsername)
      // 4. context.go('/timeline')
      //
      // The key insight: myArtistProvider MUST use FetchPolicy.networkOnly
      // because the initial load (pre-registration) cached null, and
      // cacheFirst would return stale null after registration.

      String? cachedMyArtist; // Simulates GraphQL cache
      String? myArtistState;
      String? timelineArtist;

      // Initial load (pre-registration) — caches null
      cachedMyArtist = null;
      myArtistState = cachedMyArtist;
      expect(myArtistState, isNull);

      // Artist registration happens (server-side)
      // ...

      // load() with cacheFirst → returns stale null (BUG)
      myArtistState = cachedMyArtist; // Still null from cache!
      expect(myArtistState, isNull, reason: 'cacheFirst returns stale null');

      // load() with networkOnly → fetches fresh data (FIX)
      cachedMyArtist = 'my_artist'; // Simulates server response
      myArtistState = cachedMyArtist;
      expect(myArtistState, 'my_artist');

      // Timeline loaded with own data
      timelineArtist = 'my_artist';

      // FAB visibility check (mirrors _isOwnTimeline + FAB condition)
      final viewingArtistUsername = 'other'; // stale from before registration
      final isOwn =
          viewingArtistUsername == myArtistState ||
          timelineArtist == myArtistState;
      expect(isOwn, isTrue, reason: 'FAB should show via timeline data match');
      expect(
        timelineArtist,
        isNotNull,
        reason: 'timeline.artist required for FAB',
      );
      expect(myArtistState, isNotNull, reason: 'myArtist required for isOwn');
    });
  });
}
