import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/models/artist.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/models/track.dart';
import 'package:gleisner_web/providers/timeline_provider.dart';

class _MockLink extends Link {
  final Map<String, dynamic>? data;
  final List<GraphQLError>? errors;
  final Exception? exception;
  final List<Request> requests = [];

  _MockLink({this.data, this.errors, this.exception});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    requests.add(request);
    if (exception != null) return Stream.error(exception!);
    return Stream.value(Response(data: data, errors: errors, response: {}));
  }
}

GraphQLClient _clientWith({
  Map<String, dynamic>? data,
  List<GraphQLError>? errors,
  Exception? exception,
}) {
  return GraphQLClient(
    link: _MockLink(data: data, errors: errors, exception: exception),
    cache: GraphQLCache(store: InMemoryStore()),
  );
}

({GraphQLClient client, _MockLink link}) _clientAndLinkWith({
  Map<String, dynamic>? data,
  List<GraphQLError>? errors,
  Exception? exception,
}) {
  final link = _MockLink(data: data, errors: errors, exception: exception);
  return (
    client: GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    ),
    link: link,
  );
}

/// Minimal Post factory for OGP refresh tests.
Post _linkPost({
  String id = 'p1',
  String? ogTitle,
  String? ogDescription,
  String? ogImage,
  String? ogSiteName,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return Post(
    id: id,
    mediaType: MediaType.link,
    mediaUrl: 'https://example.com',
    importance: 1.0,
    createdAt: now,
    updatedAt: now,
    author: const PostAuthor(id: 'u1', username: 'alice'),
    ogTitle: ogTitle,
    ogDescription: ogDescription,
    ogImage: ogImage,
    ogSiteName: ogSiteName,
  );
}

Map<String, dynamic> _fetchOgpResponse({
  String id = 'p1',
  String ogTitle = 'Example Title',
  String? ogDescription = 'Example Description',
  String? ogImage = 'https://example.com/og.png',
  String? ogSiteName = 'example.com',
}) {
  // `__typename` is required at every object level so that the graphql
  // client's normalizing cache (used by default via FetchPolicy.networkOnly)
  // can ingest the mocked response without throwing
  // UnexpectedResponseStructureException. Mirrors the pattern in
  // tune_in_provider_test.dart.
  return {
    '__typename': 'Mutation',
    'fetchOgp': {
      '__typename': 'Post',
      'id': id,
      'mediaType': 'link',
      'title': null,
      'body': null,
      'bodyFormat': 'plain',
      'mediaUrl': 'https://example.com',
      'thumbnailUrl': null,
      'duration': null,
      'importance': 1.0,
      'visibility': 'public',
      'eventAt': null,
      'layoutX': null,
      'layoutY': null,
      'contentHash': null,
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
      'author': {
        '__typename': 'PublicUser',
        'id': 'u1',
        'username': 'alice',
        'displayName': null,
        'avatarUrl': null,
      },
      'track': null,
      'reactionCounts': const [],
      'myReactions': const [],
      'outgoingConnections': const [],
      'incomingConnections': const [],
      'constellation': null,
      'media': const [],
      'articleGenre': null,
      'externalPublish': false,
      'ogTitle': ogTitle,
      'ogDescription': ogDescription,
      'ogImage': ogImage,
      'ogSiteName': ogSiteName,
    },
  };
}

ProviderContainer _createContainer({required GraphQLClient client}) {
  return ProviderContainer(
    overrides: [graphqlClientProvider.overrideWithValue(client)],
  );
}

void main() {
  group('TimelineNotifier', () {
    test('initial state', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final state = container.read(timelineProvider);
      expect(state.artist, isNull);
      expect(state.selectedTrackIds, isEmpty);
      expect(state.posts, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loadArtist clears state when artist not found', () async {
      final container = _createContainer(
        client: _clientWith(data: {'artist': null}),
      );
      addTearDown(container.dispose);

      await container.read(timelineProvider.notifier).loadArtist('nobody');

      final state = container.read(timelineProvider);
      expect(state.artist, isNull);
      expect(state.selectedTrackIds, isEmpty);
      expect(state.posts, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('loadArtist sets error on GraphQL exception', () async {
      final container = _createContainer(
        client: _clientWith(
          errors: [const GraphQLError(message: 'Server error')],
        ),
      );
      addTearDown(container.dispose);

      await container.read(timelineProvider.notifier).loadArtist('alice');

      final state = container.read(timelineProvider);
      expect(state.error, 'Server error');
      expect(state.isLoading, isFalse);
    });

    test('loadArtist sets error on network exception', () async {
      final container = _createContainer(
        client: _clientWith(
          // Use a plain Exception (not dart:io's SocketException) so this test
          // compiles on `--platform chrome`. The error path is exception-type
          // agnostic.
          exception: Exception('Connection refused'),
        ),
      );
      addTearDown(container.dispose);

      await container.read(timelineProvider.notifier).loadArtist('alice');

      final state = container.read(timelineProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test('ensureTrackSelected adds track to selection', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      container.read(timelineProvider.notifier).ensureTrackSelected('t2');

      expect(container.read(timelineProvider).selectedTrackIds, contains('t2'));
    });

    test('toggleTrack adds and removes track', () async {
      final container = _createContainer(
        client: _clientWith(data: {'posts': []}),
      );
      addTearDown(container.dispose);

      final notifier = container.read(timelineProvider.notifier);

      await notifier.toggleTrack('t1');
      expect(container.read(timelineProvider).selectedTrackIds, contains('t1'));

      await notifier.toggleTrack('t1');
      expect(
        container.read(timelineProvider).selectedTrackIds,
        isNot(contains('t1')),
      );
    });

    test('refresh does nothing without selected tracks', () async {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      await container.read(timelineProvider.notifier).refresh();

      final state = container.read(timelineProvider);
      expect(state.isLoading, isFalse);
      expect(state.posts, isEmpty);
    });

    test('createTrack returns error on GraphQL failure', () async {
      final container = _createContainer(
        client: _clientWith(
          errors: [const GraphQLError(message: 'Duplicate name')],
        ),
      );
      addTearDown(container.dispose);

      final (track, error) = await container
          .read(timelineProvider.notifier)
          .createTrack('Dup', '#ff0000');

      expect(track, isNull);
      expect(error, 'Duplicate name');
    });

    test('addTrackToState adds track to artist and selectedTrackIds', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final notifier = container.read(timelineProvider.notifier);
      notifier.debugSetState(
        const TimelineState(
          artist: Artist(
            id: 'a1',
            artistUsername: 'test',
            tunedInCount: 0,
            tracks: [],
          ),
        ),
      );

      final track = Track.fromJson({
        'id': 't-new',
        'name': 'NewTrack',
        'color': '#ff0000',
        'createdAt': '2026-01-01T00:00:00Z',
      });
      notifier.debugAddTrack(track);

      final state = container.read(timelineProvider);
      expect(state.artist!.tracks, hasLength(1));
      expect(state.artist!.tracks.first.name, 'NewTrack');
      expect(state.selectedTrackIds, contains('t-new'));
    });

    test('ensureTrackSelected is idempotent from empty state', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final notifier = container.read(timelineProvider.notifier);
      notifier.ensureTrackSelected('t1');
      notifier.ensureTrackSelected('t1');
      notifier.ensureTrackSelected('t1');

      expect(
        container
            .read(timelineProvider)
            .selectedTrackIds
            .where((id) => id == 't1')
            .length,
        1,
      );
    });

    test('ensureTrackSelected is idempotent with existing tracks', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final notifier = container.read(timelineProvider.notifier);
      notifier.debugSetState(
        container
            .read(timelineProvider)
            .copyWith(selectedTrackIds: {'t0', 't1'}),
      );

      notifier.ensureTrackSelected('t1');
      notifier.ensureTrackSelected('t2');
      notifier.ensureTrackSelected('t2');

      expect(container.read(timelineProvider).selectedTrackIds, {
        't0',
        't1',
        't2',
      });
    });
  });

  // Regression tests for Issue #191. The backend fires OGP fetch
  // fire-and-forget after createPost, so a freshly added link post often
  // lands in the timeline with every og* field still null. TimelineNotifier
  // schedules a deferred fetchOgp after addPost to populate them.
  group('TimelineNotifier OGP auto-refresh (#191)', () {
    test(
      'link post with null OGP triggers fetchOgp and merges result',
      () async {
        final pair = _clientAndLinkWith(data: _fetchOgpResponse());
        final container = _createContainer(client: pair.client);
        addTearDown(container.dispose);

        final notifier = container.read(timelineProvider.notifier);
        final post = _linkPost();
        notifier.debugSetState(
          container.read(timelineProvider).copyWith(posts: [post]),
        );

        await notifier.scheduleOgpRefreshForTesting(post);

        expect(pair.link.requests, hasLength(1));
        final refreshed = container.read(timelineProvider).posts.single;
        expect(refreshed.ogTitle, 'Example Title');
        expect(refreshed.ogDescription, 'Example Description');
        expect(refreshed.ogImage, 'https://example.com/og.png');
        expect(refreshed.ogSiteName, 'example.com');
        // Other fields must be untouched
        expect(refreshed.id, post.id);
        expect(refreshed.mediaType, MediaType.link);
      },
    );

    test('non-link post skips refresh entirely', () async {
      final pair = _clientAndLinkWith(data: _fetchOgpResponse());
      final container = _createContainer(client: pair.client);
      addTearDown(container.dispose);

      final now = DateTime.utc(2026, 1, 1);
      final imagePost = Post(
        id: 'p2',
        mediaType: MediaType.image,
        importance: 1.0,
        createdAt: now,
        updatedAt: now,
        author: const PostAuthor(id: 'u1', username: 'alice'),
      );

      await container
          .read(timelineProvider.notifier)
          .scheduleOgpRefreshForTesting(imagePost);

      expect(pair.link.requests, isEmpty);
    });

    test('link post with existing OGP skips refresh', () async {
      final pair = _clientAndLinkWith(data: _fetchOgpResponse());
      final container = _createContainer(client: pair.client);
      addTearDown(container.dispose);

      final post = _linkPost(ogTitle: 'Already Fetched');

      await container
          .read(timelineProvider.notifier)
          .scheduleOgpRefreshForTesting(post);

      expect(pair.link.requests, isEmpty);
    });

    test('refresh is dropped when the post has left the timeline', () async {
      final pair = _clientAndLinkWith(data: _fetchOgpResponse());
      final container = _createContainer(client: pair.client);
      addTearDown(container.dispose);

      final notifier = container.read(timelineProvider.notifier);
      final post = _linkPost();
      // Start with post absent — simulates deletion between scheduling and
      // the delay elapsing.
      notifier.debugSetState(
        container.read(timelineProvider).copyWith(posts: const []),
      );

      await notifier.scheduleOgpRefreshForTesting(post);

      expect(pair.link.requests, isEmpty);
      expect(container.read(timelineProvider).posts, isEmpty);
    });

    test('GraphQL errors during refresh leave state unchanged', () async {
      final pair = _clientAndLinkWith(
        errors: [const GraphQLError(message: 'Rate limited')],
      );
      final container = _createContainer(client: pair.client);
      addTearDown(container.dispose);

      final notifier = container.read(timelineProvider.notifier);
      final post = _linkPost();
      notifier.debugSetState(
        container.read(timelineProvider).copyWith(posts: [post]),
      );

      await notifier.scheduleOgpRefreshForTesting(post);

      final after = container.read(timelineProvider).posts.single;
      expect(after.ogTitle, isNull);
      expect(after.ogDescription, isNull);
      expect(after.ogImage, isNull);
      expect(after.ogSiteName, isNull);
    });
  });
}
