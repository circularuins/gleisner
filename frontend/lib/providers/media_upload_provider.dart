import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../graphql/client.dart';
import '../graphql/mutations/media.dart';
import 'disposable_notifier.dart';

enum UploadCategory { avatars, covers, media }

class MediaUploadState {
  final bool isUploading;
  final double? progress;
  final String? error;

  const MediaUploadState({this.isUploading = false, this.progress, this.error});
}

/// Magic bytes for allowed image types.
const _jpegMagic = [0xFF, 0xD8, 0xFF];
const _pngMagic = [0x89, 0x50, 0x4E, 0x47];
const _webpPrefix = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
const _gifMagic = [0x47, 0x49, 0x46]; // "GIF"

/// Detect MIME type from file magic bytes. Returns null if unrecognized.
String? _mimeFromBytes(Uint8List bytes) {
  if (bytes.length < 12) return null;
  if (_startsWith(bytes, _jpegMagic)) return 'image/jpeg';
  if (_startsWith(bytes, _pngMagic)) return 'image/png';
  if (_startsWith(bytes, _webpPrefix) &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  if (_startsWith(bytes, _gifMagic)) return 'image/gif';
  return null;
}

bool _startsWith(Uint8List data, List<int> prefix) {
  for (int i = 0; i < prefix.length; i++) {
    if (data[i] != prefix[i]) return false;
  }
  return true;
}

class MediaUploadNotifier extends Notifier<MediaUploadState>
    with DisposableNotifier<MediaUploadState> {
  late GraphQLClient _client;

  @override
  MediaUploadState build() {
    _client = ref.watch(graphqlClientProvider);
    initDisposable();
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
    // Guard against double-tap / concurrent uploads
    if (state.isUploading) return null;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: maxWidth ?? 1200,
        maxHeight: maxHeight ?? 1200,
        imageQuality: imageQuality ?? 85,
      );

      if (picked == null) return null; // User cancelled
      if (disposed) return null;

      final bytes = await picked.readAsBytes();
      if (disposed) return null;

      // Validate content type from magic bytes, not file extension
      final contentType = _mimeFromBytes(bytes);
      if (contentType == null) {
        state = const MediaUploadState(
          error: 'Unsupported image format. Use JPEG, PNG, or WebP.',
        );
        return null;
      }

      return await _upload(
        category: category,
        bytes: bytes,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint('[MediaUpload] pickAndUploadImage error: $e');
      if (!disposed) {
        state = const MediaUploadState(
          error: 'Failed to upload image. Please try again.',
        );
      }
      return null;
    }
  }

  /// Upload raw bytes to R2 via presigned URL.
  Future<String?> _upload({
    required UploadCategory category,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (disposed) return null;
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

    if (disposed) return null;

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

    if (disposed) return null;

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
    if (!disposed) {
      state = const MediaUploadState();
    }
  }
}

final mediaUploadProvider =
    NotifierProvider<MediaUploadNotifier, MediaUploadState>(
      MediaUploadNotifier.new,
    );
