import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../graphql/client.dart';
import '../graphql/mutations/media.dart';

enum UploadCategory { avatars, covers, media }

class MediaUploadState {
  final bool isUploading;
  final double? progress;
  final String? error;

  const MediaUploadState({this.isUploading = false, this.progress, this.error});
}

class MediaUploadNotifier extends Notifier<MediaUploadState> {
  late GraphQLClient _client;

  @override
  MediaUploadState build() {
    _client = ref.watch(graphqlClientProvider);
    return const MediaUploadState();
  }

  /// Pick an image from gallery or camera and upload to R2.
  /// Returns the public URL on success, null on failure or cancellation.
  Future<String?> pickAndUploadImage({
    required UploadCategory category,
    ImageSource source = ImageSource.gallery,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    state = const MediaUploadState(isUploading: false);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: maxWidth ?? 1200,
        maxHeight: maxHeight ?? 1200,
        imageQuality: imageQuality ?? 85,
      );

      if (picked == null) return null; // User cancelled

      final bytes = await picked.readAsBytes();
      final contentType = _mimeFromPath(picked.name);

      return await _upload(
        category: category,
        bytes: bytes,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint('[MediaUpload] pickAndUploadImage error: $e');
      state = const MediaUploadState(
        error: 'Failed to upload image. Please try again.',
      );
      return null;
    }
  }

  /// Upload raw bytes to R2 via presigned URL.
  Future<String?> _upload({
    required UploadCategory category,
    required Uint8List bytes,
    required String contentType,
  }) async {
    state = const MediaUploadState(isUploading: true, progress: 0);

    // Step 1: Get presigned URL from backend
    final result = await _client.mutate(
      MutationOptions(
        document: gql(getUploadUrlMutation),
        variables: {
          'category': category.name,
          'contentType': contentType,
          'contentLength': bytes.length,
        },
      ),
    );

    if (result.hasException) {
      final message =
          result.exception?.graphqlErrors.firstOrNull?.message ??
          'Failed to prepare upload';
      debugPrint('[MediaUpload] getUploadUrl error: $message');
      state = const MediaUploadState(
        error: 'Failed to prepare upload. Please try again.',
      );
      return null;
    }

    final data = result.data?['getUploadUrl'] as Map<String, dynamic>?;
    if (data == null) {
      state = const MediaUploadState(
        error: 'Failed to prepare upload. Please try again.',
      );
      return null;
    }

    final uploadUrl = data['uploadUrl'] as String;
    final publicUrl = data['publicUrl'] as String;

    // Step 2: PUT file directly to R2
    state = const MediaUploadState(isUploading: true, progress: 0.5);

    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (response.statusCode != 200) {
      debugPrint(
        '[MediaUpload] R2 PUT failed: ${response.statusCode} ${response.body}',
      );
      state = const MediaUploadState(
        error: 'Failed to upload file. Please try again.',
      );
      return null;
    }

    state = const MediaUploadState(isUploading: false, progress: 1.0);
    return publicUrl;
  }

  void clearError() {
    state = const MediaUploadState();
  }

  static String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}

final mediaUploadProvider =
    NotifierProvider<MediaUploadNotifier, MediaUploadState>(
      MediaUploadNotifier.new,
    );
