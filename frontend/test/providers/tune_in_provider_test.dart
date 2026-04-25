import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/providers/tune_in_provider.dart';

// ── Mock helpers ──

class _SequentialMockLink extends Link {
  final List<Map<String, dynamic>?> responses;
  int _index = 0;

  _SequentialMockLink(this.responses);

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    final data = _index < responses.length ? responses[_index] : null;
    _index++;
    return Stream.value(Response(data: data, response: {}));
  }
}

GraphQLClient _clientWithResponses(List<Map<String, dynamic>?> responses) {
  return GraphQLClient(
    link: _SequentialMockLink(responses),
    // Use no-cache to avoid __typename normalization issues in tests
    cache: GraphQLCache(store: InMemoryStore()),
    defaultPolicies: DefaultPolicies(
      mutate: Policies(fetch: FetchPolicy.noCache),
      query: Policies(fetch: FetchPolicy.noCache),
    ),
  );
}

ProviderContainer _createContainer({required GraphQLClient client}) {
  return ProviderContainer(
    overrides: [graphqlClientProvider.overrideWithValue(client)],
  );
}

Map<String, dynamic> _tuneInResponse(
  String id,
  String username,
  String name, {
  String profileVisibility = 'public',
}) {
  return {
    'toggleTuneIn': {
      'createdAt': '2026-01-01T00:00:00Z',
      'artist': {
        'id': id,
        'artistUsername': username,
        'displayName': name,
        'avatarUrl': null,
        'tunedInCount': 1,
        'profileVisibility': profileVisibility,
      },
    },
  };
}

Map<String, dynamic> _tuneOutResponse() {
  return {'toggleTuneIn': null};
}

Map<String, dynamic> _myTuneInsResponse(List<Map<String, dynamic>> artists) {
  return {
    '__typename': 'Query',
    'myTuneIns': artists
        .map(
          (a) => {
            '__typename': 'TuneIn',
            'createdAt': '2026-01-01T00:00:00Z',
            'artist': a,
          },
        )
        .toList(),
  };
}

Map<String, dynamic> _artistData(String id, String username, String name) {
  return {
    '__typename': 'Artist',
    'id': id,
    'artistUsername': username,
    'displayName': name,
    'avatarUrl': null,
    'tunedInCount': 1,
    // myTuneInsQuery selects profileVisibility — must be present in mock data
    // or graphql_flutter cache normalization throws PartialDataException.
    'profileVisibility': 'public',
  };
}

