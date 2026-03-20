import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/artist.dart';
import '../graphql/queries/post.dart';
import '../models/artist.dart';
import '../models/post.dart';
import '../models/track.dart';
import '../utils/sentinel.dart';

class TimelineState {
  final Artist? artist;
  final Track? selectedTrack;
  final List<Post> posts;
  final bool isLoading;
  final String? error;

  const TimelineState({
    this.artist,
    this.selectedTrack,
    this.posts = const [],
    this.isLoading = false,
    this.error,
  });

  TimelineState copyWith({
    Object? artist = sentinel,
    Object? selectedTrack = sentinel,
    List<Post>? posts,
    bool? isLoading,
    String? error,
  }) {
    return TimelineState(
      artist: artist == sentinel ? this.artist : artist as Artist?,
      selectedTrack: selectedTrack == sentinel
          ? this.selectedTrack
          : selectedTrack as Track?,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  final GraphQLClient _client;

  TimelineNotifier(this._client) : super(const TimelineState());

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
          selectedTrack: null,
          posts: [],
        );
        return;
      }

      final artist = Artist.fromJson(data as Map<String, dynamic>);
      // Preserve current track selection if it still exists in the new data
      final currentTrack = state.selectedTrack;
      final preservedTrack = currentTrack != null
          ? artist.tracks.where((t) => t.id == currentTrack.id).firstOrNull
          : null;
      final activeTrack =
          preservedTrack ??
          (artist.tracks.isNotEmpty ? artist.tracks.first : null);

      // Keep isLoading true if we're about to load posts
      state = state.copyWith(
        artist: artist,
        selectedTrack: activeTrack,
        isLoading: activeTrack != null,
      );

      if (activeTrack != null) {
        await loadPosts(activeTrack.id);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectTrack(Track track) async {
    state = state.copyWith(selectedTrack: track, posts: []);
    await loadPosts(track.id);
  }

  Future<void> loadPosts(String trackId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(postsQuery),
          variables: {'trackId': trackId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        state = state.copyWith(
          isLoading: false,
          error:
              result.exception?.graphqlErrors.firstOrNull?.message ??
              'Failed to load posts',
        );
        return;
      }

      final postsData = result.data?['posts'] as List<dynamic>? ?? [];
      final posts = postsData
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList();

      state = state.copyWith(posts: posts, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    final track = state.selectedTrack;
    if (track != null) {
      await loadPosts(track.id);
    }
  }
}

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>(
  (ref) {
    final client = ref.watch(graphqlClientProvider);
    return TimelineNotifier(client);
  },
);
