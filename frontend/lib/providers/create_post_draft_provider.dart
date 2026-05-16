import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/create_post_draft_service.dart';

/// Service provider for the post-composer draft store.
///
/// **Keep-alive (NOT autoDispose) — intentional, revisited across reviews.**
///
/// We initially used `Provider.autoDispose` to let a transient init failure
/// (Web tab that briefly lost localStorage access) recover when the user
/// re-opens the composer. In practice that recovery path is dominated by
/// app restart — losing localStorage between two composer opens within a
/// single session is exceedingly rare — while autoDispose introduces a
/// subtler hazard: `auth_provider.logout()` calls `ref.read` on this
/// provider from outside the composer's lifecycle, which spawns a
/// "create → immediately-discarded" instance. Today the service has no
/// `dispose()` and the in-flight cleanup completes regardless, but the
/// moment the service grows a teardown hook we'd be staring at a
/// use-after-dispose bug.
///
/// Keep-alive is the simpler invariant. The trade-off is documented here
/// rather than encoded as autoDispose so the next reviewer doesn't flip it
/// back.
///
/// Override in tests with an in-memory [SharedPreferences]
/// (see test/services/create_post_draft_service_test.dart).
final createPostDraftServiceProvider = Provider<CreatePostDraftService>(
  (ref) => CreatePostDraftService(),
);
