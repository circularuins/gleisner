import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/providers/unassigned_posts_provider.dart';

class _MockLink extends Link {
  final Map<String, dynamic>? data;
  final List<GraphQLError>? errors;
  final List<Request> requests = [];

  _MockLink({this.data, this.errors});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    requests.add(request);
    // Mirror create_post_provider_test's mock: graphql_flutter writes the
    // response to its normalizing cache, and passing the raw `response`
    // map avoids cache-writer surprises that can otherwise mark the
    // OperationResult as exception (which the provider then short-circuits).
    return Stream.value(
      Response(
        data: data,
        errors: errors,
        response: {'data': data, if (errors != null) 'errors': errors},
      ),
    );
  }
}

({GraphQLClient client, _MockLink link}) _clientAndLinkWith({
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

// Build a Post-shaped JSON value matching the full `postFields` fragment
// (lib/graphql/queries/post.dart). Every field requested by the document
// must be present in the mock response, otherwise graphql_flutter's
// response normalizer raises PartialDataException → OperationException
// and the provider's `result.hasException` short-circuits.
Map<String, dynamic> _postJson({
  required String id,
  String? trackId,
  String? title = 'updated',
  String? eventAt,
}) {
  return {
    '__typename': 'Post',
    'id': id,
    'mediaType': 'thought',
    'title': title,
    'body': null,
    'bodyFormat': 'plain',
    'mediaUrl': null,
    'thumbnailUrl': null,
    'duration': null,
    'eventAt': eventAt,
    'importance': 0.5,
    'visibility': 'public',
    'layoutX': null,
    'layoutY': null,
    'contentHash': null,
    'articleGenre': null,
    'externalPublish': false,
    'ogTitle': null,
    'ogDescription': null,
    'ogImage': null,
    'ogSiteName': null,
    'createdAt': '2026-05-10T05:00:00.000Z',
    'updatedAt': '2026-05-10T05:00:00.000Z',
    'author': {
      '__typename': 'PublicUser',
      'id': 'u1',
      'username': 'alice',
      'displayName': 'Alice',
      'avatarUrl': null,
    },
    'track': trackId == null
        ? null
        : {
            '__typename': 'Track',
            'id': trackId,
            'name': 'Music',
            'color': '#4A90D9',
          },
    'reactionCounts': const <Map<String, dynamic>>[],
    'myReactions': const <String>[],
    'outgoingConnections': const <Map<String, dynamic>>[],
    'incomingConnections': const <Map<String, dynamic>>[],
    'constellation': null,
    'media': const <Map<String, dynamic>>[],
  };
}

void main() {
  group('UnassignedPostsNotifier.updatePost', () {
    // Mirrors the timeline-side coverage for the JST-as-UTC bug. Callers
    // hand a local DateTime; the provider must serialize as UTC ISO so
    // the backend stores the user's intended absolute moment.
    test('serializes eventAt as a UTC ISO-8601 string', () async {
      final pair = _clientAndLinkWith(
        data: {
          '__typename': 'Mutation',
          'updatePost': _postJson(
            id: 'unassigned-1',
            eventAt: '2026-05-10T04:45:00.000Z',
          ),
        },
      );
      final container = _createContainer(client: pair.client);
      addTearDown(container.dispose);

      final notifier = container.read(unassignedPostsProvider.notifier);

      // What EventAtPicker.onChanged emits — a naive local DateTime.
      final localEventAt = DateTime(2026, 5, 10, 13, 45);

      await notifier.updatePost(id: 'unassigned-1', eventAt: localEventAt);

      final updateRequest = pair.link.requests.firstWhere(
        (r) => r.variables.containsKey('eventAt'),
      );
      final serialized = updateRequest.variables['eventAt'] as String;

      expect(
        serialized.endsWith('Z'),
        isTrue,
        reason: 'eventAt must be UTC-serialized: got "$serialized"',
      );
      expect(
        DateTime.parse(serialized).millisecondsSinceEpoch,
        localEventAt.millisecondsSinceEpoch,
      );
    });

    // Unassigned posts that stay unassigned after an edit (e.g. user
    // updates only eventAt / title / body) must reflect the server
    // response in state.posts so the same screen sees the change
    // immediately. Posts that get reassigned (trackId becomes non-null)
    // must drop out of the unassigned list.
    test(
      'splices the updated post back into state when trackId stays null',
      () async {
        // Use debugSetState to seed an initial post directly. We avoid
        // load() in this test because graphql_flutter's normalizing cache
        // can conflate the load() and updatePost responses (same Post id
        // → cache merges fields), making the splice assertion flaky.
        final pair = _clientAndLinkWith(
          data: {
            '__typename': 'Mutation',
            'updatePost': _postJson(
              id: 'p-stay',
              title: 'new',
              eventAt: '2026-05-10T04:45:00.000Z',
            ),
          },
        );
        final container = _createContainer(client: pair.client);
        addTearDown(container.dispose);

        final notifier = container.read(unassignedPostsProvider.notifier);

        final original = Post.fromJson(_postJson(id: 'p-stay', title: 'old'));
        notifier.debugSetState(UnassignedPostsState(posts: [original]));
        expect(container.read(unassignedPostsProvider).posts, hasLength(1));
        expect(
          container.read(unassignedPostsProvider).posts.single.title,
          'old',
        );

        await notifier.updatePost(
          id: 'p-stay',
          title: 'new',
          eventAt: DateTime(2026, 5, 10, 13, 45),
        );

        final after = container.read(unassignedPostsProvider).posts;
        expect(after, hasLength(1));
        expect(after.single.id, 'p-stay');
        // Server response is reflected in state without waiting for a
        // refetch — the regression Important #2 was protecting against.
        expect(after.single.title, 'new');
        expect(after.single.eventAt, isNotNull);
        expect(after.single.eventAt!.isUtc, isTrue);
      },
    );

    // Companion to the splice test: the `clearEventAt: true` flag tells
    // the backend to NULL out eventAt, and the response carries
    // `eventAt: null`. The splice path must propagate that null back
    // into state so the UI doesn't keep showing the old timestamp.
    test(
      'splices null eventAt into state when clearEventAt clears it',
      () async {
        final pair = _clientAndLinkWith(
          data: {
            '__typename': 'Mutation',
            'updatePost': _postJson(id: 'p-clear', eventAt: null),
          },
        );
        final container = _createContainer(client: pair.client);
        addTearDown(container.dispose);

        final notifier = container.read(unassignedPostsProvider.notifier);
        // Seed with a post that already has a non-null eventAt so we can
        // observe the clear actually changing state, not just matching
        // an already-null field.
        final original = Post.fromJson(
          _postJson(id: 'p-clear', eventAt: '2026-05-10T04:45:00.000Z'),
        );
        notifier.debugSetState(UnassignedPostsState(posts: [original]));
        expect(
          container.read(unassignedPostsProvider).posts.single.eventAt,
          isNotNull,
        );

        await notifier.updatePost(id: 'p-clear', clearEventAt: true);

        // The mutation request must carry an explicit `eventAt: null`
        // (not a missing key — that would mean "no change").
        final updateRequest = pair.link.requests.firstWhere(
          (r) => r.operation.operationName != null,
          orElse: () => pair.link.requests.first,
        );
        expect(updateRequest.variables.containsKey('eventAt'), isTrue);
        expect(updateRequest.variables['eventAt'], isNull);

        // And the splice must reflect the cleared value in state.
        final after = container.read(unassignedPostsProvider).posts;
        expect(after, hasLength(1));
        expect(after.single.id, 'p-clear');
        expect(after.single.eventAt, isNull);
      },
    );

    test('drops the post from state when trackId becomes non-null', () async {
      final pair = _clientAndLinkWith(
        data: {
          '__typename': 'Mutation',
          'updatePost': _postJson(
            id: 'p-reassign',
            title: 'old',
            trackId: 'track-x',
          ),
        },
      );
      final container = _createContainer(client: pair.client);
      addTearDown(container.dispose);

      final notifier = container.read(unassignedPostsProvider.notifier);
      final original = Post.fromJson(_postJson(id: 'p-reassign', title: 'old'));
      notifier.debugSetState(UnassignedPostsState(posts: [original]));
      expect(container.read(unassignedPostsProvider).posts, hasLength(1));

      await notifier.updatePost(id: 'p-reassign', trackId: 'track-x');

      // Reassigned to a track → leaves the unassigned list.
      expect(container.read(unassignedPostsProvider).posts, isEmpty);
    });
  });
}
