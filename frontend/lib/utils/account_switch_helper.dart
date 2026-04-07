import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/discover_provider.dart';
import '../providers/my_artist_provider.dart';
import '../providers/timeline_provider.dart';
import '../providers/tune_in_provider.dart';
import '../providers/unassigned_posts_provider.dart';

/// Reload all user-specific providers after a JWT switch (guardian ↔ child).
///
/// Each provider's load() method resets state internally and fetches with
/// networkOnly, so explicit invalidate is not needed (and would cause
/// redundant state resets).
Future<void> reloadAfterAccountSwitch(WidgetRef ref) async {
  // myArtistProvider must complete first — timeline depends on the result
  await ref.read(myArtistProvider.notifier).load();

  final myArtist = ref.read(myArtistProvider);
  if (myArtist != null) {
    ref.read(timelineProvider.notifier).loadArtist(myArtist.artistUsername);
  }
  ref.read(discoverProvider.notifier).loadInitial();
  ref.read(tuneInProvider.notifier).loadMyTuneIns();
  ref.read(unassignedPostsProvider.notifier).load();
}
