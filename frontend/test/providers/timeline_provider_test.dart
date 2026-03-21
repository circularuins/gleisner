import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_ce/hive.dart';

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
      final notifier = TimelineNotifier(_clientWith());

      expect(notifier.state.artist, isNull);
      expect(notifier.state.selectedTrackIds, isEmpty);
      expect(notifier.state.posts, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNull);
    });

    test('loadArtist clears state when artist not found', () async {
      final notifier = TimelineNotifier(_clientWith(data: {'artist': null}));

      await notifier.loadArtist('nobody');

      expect(notifier.state.artist, isNull);
      expect(notifier.state.selectedTrackIds, isEmpty);
      expect(notifier.state.posts, isEmpty);
      expect(notifier.state.isLoading, isFalse);
    });

    test('loadArtist sets error on GraphQL exception', () async {
      final notifier = TimelineNotifier(
        _clientWith(errors: [const GraphQLError(message: 'Server error')]),
      );

      await notifier.loadArtist('alice');

      expect(notifier.state.error, 'Server error');
      expect(notifier.state.isLoading, isFalse);
    });

    test('loadArtist sets error on network exception', () async {
      final notifier = TimelineNotifier(
        _clientWith(exception: const SocketException('Connection refused')),
      );

      await notifier.loadArtist('alice');

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.isLoading, isFalse);
    });

    test('ensureTrackSelected adds track to selection', () {
      final notifier = TimelineNotifier(_clientWith());

      notifier.ensureTrackSelected('t2');

      expect(notifier.state.selectedTrackIds, contains('t2'));
    });

    test('toggleTrack adds and removes track', () async {
      final notifier = TimelineNotifier(_clientWith(data: {'posts': []}));

      await notifier.toggleTrack('t1');
      expect(notifier.state.selectedTrackIds, contains('t1'));

      await notifier.toggleTrack('t1');
      expect(notifier.state.selectedTrackIds, isNot(contains('t1')));
    });

    test('refresh does nothing without selected tracks', () async {
      final notifier = TimelineNotifier(_clientWith());

      await notifier.refresh();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.posts, isEmpty);
    });
  });
}
