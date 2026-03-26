import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/artist.dart';
import '../models/artist.dart';
import '../models/post.dart';
import 'disposable_notifier.dart';

class ArtistPageState {
  final Artist? artist;
  final List<Post> recentPosts;
  final bool isLoading;
  final String? error;

  const ArtistPageState({
    this.artist,
    this.recentPosts = const [],
    this.isLoading = false,
    this.error,
  });

  ArtistPageState copyWith({
    Artist? artist,
    List<Post>? recentPosts,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearArtist = false,
  }) {
    return ArtistPageState(
      artist: clearArtist ? null : (artist ?? this.artist),
      recentPosts: recentPosts ?? this.recentPosts,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ArtistPageNotifier extends Notifier<ArtistPageState>
    with DisposableNotifier {
  late GraphQLClient _client;

  @override
  ArtistPageState build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
    return const ArtistPageState();
  }

  /// Reset state and load a new artist. Call when navigating to a different
  /// artist page to prevent stale data from the previous artist being shown.
  Future<void> loadArtist(String username) async {
    state = const ArtistPageState(isLoading: true);

    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(artistQuery),
          variables: {'username': username},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (disposed) return;

      if (result.hasException) {
        debugPrint('[ArtistPage] load error: ${result.exception}');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load artist.',
        );
        return;
      }

      final data = result.data?['artist'];
      if (data == null) {
        state = state.copyWith(isLoading: false, error: 'Artist not found.');
        return;
      }

      final artist = Artist.fromJson(data as Map<String, dynamic>);
      state = state.copyWith(artist: artist, isLoading: false);

      // Load recent posts after artist is loaded
      await _loadRecentPosts(artist.id);
    } catch (e) {
      if (disposed) return;
      debugPrint('[ArtistPage] load error: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to load artist.');
    }
  }

  Future<void> _loadRecentPosts(String artistId) async {
    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(artistRecentPostsQuery),
          variables: {'artistId': artistId, 'limit': 5},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (disposed) return;

      if (result.hasException || result.data?['artistPosts'] == null) {
        return; // Silently fail — recent posts are optional
      }

      final posts = (result.data!['artistPosts'] as List)
          .map((p) => Post.fromJson(p as Map<String, dynamic>))
          .toList();

      state = state.copyWith(recentPosts: posts);
    } catch (e) {
      if (disposed) return;
      debugPrint('[ArtistPage] loadRecentPosts error: $e');
    }
  }
}

final artistPageProvider =
    NotifierProvider<ArtistPageNotifier, ArtistPageState>(
      ArtistPageNotifier.new,
    );
