import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_provider.dart';

/// Tracks which tutorials the user has seen.
/// Persists via FlutterSecureStorage so tutorials show only once.
class TutorialNotifier extends Notifier<Set<String>> {
  late FlutterSecureStorage _storage;

  static const _storageKey = 'seen_tutorials';

  bool _resetPending = false;

  @override
  Set<String> build() {
    _storage = ref.watch(secureStorageProvider);
    _resetPending = false;
    _loadSeen();
    return {};
  }

  Future<void> _loadSeen() async {
    final raw = await _storage.read(key: _storageKey);
    // Skip if reset() was called while _loadSeen was in flight
    if (_resetPending) return;
    if (raw != null && raw.isNotEmpty) {
      state = raw.split(',').toSet();
    }
  }

  bool hasSeen(String tutorialId) => state.contains(tutorialId);

  Future<void> markSeen(String tutorialId) async {
    state = {...state, tutorialId};
    await _storage.write(key: _storageKey, value: state.join(','));
  }

  /// Reset all tutorials (e.g. on logout, so next user gets fresh tutorials).
  Future<void> reset() async {
    _resetPending = true;
    state = {};
    await _storage.delete(key: _storageKey);
  }
}

final tutorialProvider =
    NotifierProvider<TutorialNotifier, Set<String>>(TutorialNotifier.new);

/// Tutorial IDs — centralized to avoid typos.
class TutorialIds {
  static const firstPost = 'first_post';
  // Future tutorials:
  // static const firstTuneIn = 'first_tune_in';
  // static const avatarRail = 'avatar_rail';
}
