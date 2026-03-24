import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timeline_provider.dart';

/// A separate TimelineNotifier instance for public (unauthenticated) viewing.
/// Keeps state independent from the authenticated user's own timeline.
final publicTimelineProvider =
    NotifierProvider<TimelineNotifier, TimelineState>(TimelineNotifier.new);
