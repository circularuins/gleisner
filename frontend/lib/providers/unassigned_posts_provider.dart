import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/mutations/post.dart';
import '../graphql/queries/post.dart';
import '../models/post.dart';
import 'disposable_notifier.dart';

class UnassignedPostsState {
  final List<Post> posts;
  final bool isLoading;

  const UnassignedPostsState({this.posts = const [], this.isLoading = false});
}

class UnassignedPostsNotifier extends Notifier<UnassignedPostsState>
    with DisposableNotifier {
  late GraphQLClient _client;

  /// Tracks postIds whose deletion mutation is in flight, so a tap-storm on
  /// the trash button does not fire the mutation twice for the same post.
  final Set<String> _inFlightDeletes = <String>{};

  @override
  UnassignedPostsState build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
    return const UnassignedPostsState();
  }

  /// Test-only state seed. See `TimelineNotifier.debugSetState` for the
  /// rationale (avoiding graphql_flutter cache cross-talk between
  /// `myUnassignedPosts` query fixtures and `updatePost` mutation
  /// fixtures that share Post ids). Do NOT call from production paths.
  @visibleForTesting
  void debugSetState(UnassignedPostsState newState) => state = newState;

  Future<void> load() async {
    state = const UnassignedPostsState(isLoading: true);
    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(myUnassignedPostsQuery),
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );
      if (disposed) return;
      final data = result.data?['myUnassignedPosts'] as List<dynamic>? ?? [];
      state = UnassignedPostsState(
        posts: data
            .map((p) => Post.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      debugPrint('[UnassignedPosts] load error: $e');
      if (disposed) return;
      state = const UnassignedPostsState();
    }
  }

  /// Update an unassigned post (e.g., reassign to a track).
  /// Returns the updated post on success, null on failure.
  Future<Post?> updatePost({
    required String id,
    String? trackId,
    String? title,
    String? body,
    String? bodyFormat,
    String? mediaUrl,
    List<String>? mediaUrls,
    String? thumbnailUrl,
    bool clearThumbnail = false,
    int? duration,
    bool clearDuration = false,
    DateTime? eventAt,
    bool clearEventAt = false,
    double? importance,
    String? visibility,
    String? articleGenre,
    bool clearArticleGenre = false,
    bool? externalPublish,
  }) async {
    if (thumbnailUrl != null && clearThumbnail) {
      debugPrint(
        '[updatePost] thumbnailUrl and clearThumbnail are mutually exclusive',
      );
      return null;
    }
    if (duration != null && clearDuration) {
      debugPrint(
        '[updatePost] duration and clearDuration are mutually exclusive',
      );
      return null;
    }
    if (eventAt != null && clearEventAt) {
      debugPrint(
        '[updatePost] eventAt and clearEventAt are mutually exclusive',
      );
      return null;
    }
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(updatePostMutation),
          variables: {
            'id': id,
            'trackId': ?trackId,
            if (title != null) 'title': title.isEmpty ? null : title,
            if (body != null) 'body': body.isEmpty ? null : body,
            'bodyFormat': ?bodyFormat,
            'mediaUrl': ?mediaUrl,
            'mediaUrls': ?mediaUrls,
            'thumbnailUrl': ?thumbnailUrl,
            if (clearThumbnail) 'thumbnailUrl': null,
            'duration': ?duration,
            if (clearDuration) 'duration': null,
            // See comment in TimelineNotifier.updatePost: callers pass a
            // local DateTime; we centralize the toUtc().toIso8601String()
            // conversion here.
            if (eventAt != null) 'eventAt': eventAt.toUtc().toIso8601String(),
            if (clearEventAt) 'eventAt': null,
            'importance': ?importance,
            'visibility': ?visibility,
            'articleGenre': ?articleGenre,
            if (clearArticleGenre) 'clearArticleGenre': true,
            'externalPublish': ?externalPublish,
          },
        ),
      );
      if (result.hasException) return null;
      final data = result.data?['updatePost'] as Map<String, dynamic>?;
      if (data == null) return null;
      final updated = Post.fromJson(data);
      // The mutation `await` may have been racing the user closing the
      // edit sheet. If the Notifier got disposed in the meantime,
      // writing to `state` (or calling `removePost` which also writes
      // state) would throw `tried to use a disposed notifier`.
      if (disposed) return updated;
      // If reassigned to a track, drop from the unassigned list. Otherwise
      // splice the updated post back into state so callers (e.g. edit
      // sheet on the unassigned list) immediately see the new eventAt /
      // title / body without having to wait for the next load().
      if (updated.trackId != null) {
        removePost(updated.id);
      } else {
        state = UnassignedPostsState(
          posts: state.posts
              .map((p) => p.id == updated.id ? updated : p)
              .toList(),
          isLoading: state.isLoading,
        );
      }
      return updated;
    } catch (e) {
      debugPrint('[UnassignedPosts] updatePost error: $e');
      return null;
    }
  }

  /// Remove a post from the local list (e.g., after reassignment).
  void removePost(String postId) {
    state = UnassignedPostsState(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  /// Delete an unassigned post via the GraphQL `deletePost` mutation.
  /// Returns true on success, false on validation/IDOR/race/network failure.
  ///
  /// Defenses layered on top of the server-side `authorId` check:
  /// 1. The post must currently exist in `state.posts` (prevents callers from
  ///    issuing deletes against arbitrary IDs that were never rendered).
  /// 2. `_inFlightDeletes` blocks duplicate concurrent mutations for the same
  ///    postId while the network call is pending.
  Future<bool> deletePost(String postId) async {
    if (!state.posts.any((p) => p.id == postId)) return false;
    if (!_inFlightDeletes.add(postId)) return false;
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(deletePostMutation),
          variables: {'id': postId},
        ),
      );
      if (disposed) return false;
      if (result.hasException) return false;
      removePost(postId);
      return true;
    } catch (e) {
      debugPrint('[UnassignedPosts] deletePost error: $e');
      if (disposed) return false;
      return false;
    } finally {
      _inFlightDeletes.remove(postId);
    }
  }
}

final unassignedPostsProvider =
    NotifierProvider<UnassignedPostsNotifier, UnassignedPostsState>(
      UnassignedPostsNotifier.new,
    );
