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

  @override
  UnassignedPostsState build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
    return const UnassignedPostsState();
  }

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
    String? thumbnailUrl,
    bool clearThumbnail = false,
    int? duration,
    bool clearDuration = false,
    String? eventAt,
    bool clearEventAt = false,
    double? importance,
    String? visibility,
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
            if (trackId != null) 'trackId': trackId,
            if (title != null) 'title': title.isEmpty ? null : title,
            if (body != null) 'body': body.isEmpty ? null : body,
            if (bodyFormat != null) 'bodyFormat': bodyFormat,
            if (mediaUrl != null) 'mediaUrl': mediaUrl,
            if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
            if (clearThumbnail) 'thumbnailUrl': null,
            if (duration != null) 'duration': duration,
            if (clearDuration) 'duration': null,
            if (eventAt != null) 'eventAt': eventAt,
            if (clearEventAt) 'eventAt': null,
            if (importance != null) 'importance': importance,
            if (visibility != null) 'visibility': visibility,
          },
        ),
      );
      if (result.hasException) return null;
      final data = result.data?['updatePost'] as Map<String, dynamic>?;
      if (data == null) return null;
      final updated = Post.fromJson(data);
      // If reassigned to a track, remove from list
      if (updated.trackId != null) {
        removePost(updated.id);
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
}

final unassignedPostsProvider =
    NotifierProvider<UnassignedPostsNotifier, UnassignedPostsState>(
      UnassignedPostsNotifier.new,
    );
