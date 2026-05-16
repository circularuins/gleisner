import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/create_post_draft_service.dart';

/// Service provider for the post-composer draft store.
///
/// `autoDispose` is intentional: the service eagerly resolves
/// `SharedPreferences.getInstance()` in its constructor and caches the
/// result for its lifetime. If a transient init failure leaves it
/// permanently no-op'd (e.g. a Web tab that briefly lost storage access),
/// re-opening the composer rebuilds the provider and gives storage another
/// chance. The service itself is cheap to construct.
///
/// Override in tests with an in-memory [SharedPreferences]
/// (see test/services/create_post_draft_service_test.dart).
final createPostDraftServiceProvider =
    Provider.autoDispose<CreatePostDraftService>(
      (ref) => CreatePostDraftService(),
    );
