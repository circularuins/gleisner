import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/mutations/tune_in.dart';
import '../graphql/queries/artist.dart';
import 'disposable_notifier.dart';

/// Lightweight artist info for the avatar rail.
class TunedInArtist {
  final String id;
  final String artistUsername;
  final String? displayName;
  final String? avatarUrl;
  final int tunedInCount;
  final DateTime tunedInAt;

  const TunedInArtist({
    required this.id,
    required this.artistUsername,
    this.displayName,
    this.avatarUrl,
    required this.tunedInCount,
    required this.tunedInAt,
  });

  factory TunedInArtist.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>;
    return TunedInArtist(
      id: artist['id'] as String,
      artistUsername: artist['artistUsername'] as String,
      displayName: artist['displayName'] as String?,
      avatarUrl: artist['avatarUrl'] as String?,
      tunedInCount: artist['tunedInCount'] as int,
      tunedInAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class TuneInState {
  final List<TunedInArtist> tunedInArtists;
  final bool isLoading;
  final String? error;

  const TuneInState({
    this.tunedInArtists = const [],
    this.isLoading = false,
    this.error,
  });

  TuneInState copyWith({
    List<TunedInArtist>? tunedInArtists,
    bool? isLoading,
    String? error,
  }) {
    return TuneInState(
      tunedInArtists: tunedInArtists ?? this.tunedInArtists,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool isTunedIn(String artistId) {
    return tunedInArtists.any((a) => a.id == artistId);
  }
}

class TuneInNotifier extends Notifier<TuneInState> with DisposableNotifier {
  late GraphQLClient _client;

  @override
  TuneInState build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
    return const TuneInState();
  }

  Future<void> loadMyTuneIns() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(myTuneInsQuery),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (disposed) return;

      if (result.hasException) {
        debugPrint('[TuneIn] loadMyTuneIns error: ${result.exception}');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load tune-ins.',
        );
        return;
      }

      final list = <TunedInArtist>[];
      for (final item in result.data!['myTuneIns'] as List) {
        list.add(TunedInArtist.fromJson(item as Map<String, dynamic>));
      }

      state = state.copyWith(tunedInArtists: list, isLoading: false);
    } catch (e) {
      if (disposed) return;
      debugPrint('[TuneIn] loadMyTuneIns error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load tune-ins.',
      );
    }
  }

  /// Toggle Tune In for an artist. Returns true if now tuned in, false if tuned out.
  Future<bool> toggleTuneIn(String artistId) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(toggleTuneInMutation),
          variables: {'artistId': artistId},
        ),
      );

      if (disposed) return false;

      if (result.hasException) {
        debugPrint('[TuneIn] toggleTuneIn error: ${result.exception}');
        return false;
      }

      final data = result.data?['toggleTuneIn'];
      if (data == null) {
        // Tuned out (null response = removed)
        state = state.copyWith(
          tunedInArtists: state.tunedInArtists
              .where((a) => a.id != artistId)
              .toList(),
        );
        return false;
      } else {
        // Tuned in (got data back) — deduplicate to prevent race with loadMyTuneIns
        final newTuneIn = TunedInArtist.fromJson(data as Map<String, dynamic>);
        final filtered = state.tunedInArtists
            .where((a) => a.id != newTuneIn.id)
            .toList();
        state = state.copyWith(tunedInArtists: [...filtered, newTuneIn]);
        return true;
      }
    } catch (e) {
      debugPrint('[TuneIn] toggleTuneIn error: $e');
      return false;
    }
  }
}

final tuneInProvider = NotifierProvider<TuneInNotifier, TuneInState>(
  TuneInNotifier.new,
);
