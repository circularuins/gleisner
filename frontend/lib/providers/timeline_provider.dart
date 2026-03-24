import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/artist.dart';
import '../graphql/mutations/connection.dart';
import '../graphql/mutations/constellation.dart';
import '../graphql/mutations/reaction.dart';
import '../graphql/mutations/track.dart';
import '../graphql/queries/post.dart';
import '../models/artist.dart';
import '../models/post.dart';
import '../models/track.dart';
import '../utils/constellation_layout.dart';
import '../utils/sentinel.dart';

class TimelineState {
  final Artist? artist;
  final Set<String> selectedTrackIds;
  final List<Post> posts;
  final bool isLoading;
  final String? error;
  final LayoutResult? layout;
  final String? highlightPostId;
  final Set<String>? constellationPostIds;

  const TimelineState({
    this.artist,
    this.selectedTrackIds = const {},
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.layout,
    this.highlightPostId,
    this.constellationPostIds,
  });

  bool get allSelected =>
      artist != null &&
      artist!.tracks.isNotEmpty &&
      selectedTrackIds.length == artist!.tracks.length;

  bool get noneSelected => selectedTrackIds.isEmpty;

  TimelineState copyWith({
    Object? artist = sentinel,
    Set<String>? selectedTrackIds,
    List<Post>? posts,
    bool? isLoading,
    Object? error = sentinel,
    Object? layout = sentinel,
    Object? highlightPostId = sentinel,
    Object? constellationPostIds = sentinel,
  }) {
    return TimelineState(
      artist: artist == sentinel ? this.artist : artist as Artist?,
      selectedTrackIds: selectedTrackIds ?? this.selectedTrackIds,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error == sentinel ? this.error : error as String?,
      layout: layout == sentinel ? this.layout : layout as LayoutResult?,
      highlightPostId: highlightPostId == sentinel
          ? this.highlightPostId
          : highlightPostId as String?,
      constellationPostIds: constellationPostIds == sentinel
          ? this.constellationPostIds
          : constellationPostIds as Set<String>?,
    );
  }
}

class TimelineNotifier extends StateNotifier<TimelineState> {
  final GraphQLClient _client;
  double _lastWidth = 0;

  TimelineNotifier(this._client) : super(const TimelineState());

  /// For testing only — set state directly.
  @visibleForTesting
  void debugSetState(TimelineState newState) => state = newState;

  /// For testing only — add a track to state.
  @visibleForTesting
  void debugAddTrack(Track track) => _addTrackToState(track);

  Future<void> loadArtist(String username) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _client.query(
        QueryOptions(
          document: gql(artistQuery),
          variables: {'username': username},
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        state = state.copyWith(
          isLoading: false,
          error:
              result.exception?.graphqlErrors.firstOrNull?.message ??
              'Failed to load artist',
        );
        return;
      }

      final data = result.data?['artist'];
      if (data == null) {
        state = state.copyWith(
          isLoading: false,
          artist: null,
          selectedTrackIds: {},
          posts: [],
          layout: null,
        );
        return;
      }

      final artist = Artist.fromJson(data as Map<String, dynamic>);
      // Default: all tracks selected
      final allIds = artist.tracks.map((t) => t.id).toSet();
      state = state.copyWith(
        artist: artist,
        selectedTrackIds: allIds,
        isLoading: artist.tracks.isNotEmpty,
      );

      if (artist.tracks.isNotEmpty) {
        await _loadSelectedPosts();
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a new track via API and add it to local state.
  /// Returns `(Track, null)` on success, `(null, errorMessage)` on failure.
  Future<(Track?, String?)> createTrack(String name, String color) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(createTrackMutation),
          variables: {'name': name, 'color': color},
        ),
      );

      if (result.hasException) {
        final message =
            result.exception?.graphqlErrors.firstOrNull?.message ??
            'Failed to create track';
        return (null, message);
      }

      final data = result.data?['createTrack'] as Map<String, dynamic>?;
      if (data == null) return (null, 'No data returned');

