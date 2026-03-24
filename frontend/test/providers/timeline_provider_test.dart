import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_ce/hive.dart';

import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/models/artist.dart';
import 'package:gleisner_web/models/track.dart';
import 'package:gleisner_web/providers/timeline_provider.dart';

class _MockLink extends Link {
  final Map<String, dynamic>? data;
  final List<GraphQLError>? errors;
  final Exception? exception;

  _MockLink({this.data, this.errors, this.exception});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
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

ProviderContainer _createContainer({required GraphQLClient client}) {
  return ProviderContainer(
    overrides: [graphqlClientProvider.overrideWithValue(client)],
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('gleisner_timeline_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

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
          exception: const SocketException('Connection refused'),
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
      expect(
        container.read(timelineProvider).selectedTrackIds,
        contains('t1'),
      );

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

      expect(
        container.read(timelineProvider).selectedTrackIds,
        {'t0', 't1', 't2'},
      );
    });
  });
}
