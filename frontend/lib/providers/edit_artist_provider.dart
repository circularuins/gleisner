import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/mutations/artist.dart';
import '../graphql/mutations/genre.dart';
import '../graphql/mutations/track.dart';
import '../models/artist.dart';
import '../models/genre.dart';
import 'my_artist_provider.dart';

class EditArtistNotifier extends Notifier<AsyncValue<void>> {
  late GraphQLClient _client;

  @override
  AsyncValue<void> build() {
    _client = ref.watch(graphqlClientProvider);
    return const AsyncData(null);
  }

  Future<bool> updateArtist({
    String? displayName,
    String? bio,
    String? tagline,
    String? location,
    int? activeSince,
    String? avatarUrl,
    String? coverImageUrl,
    String? profileVisibility,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(updateArtistMutation),
          variables: {
            if (displayName != null) 'displayName': displayName,
            if (bio != null) 'bio': bio,
            if (tagline != null) 'tagline': tagline,
            if (location != null) 'location': location,
            if (activeSince != null) 'activeSince': activeSince,
            if (avatarUrl != null) 'avatarUrl': avatarUrl,
            if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
            if (profileVisibility != null)
              'profileVisibility': profileVisibility,
          },
        ),
      );

      if (result.hasException) {
        state = const AsyncData(null);
        return false;
      }

      // Refresh both caches
      await ref.read(myArtistProvider.notifier).load();
      state = const AsyncData(null);
      return true;
    } catch (e) {
      debugPrint('[EditArtistNotifier] updateArtist error: $e');
      state = const AsyncData(null);
      return false;
    }
  }

  Future<ArtistLink?> createLink({
    required String linkCategory,
    required String platform,
    required String url,
    int? position,
  }) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(createArtistLinkMutation),
          variables: {
            'linkCategory': linkCategory,
            'platform': platform,
            'url': url,
            if (position != null) 'position': position,
          },
        ),
      );

      if (result.hasException) return null;

      final data = result.data?['createArtistLink'] as Map<String, dynamic>?;
      if (data == null) return null;

      await ref.read(myArtistProvider.notifier).load();
      return ArtistLink.fromJson(data);
    } catch (e) {
      debugPrint('[EditArtistNotifier] createLink error: $e');
      return null;
    }
  }

  Future<bool> updateLink({
    required String id,
    String? linkCategory,
    String? platform,
    String? url,
    int? position,
  }) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(updateArtistLinkMutation),
          variables: {
            'id': id,
            if (linkCategory != null) 'linkCategory': linkCategory,
            if (platform != null) 'platform': platform,
            if (url != null) 'url': url,
            if (position != null) 'position': position,
          },
        ),
      );

      if (result.hasException) return false;

      await ref.read(myArtistProvider.notifier).load();
      return true;
    } catch (e) {
      debugPrint('[EditArtistNotifier] updateLink error: $e');
      return false;
    }
  }

  Future<bool> deleteLink(String id) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(deleteArtistLinkMutation),
          variables: {'id': id},
        ),
      );

      if (result.hasException) return false;

      await ref.read(myArtistProvider.notifier).load();
      return true;
    } catch (e) {
      debugPrint('[EditArtistNotifier] deleteLink error: $e');
      return false;
    }
  }

  /// Create a new genre and return it, or null on failure.
  Future<Genre?> createGenre(String name) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(createGenreMutation),
          variables: {'name': name},
        ),
      );
      if (result.hasException) return null;
      final data = result.data?['createGenre'] as Map<String, dynamic>?;
      if (data == null) return null;
      return Genre.fromJson(data);
    } catch (e) {
      debugPrint('[EditArtist] createGenre error: $e');
      return null;
    }
  }

  Future<bool> addGenre(String genreId, {int? position}) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(addArtistGenreMutation),
          variables: {
            'genreId': genreId,
            if (position != null) 'position': position,
          },
        ),
      );

      if (result.hasException) return false;

      await ref.read(myArtistProvider.notifier).load();
      return true;
    } catch (e) {
      debugPrint('[EditArtistNotifier] addGenre error: $e');
      return false;
    }
  }

  Future<bool> removeGenre(String genreId) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(removeArtistGenreMutation),
          variables: {'genreId': genreId},
        ),
      );

      if (result.hasException) return false;

      await ref.read(myArtistProvider.notifier).load();
      return true;
    } catch (e) {
      debugPrint('[EditArtistNotifier] removeGenre error: $e');
      return false;
    }
  }

  Future<bool> createTrack(String name, String color) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(createTrackMutation),
          variables: {'name': name, 'color': color},
        ),
      );

      if (result.hasException) return false;

      await ref.read(myArtistProvider.notifier).load();
      return true;
    } catch (e) {
      debugPrint('[EditArtistNotifier] createTrack error: $e');
      return false;
    }
  }

  Future<bool> deleteTrack(String id) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(deleteTrackMutation),
          variables: {'id': id},
        ),
      );

      if (result.hasException) return false;

      await ref.read(myArtistProvider.notifier).load();
      return true;
    } catch (e) {
      debugPrint('[EditArtistNotifier] deleteTrack error: $e');
      return false;
    }
  }
}

final editArtistProvider =
    NotifierProvider<EditArtistNotifier, AsyncValue<void>>(
      EditArtistNotifier.new,
    );
