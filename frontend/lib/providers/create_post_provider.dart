import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/mutations/connection.dart';
import '../graphql/mutations/post.dart';
import '../models/post.dart';
import '../models/track.dart';
import '../utils/sentinel.dart';

class CreatePostState {
  final int step; // 0: track, 1: mediaType, 2: form
  final Track? selectedTrack;
  final MediaType? selectedMediaType;
  final double importance;
  final bool isSubmitting;
  final String? error;
  final Post? selectedRelatedPost;

  const CreatePostState({
    this.step = 0,
    this.selectedTrack,
    this.selectedMediaType,
    this.importance = 0.5,
    this.isSubmitting = false,
    this.error,
    this.selectedRelatedPost,
  });

  CreatePostState copyWith({
    int? step,
    Object? selectedTrack = sentinel,
    Object? selectedMediaType = sentinel,
    double? importance,
    bool? isSubmitting,
    Object? error = sentinel,
    Object? selectedRelatedPost = sentinel,
  }) {
    return CreatePostState(
      step: step ?? this.step,
      selectedTrack: selectedTrack == sentinel
          ? this.selectedTrack
          : selectedTrack as Track?,
      selectedMediaType: selectedMediaType == sentinel
          ? this.selectedMediaType
          : selectedMediaType as MediaType?,
      importance: importance ?? this.importance,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error == sentinel ? this.error : error as String?,
      selectedRelatedPost: selectedRelatedPost == sentinel
          ? this.selectedRelatedPost
          : selectedRelatedPost as Post?,
    );
  }
}

class CreatePostNotifier extends Notifier<CreatePostState> {
  late GraphQLClient _client;
  bool _disposed = false;

  @override
  CreatePostState build() {
    _client = ref.watch(graphqlClientProvider);
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const CreatePostState();
  }

  void selectTrack(Track track) {
    state = state.copyWith(selectedTrack: track, step: 1, error: null);
  }

  void selectMediaType(MediaType mediaType) {
    state = state.copyWith(selectedMediaType: mediaType, step: 2, error: null);
  }

  void setImportance(double value) {
    state = state.copyWith(importance: value);
  }

  void selectRelatedPost(Post post) {
    state = state.copyWith(selectedRelatedPost: post, error: null);
  }

  void clearRelatedPost() {
    state = state.copyWith(selectedRelatedPost: null);
  }

  void goBack() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1, error: null);
    }
  }

  void reset() {
    state = const CreatePostState();
  }

  /// Returns `(Track, Post)` on success, or `null` on failure.
  Future<(Track, Post)?> submit({
    required String? title,
    required String? body,
    required String? mediaUrl,
  }) async {
    final track = state.selectedTrack;
    final mediaType = state.selectedMediaType;
    if (track == null || mediaType == null) return null;

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(createPostMutation),
          variables: {
            'trackId': track.id,
            'mediaType': mediaType.name,
            'title': title,
            'body': body,
            'mediaUrl': mediaUrl,
            'importance': state.importance,
          },
        ),
      );

      if (_disposed) return null;

      if (result.hasException) {
        state = state.copyWith(
          isSubmitting: false,
          error:
              result.exception?.graphqlErrors.firstOrNull?.message ??
              'Failed to create post',
        );
        return null;
      }

      final postData = result.data?['createPost'] as Map<String, dynamic>?;
      final post = postData != null ? Post.fromJson(postData) : null;

      if (post == null) {
        state = state.copyWith(isSubmitting: false);
        return null;
      }

      // Create connection to related post if selected (best-effort)
      var enrichedPost = post;
      final relatedPost = state.selectedRelatedPost;
      if (relatedPost != null) {
        final conn = await _createConnection(post.id, relatedPost.id);
        if (conn != null) {
          enrichedPost = Post(
            id: post.id,
            mediaType: post.mediaType,
            title: post.title,
            body: post.body,
            mediaUrl: post.mediaUrl,
            duration: post.duration,
            importance: post.importance,
            layoutX: post.layoutX,
            layoutY: post.layoutY,
            contentHash: post.contentHash,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt,
            author: post.author,
            trackId: post.trackId,
            trackName: post.trackName,
            trackColor: post.trackColor,
            reactionCounts: post.reactionCounts,
            myReactions: post.myReactions,
            outgoingConnections: [conn],
            incomingConnections: post.incomingConnections,
          );
        }
      }

      state = state.copyWith(isSubmitting: false);
      return (track, enrichedPost);
    } catch (e) {
      if (_disposed) return null;
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }

  Future<PostConnection?> _createConnection(
    String sourceId,
    String targetId,
  ) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(createConnectionMutation),
          variables: {
            'sourceId': sourceId,
            'targetId': targetId,
            'connectionType': 'reference',
          },
        ),
      );
      if (!result.hasException) {
        final data = result.data?['createConnection'] as Map<String, dynamic>?;
        if (data != null) return PostConnection.fromJson(data);
      }
    } catch (_) {
      // Best-effort: post is already created, connection failure is non-fatal.
    }
    return null;
  }
}

final createPostProvider =
    NotifierProvider.autoDispose<CreatePostNotifier, CreatePostState>(
      CreatePostNotifier.new,
    );
