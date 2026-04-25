import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_ce/hive.dart';

import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/models/track.dart';
import 'package:gleisner_web/providers/create_post_provider.dart';

class _MockLink extends Link {
  final Map<String, dynamic>? data;
  final List<GraphQLError>? errors;
  final Exception? exception;

  _MockLink({this.data, this.errors, this.exception});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
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

const _postResponse = {
  'createPost': {
    'id': 'post-1',
    'mediaType': 'text',
    'title': 'Hello',
    'body': 'World',
    'mediaUrl': null,
    'importance': 0.5,
    'layoutX': null,
    'layoutY': null,
    'contentHash': 'abc123',
    'createdAt': '2026-03-20T00:00:00Z',
    'updatedAt': '2026-03-20T00:00:00Z',
    'author': {
      'id': 'user-1',
      'username': 'test',
      'displayName': 'Test',
      'avatarUrl': null,
    },
  },
};

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('gleisner_create_post_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

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
      Post _fakePost(String id) => Post(
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
        notifier.addConnection(_fakePost('p1'), ConnectionType.reference);

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
          notifier.addConnection(_fakePost('p$i'), ConnectionType.evolution);
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
        notifier.addConnection(_fakePost('p1'), ConnectionType.reference);
        notifier.addConnection(_fakePost('p1'), ConnectionType.remix);

        expect(
          container.read(createPostProvider).selectedConnections,
          hasLength(1),
        );
      });

      test('removes a connection by post id', () {
        final container = _createContainer(client: _clientWith());
        addTearDown(container.dispose);

        final notifier = container.read(createPostProvider.notifier);
        notifier.addConnection(_fakePost('p1'), ConnectionType.reference);
        notifier.addConnection(_fakePost('p2'), ConnectionType.remix);
        notifier.removeConnection('p1');

        final conns = container.read(createPostProvider).selectedConnections;
        expect(conns, hasLength(1));
        expect(conns.first.post.id, 'p2');
      });

      test('reset clears connections', () {
        final container = _createContainer(client: _clientWith());
        addTearDown(container.dispose);

        final notifier = container.read(createPostProvider.notifier);
        notifier.addConnection(_fakePost('p1'), ConnectionType.reply);
        notifier.reset();

        expect(container.read(createPostProvider).selectedConnections, isEmpty);
      });
    });
  });
}
