import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/models/track.dart';
import 'package:gleisner_web/providers/create_post_provider.dart';

class _MockLink extends Link {
  final Map<String, dynamic>? data;
  final List<GraphQLError>? errors;
  final Exception? exception;
  // Captures the variables of the most recent request, for tests that need
  // to assert on the exact payload sent to the server (e.g. eventAt
  // serialization).
  final List<Map<String, dynamic>> capturedVariables = [];

  _MockLink({this.data, this.errors, this.exception});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    capturedVariables.add(Map<String, dynamic>.from(request.variables));
    if (exception != null) return Stream.error(exception!);
    return Stream.value(
      Response(
        data: data,
        errors: errors,
        response: {'data': data, if (errors != null) 'errors': errors},
      ),
    );
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

({GraphQLClient client, _MockLink link}) _capturingClient({
  Map<String, dynamic>? data,
  List<GraphQLError>? errors,
}) {
  final link = _MockLink(data: data, errors: errors);
  return (
    client: GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    ),
    link: link,
  );
}

ProviderContainer _createContainer({required GraphQLClient client}) {
  return ProviderContainer(
    overrides: [graphqlClientProvider.overrideWithValue(client)],
  );
}

final _testTrack = Track(
  id: 'track-1',
  name: 'Music',
  color: '#4A90D9',
  createdAt: DateTime(2026),
);

