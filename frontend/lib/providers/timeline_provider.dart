import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/artist.dart';
import '../graphql/mutations/track.dart';
import '../graphql/queries/post.dart';
import '../models/artist.dart';
import '../models/post.dart';
import '../models/track.dart';
import '../utils/constellation_layout.dart';
import '../utils/sentinel.dart';

class TimelineState {
  final Artist? artist;
  final Set<String> selectedTrackIds;
  final List<Post> posts;
  final bool isLoading;
  final String? error;
  final LayoutResult? layout;
  final String? highlightPostId;

  const TimelineState({
    this.artist,
    this.selectedTrackIds = const {},
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.layout,
    this.highlightPostId,
  });

  bool get allSelected =>
      artist != null &&
      artist!.tracks.isNotEmpty &&
      selectedTrackIds.length == artist!.tracks.length;

  bool get noneSelected => selectedTrackIds.isEmpty;

  TimelineState copyWith({
    Object? artist = sentinel,
    Set<String>? selectedTrackIds,
    List<Post>? posts,
    bool? isLoading,
    Object? error = sentinel,
    Object? layout = sentinel,
    Object? highlightPostId = sentinel,
  }) {
    return TimelineState(
      artist: artist == sentinel ? this.artist : artist as Artist?,
      selectedTrackIds: selectedTrackIds ?? this.selectedTrackIds,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error == sentinel ? this.error : error as String?,
      layout: layout == sentinel ? this.layout : layout as LayoutResult?,
      highlightPostId: highlightPostId == sentinel
          ? this.highlightPostId
          : highlightPostId as String?,
    );
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  final GraphQLClient _client;
  double _lastWidth = 0;

  TimelineNotifier(this._client) : super(const TimelineState());

  /// For testing only — set state directly.
  @visibleForTesting
  void debugSetState(TimelineState newState) => state = newState;

  /// For testing only — add a track to state.
  @visibleForTesting
  void debugAddTrack(Track track) => _addTrackToState(track);

  Future<void> loadArtist(String username) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(artistQuery),
          variables: {'username': username},
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        state = state.copyWith(
          isLoading: false,
          error:
              result.exception?.graphqlErrors.firstOrNull?.message ??
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
      // Default: all tracks selected
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
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new track via API and add it to local state.
  /// Returns `(Track, null)` on success, `(null, errorMessage)` on failure.
  Future<(Track?, String?)> createTrack(String name, String color) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(createTrackMutation),
          variables: {'name': name, 'color': color},
        ),
      );

      if (result.hasException) {
        final message =
            result.exception?.graphqlErrors.firstOrNull?.message ??
            'Failed to create track';
        return (null, message);
      }

      final data = result.data?['createTrack'] as Map<String, dynamic>?;
      if (data == null) return (null, 'No data returned');

      final track = Track.fromJson(data);
      _addTrackToState(track);
      return (track, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  void _addTrackToState(Track track) {
    final artist = state.artist;
    if (artist == null) return;
    final updatedArtist = artist.withTrack(track);
    final ids = Set<String>.from(state.selectedTrackIds)..add(track.id);
    state = state.copyWith(artist: updatedArtist, selectedTrackIds: ids);
  }

  /// Add a single post to local state (optimistic/post-creation update).
  /// Update reaction counts for a post (called from detail sheet).
  void updatePostReactions(String postId, List<ReactionCount> counts) {
    final posts = state.posts.map((p) {
      if (p.id == postId) {
        return Post(
          id: p.id,
          mediaType: p.mediaType,
          title: p.title,
          body: p.body,
          mediaUrl: p.mediaUrl,
          duration: p.duration,
          importance: p.importance,
          layoutX: p.layoutX,
          layoutY: p.layoutY,
          contentHash: p.contentHash,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          author: p.author,
          trackId: p.trackId,
          trackName: p.trackName,
          trackColor: p.trackColor,
          reactionCounts: counts,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(posts: posts);
    _recomputeLayout();
  }

  void addPost(Post post) {
    final posts = [...state.posts, post];
    state = state.copyWith(posts: posts, highlightPostId: post.id);
    _recomputeLayout();
    // Clear highlight after animation completes
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted && state.highlightPostId == post.id) {
        state = state.copyWith(highlightPostId: null);
      }
    });
  }

  /// Add a track ID to selectedTrackIds without fetching (sync).
  void ensureTrackSelected(String trackId) {
    final ids = Set<String>.from(state.selectedTrackIds);
    if (!ids.contains(trackId)) {
      ids.add(trackId);
      state = state.copyWith(selectedTrackIds: ids);
    }
  }

  /// Toggle a single track on/off.
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

  /// Toggle all tracks: if all selected → deselect all, else select all.
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

      if (!mounted) return;

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
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // TODO: Move to Isolate.run() for large datasets (O(n^2) overlap check)
  void computeLayout(double width) {
    _lastWidth = width;
    _recomputeLayout();
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

  Future<void> refresh() async {
    await _loadSelectedPosts();
  }
}

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>(
  (ref) {
    final client = ref.watch(graphqlClientProvider);
    return TimelineNotifier(client);
  },
);
