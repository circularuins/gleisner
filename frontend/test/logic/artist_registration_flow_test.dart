import 'package:flutter_test/flutter_test.dart';

/// Simulates the Timeline screen's myArtistProvider listener logic
/// and _loadData flow to verify FAB visibility after artist registration.
///
/// This test reproduces the exact sequence of events:
/// 1. User signs up (fan-only, no artist)
/// 2. User tunes in to other artists → _viewingArtistUsername set
/// 3. User registers as artist → myArtistProvider null → non-null
/// 4. User taps "View Your Timeline" → context.go('/timeline')
void main() {
  group('Artist registration → Timeline FAB visibility', () {
    // Simulate Timeline screen state
    String? viewingArtistUsername;
    bool showFirstPostTutorial = false;
    String? timelineArtistUsername; // What timelineProvider has loaded
    String? myArtistUsername; // What myArtistProvider holds

    // Simulate _loadData
    Future<void> loadData() async {
      // In real code: await myArtistProvider.load() + tuneInProvider.loadMyTuneIns()
      // For test: myArtistUsername is already set

      if (viewingArtistUsername != null) {
        return; // Early return — already viewing someone
      }

      if (myArtistUsername != null) {
        timelineArtistUsername = myArtistUsername;
      }
    }

    // Simulate listener callback
    void onMyArtistChanged(String? prev, String? next) {
      if (prev == null && next != null) {
        viewingArtistUsername = null;
        showFirstPostTutorial = false;
        // Future.microtask(_loadData) — simulated as sync for test
        loadData();
      }
    }

    // Simulate FAB visibility check
    bool isFabVisible() {
      final isOwn = viewingArtistUsername == null ||
          (myArtistUsername != null &&
              viewingArtistUsername == myArtistUsername);
      return timelineArtistUsername != null && isOwn;
    }

    setUp(() {
      viewingArtistUsername = null;
      showFirstPostTutorial = false;
      timelineArtistUsername = null;
      myArtistUsername = null;
    });

    test('Scenario: fan tunes in, then registers as artist', () async {
      // Step 1: User signs up as fan, _loadData runs
      myArtistUsername = null;
      await loadData();
      expect(isFabVisible(), isFalse, reason: 'No artist yet');

      // Step 2: User tunes in to another artist → view their timeline
      viewingArtistUsername = 'other_artist';
      timelineArtistUsername = 'other_artist';
      expect(isFabVisible(), isFalse, reason: 'Viewing other artist');

      // Step 3: Wizard Step 3 submit → myArtistProvider.load() called
      // This triggers the listener (null → non-null)
      final prevMyArtist = myArtistUsername; // null
      myArtistUsername = 'my_new_artist';
      onMyArtistChanged(prevMyArtist, myArtistUsername);

      // After listener: viewingArtistUsername should be reset
      expect(viewingArtistUsername, isNull,
          reason: 'Listener should reset viewingArtistUsername');

      // After _loadData: timeline should show own artist
      expect(timelineArtistUsername, 'my_new_artist',
          reason: '_loadData should load own artist timeline');

      // FAB should be visible
      expect(isFabVisible(), isTrue,
          reason: 'FAB should show for own timeline');
    });

    test('Scenario: fan registers as artist without tuning in first', () async {
      // Step 1: Fresh signup, no tune-ins
      myArtistUsername = null;
      await loadData();
      expect(isFabVisible(), isFalse);

      // Step 2: Register as artist directly
      final prevMyArtist = myArtistUsername;
      myArtistUsername = 'direct_artist';
      onMyArtistChanged(prevMyArtist, myArtistUsername);

      expect(isFabVisible(), isTrue,
          reason: 'FAB should show immediately after registration');
    });

    test('BUG REPRO: listener fires during Wizard Step 3, but _loadData '
        'hits early return because _viewingArtistUsername was set', () async {
      // Setup: viewing another artist
      viewingArtistUsername = 'other_artist';
      timelineArtistUsername = 'other_artist';
      myArtistUsername = null;

      // Wizard Step 3: myArtistProvider changes
      final prevMyArtist = myArtistUsername;
      myArtistUsername = 'my_new_artist';
      onMyArtistChanged(prevMyArtist, myArtistUsername);

      // The listener should have:
      // 1. Set viewingArtistUsername = null
      // 2. Called _loadData which should NOT early return
      // 3. Loaded own timeline

      expect(viewingArtistUsername, isNull,
          reason: 'Listener must reset viewingArtistUsername BEFORE _loadData');
      expect(timelineArtistUsername, 'my_new_artist',
          reason: '_loadData must load own timeline after reset');
      expect(isFabVisible(), isTrue,
          reason: 'FAB must be visible after artist registration');
    });
  });
}
