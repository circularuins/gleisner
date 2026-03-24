import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/artist.dart';
import '../graphql/queries/post.dart';
import '../models/artist.dart';
import '../models/post.dart';
import '../utils/constellation_layout.dart';
import 'disposable_notifier.dart';
import 'timeline_provider.dart';

/// Timeline notifier for public (unauthenticated) viewing.
/// No backend mutations (createTrack, toggleReaction, etc.) — only read queries
/// and local UI state changes (track selection, constellation highlight).
/// Auto-disposed when no screen is watching, so /@alice → /@bob transitions
/// start fresh without stale data.
class PublicTimelineNotifier extends Notifier<TimelineState>
    with DisposableNotifier {
  late GraphQLClient _client;
  double _lastWidth = 0;

  @override
  TimelineState build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
    return const TimelineState();
  }

  Future<void> loadArtist(String username) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(artistQuery),
          variables: {'username': username},
        ),
      );

      if (disposed) return;

      if (result.hasException) {
        state = state.copyWith(
          isLoading: false,
          error: result.exception?.graphqlErrors.firstOrNull?.message ??
              'Failed to load artist',
        );
        return;
      }

      final data = result.data?['artist'];
      if (data == null) {
        state = state.copyWith(
          isLoading: false,
          artist: null,
          selectedTrackIds: {},
          posts: [],
          layout: null,
        );
        return;
      }

      final artist = Artist.fromJson(data as Map<String, dynamic>);
      final allIds = artist.tracks.map((t) => t.id).toSet();
      state = state.copyWith(
        artist: artist,
        selectedTrackIds: allIds,
        isLoading: artist.tracks.isNotEmpty,
      );

      if (artist.tracks.isNotEmpty) {
        await _loadSelectedPosts();
      }
    } catch (e) {
      if (disposed) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleTrack(String trackId) async {
    final ids = Set<String>.from(state.selectedTrackIds);
    if (ids.contains(trackId)) {
      ids.remove(trackId);
    } else {
      ids.add(trackId);
    }
    state = state.copyWith(selectedTrackIds: ids, layout: null);
    await _loadSelectedPosts();
  }

  Future<void> toggleAll() async {
    final artist = state.artist;
    if (artist == null) return;

    final Set<String> ids;
    if (state.allSelected) {
      ids = {};
    } else {
      ids = artist.tracks.map((t) => t.id).toSet();
    }
    state = state.copyWith(selectedTrackIds: ids, layout: null);
    await _loadSelectedPosts();
  }

  void computeLayout(double width) {
    _lastWidth = width;
    _recomputeLayout();
  }

  void showConstellation(Set<String> postIds) {
    state = state.copyWith(constellationPostIds: postIds);
  }

  void clearConstellation() {
    state = state.copyWith(constellationPostIds: null);
  }

  Future<void> refresh() async {
    await _loadSelectedPosts();
  }

  Future<void> _loadSelectedPosts() async {
    final artist = state.artist;
    if (artist == null) return;

    final trackIds = state.selectedTrackIds;
    if (trackIds.isEmpty) {
      state = state.copyWith(posts: [], isLoading: false, layout: null);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final futures = trackIds.map(
        (tid) => _client.query(
          QueryOptions(
            document: gql(postsQuery),
            variables: {'trackId': tid},
            fetchPolicy: FetchPolicy.networkOnly,
          ),
        ),
      );

      final results = await Future.wait(futures);

      if (disposed) return;

      final allPosts = <Post>[];
      var failedCount = 0;
      for (final result in results) {
        if (result.hasException) {
          failedCount++;
          continue;
        }
        final postsData = result.data?['posts'] as List<dynamic>? ?? [];
        allPosts.addAll(
          postsData.map((p) => Post.fromJson(p as Map<String, dynamic>)),
        );
      }

      final error = failedCount > 0
          ? 'Failed to load $failedCount of ${results.length} tracks'
          : null;
      state = state.copyWith(posts: allPosts, isLoading: false, error: error);
      _recomputeLayout();
    } catch (e) {
      if (disposed) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _recomputeLayout() {
    if (state.posts.isEmpty || _lastWidth == 0) {
      state = state.copyWith(layout: null);
      return;
    }
    final result = ConstellationLayout.compute(
      posts: state.posts,
      containerWidth: _lastWidth,
    );
    state = state.copyWith(layout: result);
  }
}

/// Auto-disposed when no screen is watching. Navigating away from the public
/// timeline resets state, preventing stale data on /@alice → /@bob transitions.
final publicTimelineProvider =
    NotifierProvider.autoDispose<PublicTimelineNotifier, TimelineState>(
  PublicTimelineNotifier.new,
);
