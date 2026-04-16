import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/artist.dart';
import 'disposable_notifier.dart';

/// Fetches the featured artist's username for the login/signup "Try it first" link.
/// No authentication required. Fetches once and caches the result.
class FeaturedArtistNotifier extends Notifier<String?> with DisposableNotifier {
  late GraphQLClient _client;
  bool _loaded = false;

  @override
  String? build() {
    _client = ref.watch(graphqlClientProvider);
    _loaded = false;
    initDisposable();
    return null;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(featuredArtistQuery),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (disposed) return;
      if (result.exception != null) {
        debugPrint('[FeaturedArtist] GraphQL error: ${result.exception}');
        _loaded = true; // Don't retry on error (avoid infinite requests)
        return;
      }
      final data = result.data?['featuredArtist'];
      if (data != null) {
        state = data['artistUsername'] as String;
      }
      _loaded = true;
    } catch (e) {
      debugPrint('[FeaturedArtist] load error: $e');
      _loaded = true; // Don't retry on error
    }
  }
}

final featuredArtistProvider =
    NotifierProvider<FeaturedArtistNotifier, String?>(
      FeaturedArtistNotifier.new,
    );
