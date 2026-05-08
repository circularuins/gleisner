import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/providers/guardian_provider.dart';

/// Mock Link for the GraphQL-error scenario.
///
/// Only the error path is exercised here — `data` is never read by the
/// caller because graphql_flutter short-circuits to `result.exception`
/// when `errors` is present. Keeping the field caused
/// `unused_element_parameter` to fire under `flutter analyze` (which
/// includes `test/`); the success-path link is `_DispatchLink` below.
class _MockLink extends Link {
  final List<GraphQLError>? errors;

  _MockLink({this.errors});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    return Stream.value(Response(errors: errors, response: {}));
  }
}

/// Mock Link that dispatches based on the presence of the `childId` variable:
/// - with childId → mutation response
/// - without childId → query (myChildren) response
class _DispatchLink extends Link {
  final Map<String, dynamic> mutationData;
  final Map<String, dynamic> queryData;

  _DispatchLink({required this.mutationData, required this.queryData});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    final data = request.variables.containsKey('childId')
        ? mutationData
        : queryData;
    return Stream.value(Response(data: data, response: {}));
  }
}

/// Client for success scenarios — mutation uses noCache to avoid
/// CacheMisconfigurationException; the query re-fetch uses its own data.
GraphQLClient _clientForSuccess({
  required Map<String, dynamic> mutationData,
  required Map<String, dynamic> queryData,
}) => GraphQLClient(
  link: _DispatchLink(mutationData: mutationData, queryData: queryData),
  cache: GraphQLCache(store: InMemoryStore()),
  // Skip cache writes for mutations to avoid CacheMisconfigurationException
  // when test data doesn't match InMemoryStore normalization expectations.
  defaultPolicies: DefaultPolicies(
    mutate: Policies(fetch: FetchPolicy.noCache),
  ),
);

/// Client for error scenarios (always returns errors).
GraphQLClient _clientWithErrors(List<GraphQLError> errors) => GraphQLClient(
  link: _MockLink(errors: errors),
  cache: GraphQLCache(store: InMemoryStore()),
  defaultPolicies: DefaultPolicies(
    mutate: Policies(fetch: FetchPolicy.noCache),
  ),
);

/// Minimal child user map returned by setChildProfileVisibility mutation.
/// Includes __typename so InMemoryStore can normalize the cache entry when
/// loadChildren uses FetchPolicy.networkOnly.
Map<String, dynamic> _childUserMap({
  String id = 'child-1',
  String profileVisibility = 'public',
}) => {
  '__typename': 'User',
  'id': id,
  'did': 'did:test',
  'email': null,
  'username': 'kiddo',
  'displayName': 'Kiddo',
  'bio': null,
  'avatarUrl': null,
  'profileVisibility': profileVisibility,
  'publicKey': 'pk',
  'birthYearMonth': '2020-01',
  'isChildAccount': true,
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
};

void main() {
  group('setChildProfileVisibility', () {
    test('returns true on success', () async {
      final client = _clientForSuccess(
        mutationData: {'setChildProfileVisibility': _childUserMap()},
        queryData: {'myChildren': <dynamic>[]},
      );

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(guardianProvider.notifier)
          .setChildProfileVisibility(
            childId: 'child-1',
            profileVisibility: 'public',
          );

      expect(ok, isTrue);
    });

    test('returns false on graphql error and sets state.error', () async {
      final client = _clientWithErrors(const [
        GraphQLError(message: 'Child account not found'),
      ]);

      final container = ProviderContainer(
        overrides: [graphqlClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(guardianProvider.notifier)
          .setChildProfileVisibility(
            childId: 'unknown',
            profileVisibility: 'public',
          );

      expect(ok, isFalse);
      final state = container.read(guardianProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test(
      'reflects updated profileVisibility after successful mutation',
      () async {
        final client = _clientForSuccess(
          mutationData: {
            'setChildProfileVisibility': _childUserMap(
              profileVisibility: 'public',
            ),
          },
          queryData: {
            '__typename': 'Query',
            'myChildren': [_childUserMap(profileVisibility: 'public')],
          },
        );

        final container = ProviderContainer(
          overrides: [graphqlClientProvider.overrideWithValue(client)],
        );
        addTearDown(container.dispose);

        final ok = await container
            .read(guardianProvider.notifier)
            .setChildProfileVisibility(
              childId: 'child-1',
              profileVisibility: 'public',
            );

        expect(ok, isTrue);
        final state = container.read(guardianProvider);
        expect(state.children.first.profileVisibility, 'public');
      },
    );
  });
}
