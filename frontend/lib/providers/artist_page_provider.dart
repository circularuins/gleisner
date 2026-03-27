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

      final jsonData = data as Map<String, dynamic>;
      final artist = Artist.fromJson(jsonData);

      // Parse recentPosts from the same query response (single RTT, #63)
      final recentPosts = (jsonData['recentPosts'] as List<dynamic>?)
              ?.map((p) => Post.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [];

      state = state.copyWith(
        artist: artist,
        recentPosts: recentPosts,
        isLoading: false,
      );
    } catch (e) {
      if (disposed) return;
      debugPrint('[ArtistPage] load error: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to load artist.');
    }
  }
}

final artistPageProvider =
    NotifierProvider<ArtistPageNotifier, ArtistPageState>(
      ArtistPageNotifier.new,
    );
