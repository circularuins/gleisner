import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
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
