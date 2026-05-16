import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import 'create_post_draft_provider.dart';
import 'disposable_notifier.dart';
import '../graphql/mutations/connection.dart';
import '../graphql/mutations/post.dart';
import '../models/create_post_draft.dart';
import '../models/post.dart';
import '../models/track.dart';
import '../services/create_post_draft_service.dart';
import '../utils/sentinel.dart';

/// A pending connection: target post + connection type.
typedef PendingConnection = ({Post post, ConnectionType connectionType});

class CreatePostState {
  final int step; // 0: track, 1: mediaType, 2: form
  final Track? selectedTrack;
  final MediaType? selectedMediaType;
  final double importance;
  final String visibility;
  final bool isSubmitting;
  final String? error;
  final List<PendingConnection> selectedConnections;
  final ArticleGenre? articleGenre;
  final bool externalPublish;

  const CreatePostState({
    this.step = 0,
    this.selectedTrack,
    this.selectedMediaType,
    this.importance = 0.5,
    this.visibility = 'public',
    this.isSubmitting = false,
    this.error,
    this.selectedConnections = const [],
    this.articleGenre,
    this.externalPublish = false,
  });

  CreatePostState copyWith({
    int? step,
    Object? selectedTrack = sentinel,
    Object? selectedMediaType = sentinel,
    double? importance,
    String? visibility,
    bool? isSubmitting,
    Object? error = sentinel,
    List<PendingConnection>? selectedConnections,
    Object? articleGenre = sentinel,
    bool? externalPublish,
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
      visibility: visibility ?? this.visibility,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error == sentinel ? this.error : error as String?,
      selectedConnections: selectedConnections ?? this.selectedConnections,
      articleGenre: articleGenre == sentinel
          ? this.articleGenre
          : articleGenre as ArticleGenre?,
      externalPublish: externalPublish ?? this.externalPublish,
    );
  }
}