void main() {
  group('TuneInNotifier', () {
    group('toggleTuneIn', () {
      test('adds artist to list on Tune In', () async {
        final client = _clientWithResponses([
          _tuneInResponse('a1', 'artist1', 'Artist One'),
        ]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        final notifier = container.read(tuneInProvider.notifier);
        final result = await notifier.toggleTuneIn('a1');

        expect(result, isTrue);
        expect(container.read(tuneInProvider).tunedInArtists, hasLength(1));
        expect(
          container.read(tuneInProvider).tunedInArtists.first.artistUsername,
          'artist1',
        );
      });

      test('preserves profileVisibility on Tune In (private artist)', () async {
        // Regression: toggleTuneInMutation must select profileVisibility so
        // the local state reflects whether the tuned-in artist is private.
        // Without this, TunedInArtist.fromJson silently defaults to 'public'
        // and the avatar rail / `isPrivate` checks misclassify the artist
        // until the next loadMyTuneIns reconciles.
        final client = _clientWithResponses([
          _tuneInResponse(
            'a1',
            'artist1',
            'Artist One',
            profileVisibility: 'private',
          ),
        ]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        await container.read(tuneInProvider.notifier).toggleTuneIn('a1');

        final artist = container.read(tuneInProvider).tunedInArtists.first;
        expect(artist.profileVisibility, 'private');
        expect(artist.isPrivate, isTrue);
      });

      test('removes artist from list on Tune Out', () async {
        final client = _clientWithResponses([
          _tuneInResponse('a1', 'artist1', 'Artist One'),
          _tuneOutResponse(),
        ]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        final notifier = container.read(tuneInProvider.notifier);

        // Tune in first
        await notifier.toggleTuneIn('a1');
        expect(container.read(tuneInProvider).tunedInArtists, hasLength(1));

        // Tune out
        final result = await notifier.toggleTuneIn('a1');
        expect(result, isFalse);
        expect(container.read(tuneInProvider).tunedInArtists, isEmpty);
      });

      test('deduplicates on Tune In (prevents race condition)', () async {
        final client = _clientWithResponses([
          _tuneInResponse('a1', 'artist1', 'Artist One'),
          _tuneInResponse('a1', 'artist1', 'Artist One'),
        ]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        final notifier = container.read(tuneInProvider.notifier);
        await notifier.toggleTuneIn('a1');
        await notifier.toggleTuneIn('a1');

        // Should still be 1, not 2
        expect(container.read(tuneInProvider).tunedInArtists, hasLength(1));
      });

      test('only removes targeted artist, keeps others', () async {
        final client = _clientWithResponses([
          _tuneInResponse('a1', 'artist1', 'Artist One'),
          _tuneInResponse('a2', 'artist2', 'Artist Two'),
          _tuneInResponse('a3', 'artist3', 'Artist Three'),
          _tuneOutResponse(), // tune out a2
        ]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        final notifier = container.read(tuneInProvider.notifier);
        await notifier.toggleTuneIn('a1');
        await notifier.toggleTuneIn('a2');
        await notifier.toggleTuneIn('a3');
        expect(container.read(tuneInProvider).tunedInArtists, hasLength(3));

        // Tune out artist2
        await notifier.toggleTuneIn('a2');
        final remaining = container.read(tuneInProvider).tunedInArtists;
        expect(remaining, hasLength(2));
        expect(remaining.map((a) => a.id), containsAll(['a1', 'a3']));
        expect(remaining.map((a) => a.id), isNot(contains('a2')));
      });
    });

    group('loadMyTuneIns', () {
      test('replaces local state with server data', () async {
        final client = _clientWithResponses([
          _tuneInResponse('a1', 'artist1', 'Artist One'), // for toggleTuneIn
          _myTuneInsResponse([
            _artistData('a1', 'artist1', 'Artist One'),
            _artistData('a2', 'artist2', 'Artist Two'),
          ]),
        ]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        final notifier = container.read(tuneInProvider.notifier);

        // Local state has 1 artist
        await notifier.toggleTuneIn('a1');
        expect(container.read(tuneInProvider).tunedInArtists, hasLength(1));

        // Server returns 2 — replaces local state
        await notifier.loadMyTuneIns();
        expect(container.read(tuneInProvider).tunedInArtists, hasLength(2));
      });

      test('returns empty list when no tune-ins', () async {
        final client = _clientWithResponses([_myTuneInsResponse([])]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        await container.read(tuneInProvider.notifier).loadMyTuneIns();
        expect(container.read(tuneInProvider).tunedInArtists, isEmpty);
      });
    });

    group('isTunedIn', () {
      test('returns true for tuned-in artist', () async {
        final client = _clientWithResponses([
          _tuneInResponse('a1', 'artist1', 'Artist One'),
        ]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        await container.read(tuneInProvider.notifier).toggleTuneIn('a1');
        expect(container.read(tuneInProvider).isTunedIn('a1'), isTrue);
      });

      test('returns false for non-tuned-in artist', () {
        final client = _clientWithResponses([]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        expect(container.read(tuneInProvider).isTunedIn('a1'), isFalse);
      });

      test('returns false after Tune Out', () async {
        final client = _clientWithResponses([
          _tuneInResponse('a1', 'artist1', 'Artist One'),
          _tuneOutResponse(),
        ]);
        final container = _createContainer(client: client);
        addTearDown(container.dispose);

        final notifier = container.read(tuneInProvider.notifier);
        await notifier.toggleTuneIn('a1');
        expect(container.read(tuneInProvider).isTunedIn('a1'), isTrue);

        await notifier.toggleTuneIn('a1');
        expect(container.read(tuneInProvider).isTunedIn('a1'), isFalse);
      });
    });

    group('Tune Out sequence (simulating Timeline behavior)', () {
      test(
        'sequential Tune Out: 3 artists → 2 → 1 → 0, remaining list is correct',
        () async {
          final client = _clientWithResponses([
            // Initial load
            _myTuneInsResponse([
              _artistData('a1', 'artist1', 'One'),
              _artistData('a2', 'artist2', 'Two'),
              _artistData('a3', 'artist3', 'Three'),
            ]),
            // Tune out a1
            _tuneOutResponse(),
            _myTuneInsResponse([
              _artistData('a2', 'artist2', 'Two'),
              _artistData('a3', 'artist3', 'Three'),
            ]),
            // Tune out a2
            _tuneOutResponse(),
            _myTuneInsResponse([_artistData('a3', 'artist3', 'Three')]),
            // Tune out a3
            _tuneOutResponse(),
            _myTuneInsResponse([]),
          ]);
          final container = _createContainer(client: client);
          addTearDown(container.dispose);

          final notifier = container.read(tuneInProvider.notifier);

          // Load initial 3 artists
          await notifier.loadMyTuneIns();
          var state = container.read(tuneInProvider);
          expect(state.tunedInArtists, hasLength(3));

          // Tune out artist1 → 2 remaining
          await notifier.toggleTuneIn('a1');
          await notifier.loadMyTuneIns();
          state = container.read(tuneInProvider);
          expect(state.tunedInArtists, hasLength(2));
          expect(state.isTunedIn('a1'), isFalse);
          expect(state.isTunedIn('a2'), isTrue);
          expect(state.isTunedIn('a3'), isTrue);

          // Next artist to show should be first remaining
          expect(state.tunedInArtists.first.artistUsername, 'artist2');

          // Tune out artist2 → 1 remaining
          await notifier.toggleTuneIn('a2');
          await notifier.loadMyTuneIns();
          state = container.read(tuneInProvider);
          expect(state.tunedInArtists, hasLength(1));
          expect(state.tunedInArtists.first.artistUsername, 'artist3');

          // Tune out artist3 → 0 remaining
          await notifier.toggleTuneIn('a3');
          await notifier.loadMyTuneIns();
          state = container.read(tuneInProvider);
          expect(state.tunedInArtists, isEmpty);
        },
      );
    });
  });
}
