import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
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

  const CreatePostState({
    this.step = 0,
    this.selectedTrack,
    this.selectedMediaType,
    this.importance = 0.5,
    this.isSubmitting = false,
    this.error,
  });

  CreatePostState copyWith({
    int? step,
    Object? selectedTrack = sentinel,
    Object? selectedMediaType = sentinel,
    double? importance,
    bool? isSubmitting,
    Object? error = sentinel,
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
    );
  }
}

class CreatePostNotifier extends StateNotifier<CreatePostState> {
  final GraphQLClient _client;

  CreatePostNotifier(this._client) : super(const CreatePostState());

  void selectTrack(Track track) {
    state = state.copyWith(selectedTrack: track, step: 1, error: null);
  }

  void selectMediaType(MediaType mediaType) {
    state = state.copyWith(selectedMediaType: mediaType, step: 2, error: null);
  }

  void setImportance(double value) {
    state = state.copyWith(importance: value);
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

      if (!mounted) return null;

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
      state = state.copyWith(isSubmitting: false);
      return post != null ? (track, post) : null;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }
}

final createPostProvider =
    StateNotifierProvider.autoDispose<CreatePostNotifier, CreatePostState>((
      ref,
    ) {
      final client = ref.watch(graphqlClientProvider);
      return CreatePostNotifier(client);
    });
