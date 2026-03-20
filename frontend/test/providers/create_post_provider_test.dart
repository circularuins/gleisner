import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_ce/hive.dart';

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
      final notifier = CreatePostNotifier(_clientWith());
      expect(notifier.state.step, 0);
      expect(notifier.state.selectedTrack, isNull);
      expect(notifier.state.selectedMediaType, isNull);
      expect(notifier.state.importance, 0.5);
      expect(notifier.state.isSubmitting, false);
      expect(notifier.state.error, isNull);
      notifier.dispose();
    });

    test('selectTrack advances to step 1', () {
      final notifier = CreatePostNotifier(_clientWith());
      notifier.selectTrack(_testTrack);
      expect(notifier.state.step, 1);
      expect(notifier.state.selectedTrack, _testTrack);
      notifier.dispose();
    });

    test('selectMediaType advances to step 2', () {
      final notifier = CreatePostNotifier(_clientWith());
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.text);
      expect(notifier.state.step, 2);
      expect(notifier.state.selectedMediaType, MediaType.text);
      notifier.dispose();
    });

    test('goBack decrements step', () {
      final notifier = CreatePostNotifier(_clientWith());
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.text);
      expect(notifier.state.step, 2);
      notifier.goBack();
      expect(notifier.state.step, 1);
      notifier.goBack();
      expect(notifier.state.step, 0);
      notifier.goBack(); // should not go below 0
      expect(notifier.state.step, 0);
      notifier.dispose();
    });

    test('reset returns to initial state', () {
      final notifier = CreatePostNotifier(_clientWith());
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.text);
      notifier.setImportance(0.8);
      notifier.reset();
      expect(notifier.state.step, 0);
      expect(notifier.state.selectedTrack, isNull);
      expect(notifier.state.importance, 0.5);
      notifier.dispose();
    });

    test('submit sets isSubmitting during request', () async {
      final notifier = CreatePostNotifier(
        _clientWith(errors: [const GraphQLError(message: 'fail')]),
      );
      notifier.addListener((_) {});
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.text);

      // Capture isSubmitting during the mutation
      final states = <bool>[];
      notifier.addListener((state) => states.add(state.isSubmitting));

      await notifier.submit(title: 'Hello', body: 'World', mediaUrl: null);

      // Should have been true (submitting) then false (done)
      expect(states, contains(true));
      expect(notifier.state.isSubmitting, false);
      notifier.dispose();
    });

    test('submit returns null without track/mediaType', () async {
      final notifier = CreatePostNotifier(_clientWith());
      notifier.addListener((_) {});

      final result = await notifier.submit(
        title: 'Hello',
        body: 'World',
        mediaUrl: null,
      );

      expect(result, isNull);
      notifier.dispose();
    });

    test('submit returns null and sets error on GraphQL error', () async {
      final notifier = CreatePostNotifier(
        _clientWith(errors: [const GraphQLError(message: 'Track not found')]),
      );
      notifier.addListener((_) {});
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.text);

      final result = await notifier.submit(
        title: 'Hello',
        body: 'World',
        mediaUrl: null,
      );

      expect(result, isNull);
      expect(notifier.state.error, 'Track not found');
      expect(notifier.state.isSubmitting, false);
      notifier.dispose();
    });

    test('submit returns null on network exception', () async {
      final notifier = CreatePostNotifier(
        _clientWith(exception: Exception('Network error')),
      );
      notifier.addListener((_) {});
      notifier.selectTrack(_testTrack);
      notifier.selectMediaType(MediaType.text);

      final result = await notifier.submit(
        title: 'Hello',
        body: 'World',
        mediaUrl: null,
      );

      expect(result, isNull);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isSubmitting, false);
      notifier.dispose();
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
  });
}
