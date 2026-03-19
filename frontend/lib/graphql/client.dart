import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../config/env.dart';

const _storage = FlutterSecureStorage();

GraphQLClient _createClient() {
  final link = AuthLink(
    getToken: () async {
      final token = await _storage.read(key: 'jwt');
      return token != null ? 'Bearer $token' : null;
    },
  ).concat(HttpLink(apiUrl));

  return GraphQLClient(
    link: link,
    cache: GraphQLCache(store: InMemoryStore()),
  );
}

final graphqlClientProvider = Provider<GraphQLClient>((ref) {
  return _createClient();
});

final graphqlClientNotifierProvider = Provider<ValueNotifier<GraphQLClient>>((
  ref,
) {
  final notifier = ValueNotifier(ref.read(graphqlClientProvider));
  ref.onDispose(notifier.dispose);
  return notifier;
});
