import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_provider.dart';

/// Tracks which tutorials the user has seen.
/// Persists via FlutterSecureStorage so tutorials show only once.
///
/// State includes `isLoaded` flag to prevent showing tutorials
/// before persisted data is loaded (avoids flash-then-hide UX).
class TutorialState {
  final Set<String> seen;
  final bool isLoaded;

  const TutorialState({this.seen = const {}, this.isLoaded = false});
}

class TutorialNotifier extends Notifier<TutorialState> {
  late FlutterSecureStorage _storage;

  static const _storageKey = 'seen_tutorials';
  bool _resetPending = false;

  @override
  TutorialState build() {
    _storage = ref.watch(secureStorageProvider);
    _resetPending = false;
    _loadSeen();
    return const TutorialState(); // isLoaded: false until _loadSeen completes
  }

  Future<void> _loadSeen() async {
    final raw = await _storage.read(key: _storageKey);
    if (_resetPending) return;
    if (raw != null && raw.isNotEmpty) {
      state = TutorialState(seen: raw.split(',').toSet(), isLoaded: true);
    } else {
      state = const TutorialState(isLoaded: true);
    }
  }

  Future<void> markSeen(String tutorialId) async {
    final newSeen = {...state.seen, tutorialId};
    state = TutorialState(seen: newSeen, isLoaded: true);
    await _storage.write(key: _storageKey, value: newSeen.join(','));
  }

  Future<void> reset() async {
    _resetPending = true;
    state = const TutorialState(isLoaded: true);
    await _storage.delete(key: _storageKey);
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialState>(
  TutorialNotifier.new,
);

/// Tutorial IDs — centralized to avoid typos.
class TutorialIds {
  static const firstPost = 'first_post';
}
