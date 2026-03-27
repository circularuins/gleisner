import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/artist.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import 'disposable_notifier.dart';

class DiscoverState {
  final List<Artist> artists;
  final List<Genre> genres;
  final Genre? selectedGenre;
  final String searchQuery;
  final bool isLoading;
  final String? error;

  const DiscoverState({
    this.artists = const [],
    this.genres = const [],
    this.selectedGenre,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
  });

  DiscoverState copyWith({
    List<Artist>? artists,
    List<Genre>? genres,
    Genre? selectedGenre,
    bool clearGenre = false,
    String? searchQuery,
    bool? isLoading,
    String? error,
  }) {
    return DiscoverState(
      artists: artists ?? this.artists,
      genres: genres ?? this.genres,
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DiscoverNotifier extends Notifier<DiscoverState> with DisposableNotifier {
  late GraphQLClient _client;

  @override
  DiscoverState build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
    return const DiscoverState();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load genres and artists in parallel
      final results = await Future.wait([
        _client.query(QueryOptions(document: gql(genresQuery))),
        _client.query(
          QueryOptions(
            document: gql(discoverArtistsQuery),
            variables: const {'limit': 20},
            fetchPolicy: FetchPolicy.networkOnly,
          ),
        ),
      ]);

      if (disposed) return;

      final genreResult = results[0];
      final artistResult = results[1];

      final genres = <Genre>[];
      if (!genreResult.hasException && genreResult.data?['genres'] != null) {
        for (final g in genreResult.data!['genres'] as List) {
          final genre = Genre.fromJson(g as Map<String, dynamic>);
          if (genre.isPromoted) genres.add(genre);
        }
      }

      final artists = <Artist>[];
      if (!artistResult.hasException &&
          artistResult.data?['discoverArtists'] != null) {
        for (final a in artistResult.data!['discoverArtists'] as List) {
          artists.add(Artist.fromJson(a as Map<String, dynamic>));
        }
      }

      state = state.copyWith(
        genres: genres,
        artists: artists,
        isLoading: false,
      );
    } catch (e) {
      if (disposed) return;
      debugPrint('[Discover] loadInitial error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load artists. Please try again.',
      );
    }
  }

  Future<void> selectGenre(Genre? genre) async {
    if (genre?.id == state.selectedGenre?.id) {
      // Deselect
      state = state.copyWith(clearGenre: true, isLoading: true);
    } else {
      state = state.copyWith(selectedGenre: genre, isLoading: true);
    }

    await _fetchArtists();
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query, isLoading: true);
    await _fetchArtists();
  }

  Future<void> _fetchArtists() async {
    try {
      final variables = <String, dynamic>{'limit': 20};
      if (state.selectedGenre != null) {
        variables['genreId'] = state.selectedGenre!.id;
      }
      if (state.searchQuery.isNotEmpty) {
        variables['query'] = state.searchQuery;
      }

      final result = await _client.query(
        QueryOptions(
          document: gql(discoverArtistsQuery),
          variables: variables,
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (disposed) return;

      if (result.hasException) {
        debugPrint('[Discover] fetch error: ${result.exception}');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load artists.',
        );
        return;
      }

      final artists = <Artist>[];
      for (final a in result.data!['discoverArtists'] as List) {
        artists.add(Artist.fromJson(a as Map<String, dynamic>));
      }

      state = state.copyWith(artists: artists, isLoading: false, error: null);
    } catch (e) {
      if (disposed) return;
      debugPrint('[Discover] fetch error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load artists.',
      );
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _fetchArtists();
  }
}

final discoverProvider = NotifierProvider<DiscoverNotifier, DiscoverState>(
  DiscoverNotifier.new,
);
