import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/artist.dart';
import '../models/artist.dart';
import 'disposable_notifier.dart';

/// Caches the authenticated user's own artist profile.
/// Separate from timelineProvider which holds the currently *viewed* artist.
class MyArtistNotifier extends Notifier<Artist?> with DisposableNotifier {
  late GraphQLClient _client;

  @override
  Artist? build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
    return null;
  }

  Future<void> load() async {
    try {
      final result = await _client.query(
        QueryOptions(document: gql(myArtistQuery)),
      );
      if (disposed) return;
      final data = result.data?['myArtist'];
      state = data != null
          ? Artist.fromJson(data as Map<String, dynamic>)
          : null;
    } catch (e) {
      debugPrint('[MyArtist] load error: $e');
    }
  }
}

final myArtistProvider = NotifierProvider<MyArtistNotifier, Artist?>(
  MyArtistNotifier.new,
);