      final track = Track.fromJson(data);
      _addTrackToState(track);
      return (track, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  void _addTrackToState(Track track) {
    final artist = state.artist;
    if (artist == null) return;
    final updatedArtist = artist.withTrack(track);
    final ids = Set<String>.from(state.selectedTrackIds)..add(track.id);
    state = state.copyWith(artist: updatedArtist, selectedTrackIds: ids);
  }

  /// Toggle a reaction on a post with optimistic local update.
  /// Returns true on success.
  Future<bool> toggleReaction(String postId, String emoji) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(toggleReactionMutation),
          variables: {'postId': postId, 'emoji': emoji},
        ),
      );
      if (result.hasException) return false;

      // Optimistic update: toggle myReactions + counts locally
      final post = state.posts.firstWhere((p) => p.id == postId);
      final myR = List<String>.from(post.myReactions);
      final counts = List<ReactionCount>.from(post.reactionCounts);
      if (myR.contains(emoji)) {
        myR.remove(emoji);
        final idx = counts.indexWhere((c) => c.emoji == emoji);
        if (idx >= 0) {
          final n = counts[idx].count - 1;
          if (n <= 0) {
            counts.removeAt(idx);
          } else {
            counts[idx] = ReactionCount(emoji: emoji, count: n);
          }
        }
      } else {
        myR.add(emoji);
        final idx = counts.indexWhere((c) => c.emoji == emoji);
        if (idx >= 0) {
          counts[idx] = ReactionCount(
            emoji: emoji,
            count: counts[idx].count + 1,
          );
        } else {
          counts.add(ReactionCount(emoji: emoji, count: 1));
        }
      }
      counts.sort((a, b) => b.count.compareTo(a.count));
      updatePostReactions(postId, counts, myR);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Create a connection between two posts. Returns the connection on success.
  Future<PostConnection?> createConnection(
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
    } catch (_) {}
    return null;
  }

  /// Delete a connection. Returns true on success.
  Future<bool> deleteConnection(String connectionId) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(deleteConnectionMutation),
          variables: {'id': connectionId},
        ),
      );
      return !result.hasException;
    } catch (_) {
      return false;
    }
  }

  /// Add a connection to both source and target posts, then recompute layout.
  void addConnectionToState(PostConnection conn) {
    final posts = state.posts.map((p) {
      if (p.id == conn.sourceId) {
        return _copyPostWith(
          p,
          outgoingConnections: [...p.outgoingConnections, conn],
        );
      }
      if (p.id == conn.targetId) {
        return _copyPostWith(
          p,
          incomingConnections: [...p.incomingConnections, conn],
        );
      }
      return p;
    }).toList();
    state = state.copyWith(posts: posts);
    _recomputeLayout();
  }

  /// Remove a connection from both source and target posts, then recompute layout.
  void removeConnectionFromState(PostConnection conn) {
    final posts = state.posts.map((p) {
      if (p.id == conn.sourceId) {
        return _copyPostWith(
          p,
          outgoingConnections: p.outgoingConnections
              .where((c) => c.id != conn.id)
              .toList(),
        );
      }
      if (p.id == conn.targetId) {
        return _copyPostWith(
          p,
          incomingConnections: p.incomingConnections
              .where((c) => c.id != conn.id)
              .toList(),
        );
      }
      return p;
    }).toList();
    state = state.copyWith(posts: posts);
    _recomputeLayout();
  }

  static Post _copyPostWith(
    Post p, {
    List<PostConnection>? outgoingConnections,
    List<PostConnection>? incomingConnections,
  }) {
    return Post(
      id: p.id,
      mediaType: p.mediaType,
      title: p.title,
      body: p.body,
      mediaUrl: p.mediaUrl,
      duration: p.duration,
      importance: p.importance,
      layoutX: p.layoutX,
      layoutY: p.layoutY,
      contentHash: p.contentHash,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      author: p.author,
      trackId: p.trackId,
      trackName: p.trackName,
      trackColor: p.trackColor,
      reactionCounts: p.reactionCounts,
      myReactions: p.myReactions,
      outgoingConnections: outgoingConnections ?? p.outgoingConnections,
      incomingConnections: incomingConnections ?? p.incomingConnections,
      constellation: p.constellation,
    );
  }

  /// Update reaction counts and user's own reactions for a post.
  void updatePostReactions(
    String postId,
    List<ReactionCount> counts,
    List<String> myReactions,
  ) {
    final posts = state.posts.map((p) {
      if (p.id == postId) {
        return Post(
          id: p.id,
          mediaType: p.mediaType,
          title: p.title,
          body: p.body,
          mediaUrl: p.mediaUrl,
          duration: p.duration,
          importance: p.importance,
          layoutX: p.layoutX,
          layoutY: p.layoutY,
          contentHash: p.contentHash,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          author: p.author,
          trackId: p.trackId,
          trackName: p.trackName,
          trackColor: p.trackColor,
          reactionCounts: counts,
          myReactions: myReactions,
          outgoingConnections: p.outgoingConnections,
          incomingConnections: p.incomingConnections,
          constellation: p.constellation,
        );
      }
      return p;
    }).toList();
    // Update posts and patch layout nodes without recalculating positions.
    // Node sizes stay the same until next full refresh — avoids jarring
    // layout shifts when reacting.
    final layout = state.layout;
    if (layout != null) {
      final postMap = {for (final p in posts) p.id: p};
      final patchedNodes = layout.nodes.map((n) {
        final updated = postMap[n.post.id];
        if (updated != null && updated != n.post) {
          // Recalculate size from updated reactions, keep position
          final sz = ConstellationLayout.nodeSize(
            updated.importance,
            reactionCount: updated.totalReactions,
          );
          final isAudio = updated.mediaType == MediaType.audio;
          final w = isAudio
              ? min(sz * 1.8, _lastWidth - ConstellationLayout.spineWidth - 20)
              : sz > 110
              ? min(sz * 1.25, _lastWidth - ConstellationLayout.spineWidth - 20)
              : sz;
          final mediaH = isAudio
              ? sz * 0.45
              : sz > 110
              ? sz * 0.7
              : sz * 0.85;
          return PlacedNode(
            post: updated,
            x: n.x,
            y: n.y,
            width: w,
            height: mediaH + (isAudio ? 0 : 30),
            nodeSize: sz,
            mediaHeight: mediaH,
            showInfo: !isAudio,
          );
        }
        return n;
      }).toList();
      state = state.copyWith(
        posts: posts,
        layout: LayoutResult(
          nodes: patchedNodes,
          days: layout.days,
          connections: layout.connections,
          totalHeight: layout.totalHeight,
        ),
      );
    } else {
      state = state.copyWith(posts: posts);
    }
  }

  void addPost(Post post) {
    final posts = [...state.posts, post];
    state = state.copyWith(posts: posts, highlightPostId: post.id);
    _recomputeLayout();
    // Clear highlight after animation completes
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted && state.highlightPostId == post.id) {
        state = state.copyWith(highlightPostId: null);
      }
    });
  }

  /// Add a track ID to selectedTrackIds without fetching (sync).
  void ensureTrackSelected(String trackId) {
    final ids = Set<String>.from(state.selectedTrackIds);
    if (!ids.contains(trackId)) {
      ids.add(trackId);
      state = state.copyWith(selectedTrackIds: ids);
    }
  }

  /// Toggle a single track on/off.
  Future<void> toggleTrack(String trackId) async {
    final ids = Set<String>.from(state.selectedTrackIds);
    if (ids.contains(trackId)) {
      ids.remove(trackId);
    } else {
      ids.add(trackId);
    }
    state = state.copyWith(selectedTrackIds: ids, layout: null);
    await _loadSelectedPosts();
  }

  /// Toggle all tracks: if all selected → deselect all, else select all.
  Future<void> toggleAll() async {
    final artist = state.artist;
    if (artist == null) return;

    final Set<String> ids;
    if (state.allSelected) {
      ids = {};
    } else {
      ids = artist.tracks.map((t) => t.id).toSet();
    }
    state = state.copyWith(selectedTrackIds: ids, layout: null);
    await _loadSelectedPosts();
  }

  Future<void> _loadSelectedPosts() async {
    final artist = state.artist;
    if (artist == null) return;

    final trackIds = state.selectedTrackIds;
    if (trackIds.isEmpty) {
      state = state.copyWith(posts: [], isLoading: false, layout: null);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final futures = trackIds.map(
        (tid) => _client.query(
          QueryOptions(
            document: gql(postsQuery),
            variables: {'trackId': tid},
            fetchPolicy: FetchPolicy.networkOnly,
          ),
        ),
      );

      final results = await Future.wait(futures);

      if (!mounted) return;

      final allPosts = <Post>[];
      var failedCount = 0;
      for (final result in results) {
        if (result.hasException) {
          failedCount++;
          continue;
        }
        final postsData = result.data?['posts'] as List<dynamic>? ?? [];
        allPosts.addAll(
          postsData.map((p) => Post.fromJson(p as Map<String, dynamic>)),
        );
      }

      final error = failedCount > 0
          ? 'Failed to load $failedCount of ${results.length} tracks'
          : null;
      state = state.copyWith(posts: allPosts, isLoading: false, error: error);
      _recomputeLayout();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // TODO: Move to Isolate.run() for large datasets (O(n^2) overlap check)
  void computeLayout(double width) {
    _lastWidth = width;
    _recomputeLayout();
  }

  void _recomputeLayout() {
    if (state.posts.isEmpty || _lastWidth == 0) {
      state = state.copyWith(layout: null);
      return;
    }
    final result = ConstellationLayout.compute(
      posts: state.posts,
      containerWidth: _lastWidth,
    );
    state = state.copyWith(layout: result);
  }

  /// Name or rename a constellation. Returns the constellation on success.
  Future<PostConstellation?> nameConstellation(
    String postId,
    String name,
  ) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(nameConstellationMutation),
          variables: {'postId': postId, 'name': name},
        ),
      );
      if (!result.hasException) {
        final data = result.data?['nameConstellation'] as Map<String, dynamic>?;
        if (data != null) {
          final constellation = PostConstellation.fromJson(data);
          // Refresh to pick up constellation data on all posts
          await _loadSelectedPosts();
          return constellation;
        }
      }
    } catch (_) {}
    return null;
  }

  void showConstellation(Set<String> postIds) {
    state = state.copyWith(constellationPostIds: postIds);
  }

  void clearConstellation() {
    state = state.copyWith(constellationPostIds: null);
  }

  Future<void> refresh() async {
    await _loadSelectedPosts();
  }
}

final timelineProvider = StateNotifierProvider<TimelineNotifier, TimelineState>(
  (ref) {
    final client = ref.watch(graphqlClientProvider);
    return TimelineNotifier(client);
  },
);