class CreatePostNotifier extends Notifier<CreatePostState>
    with DisposableNotifier {
  late GraphQLClient _client;
  late CreatePostDraftService _draftService;

  @override
  CreatePostState build() {
    _client = ref.watch(graphqlClientProvider);
    _draftService = ref.watch(createPostDraftServiceProvider);
    initDisposable();
    return const CreatePostState();
  }

  /// Restore meta-state (track, mediaType, visibility, etc.) from a draft.
  /// Text fields (title/body/quill/media URLs) are restored by the screen
  /// directly into its TextEditingControllers — the Notifier does not own
  /// them. [resolvedTrack] is looked up by the screen from the user's own
  /// tracks; if null (the track was deleted since the draft was saved),
  /// the draft is restored with no track selected and step clamped to 0.
  void restoreFromDraft(CreatePostDraft draft, {Track? resolvedTrack}) {
    final track = resolvedTrack;
    final mediaType = draft.selectedMediaType;
    // Clamp step backward when the upstream selections are missing so the
    // form doesn't try to render step 2 without a track.
    var step = draft.step;
    if (track == null) {
      step = 0;
    } else if (mediaType == null && step >= 2) {
      step = 1;
    }
    state = CreatePostState(
      step: step,
      selectedTrack: track,
      selectedMediaType: mediaType,
      visibility: draft.visibility,
      importance: draft.importance,
      articleGenre: draft.articleGenre,
      externalPublish: draft.externalPublish,
      selectedConnections: const [],
    );
  }

  /// Persist the current composer state alongside text-field values from
  /// the screen. Debounce is owned by the screen.
  Future<void> persistDraft({
    required String userId,
    required String title,
    required String body,
    String? bodyFormat,
    String? mediaUrl,
    List<String>? mediaUrls,
    String? thumbnailUrl,
    int? durationSeconds,
    DateTime? eventAt,
  }) async {
    final draft = CreatePostDraft(
      userId: userId,
      step: state.step,
      selectedTrackId: state.selectedTrack?.id,
      selectedMediaType: state.selectedMediaType,
      visibility: state.visibility,
      importance: state.importance,
      articleGenre: state.articleGenre,
      externalPublish: state.externalPublish,
      title: title,
      body: body,
      bodyFormat: bodyFormat,
      mediaUrl: mediaUrl,
      mediaUrls: mediaUrls,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      eventAt: eventAt,
      savedAt: DateTime.now().toUtc(),
    );
    await _draftService.save(draft);
  }

  Future<CreatePostDraft?> loadDraft(String userId) =>
      _draftService.load(userId);

  Future<void> clearDraft(String userId) => _draftService.clear(userId);

  void selectTrack(Track track) {
    state = state.copyWith(selectedTrack: track, step: 1, error: null);
  }

  void selectMediaType(MediaType mediaType) {
    state = state.copyWith(selectedMediaType: mediaType, step: 2, error: null);
  }

  void setImportance(double value) {
    state = state.copyWith(importance: value);
  }

  void setVisibility(String value) {
    state = state.copyWith(visibility: value);
    // Clear externalPublish when switching to draft
    if (value != 'public' && state.externalPublish) {
      state = state.copyWith(externalPublish: false);
    }
  }

  void setArticleGenre(ArticleGenre? genre) {
    state = state.copyWith(articleGenre: genre);
  }

  void setExternalPublish(bool value) {
    state = state.copyWith(externalPublish: value);
  }

  void addConnection(Post post, ConnectionType connectionType) {
    if (state.selectedConnections.length >= 5) return;
    // Prevent duplicate target
    if (state.selectedConnections.any((c) => c.post.id == post.id)) return;
    state = state.copyWith(
      selectedConnections: [
        ...state.selectedConnections,
        (post: post, connectionType: connectionType),
      ],
      error: null,
    );
  }

  void removeConnection(String postId) {
    state = state.copyWith(
      selectedConnections: state.selectedConnections
          .where((c) => c.post.id != postId)
          .toList(),
    );
  }

  void goBack() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1, error: null);
    }
  }

  /// Clear form-level state (connections, importance, visibility) without
  /// resetting track/mediaType selection. Called when going back from form step.
  void clearFormState() {
    state = state.copyWith(
      importance: 0.5,
      visibility: 'public',
      selectedConnections: const [],
      error: null,
    );
  }

  void reset() {
    state = const CreatePostState();
  }

  /// Returns `(Track, Post)` on success, or `null` on failure.
  Future<(Track, Post)?> submit({
    required String? title,
    required String? body,
    String? bodyFormat,
    required String? mediaUrl,
    List<String>? mediaUrls,
    String? thumbnailUrl,
    int? duration,
    DateTime? eventAt,
  }) async {
    if (state.isSubmitting) return null;
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
            'bodyFormat': ?bodyFormat,
            'mediaUrl': ?mediaUrl,
            'mediaUrls': ?mediaUrls,
            'thumbnailUrl': ?thumbnailUrl,
            'duration': ?duration,
            // Always serialize as UTC. `EventAtPicker` returns a local DateTime;
            // `toIso8601String()` on a local DateTime omits the timezone offset,
            // which the backend would interpret as server-local (UTC on Railway)
            // and store the wrong absolute time. See PR / Issue for details.
            if (eventAt != null) 'eventAt': eventAt.toUtc().toIso8601String(),
            'importance': state.importance,
            'visibility': state.visibility,
            if (state.articleGenre != null)
              'articleGenre': state.articleGenre!.name,
            if (state.externalPublish) 'externalPublish': true,
          },
        ),
      );

      if (disposed) return null;

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

      // Create connections to related posts (best-effort, parallel)
      var enrichedPost = post;
      final results = await Future.wait(
        state.selectedConnections.map(
          (pending) => _createConnection(
            post.id,
            pending.post.id,
            connectionType: pending.connectionType,
          ),
        ),
      );
      if (disposed) return null;
      final connections = results.whereType<PostConnection>().toList();
      if (connections.isNotEmpty) {
        enrichedPost = post.copyWith(outgoingConnections: connections);
      }

      state = state.copyWith(isSubmitting: false);
      return (track, enrichedPost);
    } catch (e) {
      if (disposed) return null;
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return null;
    }
  }

  Future<PostConnection?> _createConnection(
    String sourceId,
    String targetId, {
    ConnectionType connectionType = ConnectionType.reference,
  }) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(createConnectionMutation),
          variables: {
            'sourceId': sourceId,
            'targetId': targetId,
            'connectionType': connectionType.name,
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
