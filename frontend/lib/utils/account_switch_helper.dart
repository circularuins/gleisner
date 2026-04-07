import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/discover_provider.dart';
import '../providers/my_artist_provider.dart';
import '../providers/timeline_provider.dart';
import '../providers/tune_in_provider.dart';
import '../providers/unassigned_posts_provider.dart';

/// Reload all user-specific providers after a JWT switch (guardian ↔ child).
///
/// `invalidate` is required because each Notifier caches the GraphQL client
/// via `ref.watch(graphqlClientProvider)` in its `build()` method. After
/// `graphqlClientProvider` is invalidated (by guardianProvider), other
/// Notifiers still hold the old client reference until they are themselves
/// invalidated and rebuilt.
///
/// After invalidation, explicit `load()` calls are needed because
/// StatefulShellRoute tabs don't auto-refresh on invalidate alone.
Future<void> reloadAfterAccountSwitch(WidgetRef ref) async {
  // Invalidate to force Notifier rebuild with new GraphQL client
  ref.invalidate(myArtistProvider);
  ref.invalidate(timelineProvider);
  ref.invalidate(tuneInProvider);
  ref.invalidate(discoverProvider);
  ref.invalidate(unassignedPostsProvider);

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
