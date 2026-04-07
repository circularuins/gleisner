import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/discover_provider.dart';
import '../providers/my_artist_provider.dart';
import '../providers/timeline_provider.dart';
import '../providers/tune_in_provider.dart';
import '../providers/unassigned_posts_provider.dart';

/// Reload all user-specific providers after a JWT switch (guardian ↔ child).
///
/// StatefulShellRoute tabs don't auto-refresh on invalidate alone,
/// so each provider must be explicitly reloaded.
Future<void> reloadAfterAccountSwitch(WidgetRef ref) async {
  ref.invalidate(myArtistProvider);
  ref.invalidate(timelineProvider);
  ref.invalidate(tuneInProvider);
  ref.invalidate(discoverProvider);
  ref.invalidate(unassignedPostsProvider);

  await ref.read(myArtistProvider.notifier).load();

  final myArtist = ref.read(myArtistProvider);
  if (myArtist != null) {
    ref.read(timelineProvider.notifier).loadArtist(myArtist.artistUsername);
  }
  ref.read(discoverProvider.notifier).loadInitial();
  ref.read(tuneInProvider.notifier).loadMyTuneIns();
}