void main() {
  group('CreatePostNotifier', () {
    test('initial state', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final state = container.read(createPostProvider);
      expect(state.step, 0);
      expect(state.selectedTrack, isNull);
      expect(state.selectedMediaType, isNull);
      expect(state.importance, 0.5);
      expect(state.isSubmitting, false);
      expect(state.error, isNull);
    });

    test('selectTrack advances to step 1', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      container.read(createPostProvider.notifier).selectTrack(_testTrack);

      final state = container.read(createPostProvider);
      expect(state.step, 1);
      expect(state.selectedTrack, _testTrack);
    });

    test('selectMediaType advances to step 2', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final notifier = container.read(createPostProvider.notifier);
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.thought);

      final state = container.read(createPostProvider);
      expect(state.step, 2);
      expect(state.selectedMediaType, MediaType.thought);
    });

    test('goBack decrements step', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final notifier = container.read(createPostProvider.notifier);
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.thought);
      expect(container.read(createPostProvider).step, 2);

      notifier.goBack();
      expect(container.read(createPostProvider).step, 1);

      notifier.goBack();
      expect(container.read(createPostProvider).step, 0);

      notifier.goBack(); // should not go below 0
      expect(container.read(createPostProvider).step, 0);
    });

    test('reset returns to initial state', () {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final notifier = container.read(createPostProvider.notifier);
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.thought);
      notifier.setImportance(0.8);
      notifier.reset();

      final state = container.read(createPostProvider);
      expect(state.step, 0);
      expect(state.selectedTrack, isNull);
      expect(state.importance, 0.5);
    });

    test('submit sets isSubmitting during request', () async {
      final container = _createContainer(
        client: _clientWith(errors: [const GraphQLError(message: 'fail')]),
      );
      addTearDown(container.dispose);

      final notifier = container.read(createPostProvider.notifier);
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.thought);

      // Capture isSubmitting during the mutation
      final states = <bool>[];
      container.listen(
        createPostProvider,
        (_, next) => states.add(next.isSubmitting),
      );

      await notifier.submit(title: 'Hello', body: 'World', mediaUrl: null);

      // Should have been true (submitting) then false (done)
      expect(states, contains(true));
      expect(container.read(createPostProvider).isSubmitting, false);
    });

    test('submit returns null without track/mediaType', () async {
      final container = _createContainer(client: _clientWith());
      addTearDown(container.dispose);

      final result = await container
          .read(createPostProvider.notifier)
          .submit(title: 'Hello', body: 'World', mediaUrl: null);

      expect(result, isNull);
    });

    test('submit returns null and sets error on GraphQL error', () async {
      final container = _createContainer(
        client: _clientWith(
          errors: [const GraphQLError(message: 'Track not found')],
        ),
      );
      addTearDown(container.dispose);

      final notifier = container.read(createPostProvider.notifier);
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.thought);

      final result = await notifier.submit(
        title: 'Hello',
        body: 'World',
        mediaUrl: null,
      );

      expect(result, isNull);
      final state = container.read(createPostProvider);
      expect(state.error, 'Track not found');
      expect(state.isSubmitting, false);
    });

    test('submit returns null on network exception', () async {
      final container = _createContainer(
        client: _clientWith(exception: Exception('Network error')),
      );
      addTearDown(container.dispose);

      final notifier = container.read(createPostProvider.notifier);
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.thought);

      final result = await notifier.submit(
        title: 'Hello',
        body: 'World',
        mediaUrl: null,
      );

      expect(result, isNull);
      final state = container.read(createPostProvider);
      expect(state.error, isNotNull);
      expect(state.isSubmitting, false);
    });

    test('submit serializes eventAt as a UTC ISO-8601 string', () async {
      // Regression for the JST-as-UTC timeline ordering bug:
      // EventAtPicker emits a local DateTime; calling toIso8601String() on
      // a local DateTime drops the timezone offset, and Node.js then
      // parses the naive string as server-local time (UTC on Railway),
      // causing JST inputs to be stored 9 hours in the future.
      // The fix is to call .toUtc() before .toIso8601String().
      final captured = _capturingClient(
        data: {
          'createPost': {
            'post': {
              'id': 'post-1',
              'mediaType': 'thought',
              'title': 'Hello',
              'importance': 0.5,
              'createdAt': '2026-05-10T14:02:00.000Z',
              'updatedAt': '2026-05-10T14:02:00.000Z',
              'author': {'id': 'u1', 'username': 'me'},
            },
            'track': {
              'id': 'track-1',
              'name': 'Music',
              'color': '#4A90D9',
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
          },
        },
      );
      final container = _createContainer(client: captured.client);
      addTearDown(container.dispose);

      final notifier = container.read(createPostProvider.notifier);
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.thought);

      // A local DateTime — what EventAtPicker hands back to callers.
      final localEventAt = DateTime(2026, 5, 10, 13, 45);

      await notifier.submit(
        title: 'Hello',
        body: 'World',
        mediaUrl: null,
        eventAt: localEventAt,
      );

      // Two requests are issued: getUploadUrl (none for thought) and
      // createPost. We only care about the one that carries eventAt.
      final createCall = captured.link.capturedVariables.firstWhere(
        (v) => v.containsKey('eventAt'),
      );
      final serialized = createCall['eventAt'] as String;

      // Must end with `Z` so the backend's `new Date(...)` parses it as
      // an absolute UTC instant rather than as server-local time.
      expect(
        serialized.endsWith('Z'),
        isTrue,
        reason: 'eventAt must be serialized in UTC: got "$serialized"',
      );

      // And the absolute moment must equal the local input — i.e. round-
      // tripping must not shift the user's intended time.
      expect(
        DateTime.parse(serialized).millisecondsSinceEpoch,
        localEventAt.millisecondsSinceEpoch,
      );
    });

    test('copyWith preserves error when not explicitly set', () {
      final state = const CreatePostState().copyWith(error: 'some error');
      final updated = state.copyWith(isSubmitting: true);
      expect(updated.error, 'some error');
      expect(updated.isSubmitting, true);
    });

    test('copyWith clears error when explicitly set to null', () {
      final state = const CreatePostState().copyWith(error: 'some error');
      final updated = state.copyWith(error: null);
      expect(updated.error, isNull);
    });

    group('addConnection / removeConnection', () {
      Post fakePost(String id) => Post(
        id: id,
        mediaType: MediaType.article,
        title: 'Post $id',
        importance: 0.5,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        author: const PostAuthor(id: 'u1', username: 'test'),
      );

      test('adds a connection', () {
        final container = _createContainer(client: _clientWith());
        addTearDown(container.dispose);

        final notifier = container.read(createPostProvider.notifier);
        notifier.addConnection(fakePost('p1'), ConnectionType.reference);

        final state = container.read(createPostProvider);
        expect(state.selectedConnections, hasLength(1));
        expect(state.selectedConnections.first.post.id, 'p1');
        expect(
          state.selectedConnections.first.connectionType,
          ConnectionType.reference,
        );
      });

      test('enforces max 5 connections', () {
        final container = _createContainer(client: _clientWith());
        addTearDown(container.dispose);

        final notifier = container.read(createPostProvider.notifier);
        for (var i = 1; i <= 6; i++) {
          notifier.addConnection(fakePost('p$i'), ConnectionType.evolution);
        }

        expect(
          container.read(createPostProvider).selectedConnections,
          hasLength(5),
        );
      });

      test('prevents duplicate target post', () {
        final container = _createContainer(client: _clientWith());
        addTearDown(container.dispose);

        final notifier = container.read(createPostProvider.notifier);
        notifier.addConnection(fakePost('p1'), ConnectionType.reference);
        notifier.addConnection(fakePost('p1'), ConnectionType.remix);

        expect(
          container.read(createPostProvider).selectedConnections,
          hasLength(1),
        );
      });

      test('removes a connection by post id', () {
        final container = _createContainer(client: _clientWith());
        addTearDown(container.dispose);

        final notifier = container.read(createPostProvider.notifier);
        notifier.addConnection(fakePost('p1'), ConnectionType.reference);
        notifier.addConnection(fakePost('p2'), ConnectionType.remix);
        notifier.removeConnection('p1');

        final conns = container.read(createPostProvider).selectedConnections;
        expect(conns, hasLength(1));
        expect(conns.first.post.id, 'p2');
      });

      test('reset clears connections', () {
        final container = _createContainer(client: _clientWith());
        addTearDown(container.dispose);

        final notifier = container.read(createPostProvider.notifier);
        notifier.addConnection(fakePost('p1'), ConnectionType.reply);
        notifier.reset();

        expect(container.read(createPostProvider).selectedConnections, isEmpty);
      });
    });
  });
}
