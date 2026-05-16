import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/create_post_draft_service.dart';

/// Singleton service provider. Override in tests with an in-memory
/// [SharedPreferences] (see test/services/create_post_draft_service_test.dart).
final createPostDraftServiceProvider = Provider<CreatePostDraftService>(
  (ref) => CreatePostDraftService(),
);
