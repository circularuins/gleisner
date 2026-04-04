import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../graphql/client.dart';
import '../graphql/mutations/media.dart';
import '../models/post.dart' show MediaType;
import '../utils/video_thumbnail.dart';
import '../utils/web_file_picker.dart';
import 'disposable_notifier.dart';

enum UploadCategory { avatars, covers, media }

class MediaUploadState {
  final bool isUploading;
  final double? progress;
  final String? error;

  const MediaUploadState({this.isUploading = false, this.progress, this.error});
}

// ── Magic bytes detection ──

const _jpegMagic = [0xFF, 0xD8, 0xFF];
const _pngMagic = [0x89, 0x50, 0x4E, 0x47];
const _webpPrefix = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
const _gifMagic = [0x47, 0x49, 0x46]; // "GIF"
const _ftypMagic = [0x66, 0x74, 0x79, 0x70]; // "ftyp" at offset 4
const _oggMagic = [0x4F, 0x67, 0x67, 0x53]; // "OggS"
const _webmMagic = [0x1A, 0x45, 0xDF, 0xA3]; // EBML header (WebM/MKV)
const _id3Magic = [0x49, 0x44, 0x33]; // "ID3"

/// Detect MIME type from file magic bytes.
/// Returns null if the file doesn't match any allowed format.
@visibleForTesting
String? mimeFromBytes(Uint8List bytes) {
  if (bytes.length < 12) return null;

  // Images
  if (_startsWith(bytes, _jpegMagic)) return 'image/jpeg';
  if (_startsWith(bytes, _pngMagic)) return 'image/png';
  if (_startsWith(bytes, _webpPrefix) &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  // RIFF/WAVE (WAV audio)
  if (_startsWith(bytes, _webpPrefix) &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x41 &&
      bytes[10] == 0x56 &&
      bytes[11] == 0x45) {
    return 'audio/wav';
  }
  if (_startsWith(bytes, _gifMagic)) return 'image/gif';

  // Video/Audio: MP4/M4A (ftyp box at offset 4)
  if (bytes.length >= 8 && _matchesAt(bytes, 4, _ftypMagic)) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (brand.startsWith('M4A')) return 'audio/mp4';
    return 'video/mp4';
  }

  // WebM (EBML header)
  if (_startsWith(bytes, _webmMagic)) return 'video/webm';

  // Ogg
  if (_startsWith(bytes, _oggMagic)) return 'audio/ogg';

  // MP3 (ID3 tag)
  if (_startsWith(bytes, _id3Magic)) return 'audio/mpeg';
  // MP3 sync word
  if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) return 'audio/mpeg';

  return null;
}

bool _startsWith(Uint8List data, List<int> prefix) {
  for (int i = 0; i < prefix.length; i++) {
    if (data[i] != prefix[i]) return false;
  }
  return true;
}

bool _matchesAt(Uint8List data, int offset, List<int> pattern) {
  if (data.length < offset + pattern.length) return false;
  for (int i = 0; i < pattern.length; i++) {
    if (data[offset + i] != pattern[i]) return false;
  }
  return true;
}

// ── DI providers ──

final httpClientProvider = Provider<http.Client>((ref) => http.Client());

// ── Notifier ──

class MediaUploadNotifier extends Notifier<MediaUploadState>
    with DisposableNotifier<MediaUploadState> {
  late GraphQLClient _gqlClient;
  late http.Client _httpClient;

  @override
  MediaUploadState build() {
    _gqlClient = ref.watch(graphqlClientProvider);
    _httpClient = ref.watch(httpClientProvider);
    initDisposable();
    return const MediaUploadState();
  }

  /// Pick an image and upload to R2.
  Future<String?> pickAndUploadImage({
    required UploadCategory category,
    ImageSource source = ImageSource.gallery,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    if (state.isUploading) return null;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: maxWidth ?? 1280,
        maxHeight: maxHeight ?? 1280,
        imageQuality: imageQuality ?? 75,
      );

      if (picked == null) return null;
      if (disposed) return null;

      final bytes = await picked.readAsBytes();
      if (disposed) return null;

      final contentType = mimeFromBytes(bytes);
      if (contentType == null || !contentType.startsWith('image/')) {
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

  /// Pick a video via image_picker and upload to R2.
  /// Returns (videoUrl, thumbnailUrl) on success, null on failure.
  Future<({String videoUrl, String? thumbnailUrl})?> pickAndUploadVideo({
    required UploadCategory category,
  }) async {
    if (state.isUploading) return null;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);

      if (picked == null) return null;
      if (disposed) return null;

      final bytes = await picked.readAsBytes();
      if (disposed) return null;

      final contentType = mimeFromBytes(bytes);
      if (contentType == null ||
          !(contentType.startsWith('video/') ||
              contentType.startsWith('audio/'))) {
        state = const MediaUploadState(
          error: 'Unsupported video format. Use MP4 or WebM.',
        );
        return null;
      }

      // Upload video
      final videoUrl = await _upload(
        category: category,
        bytes: bytes,
        contentType: contentType,
      );
      if (videoUrl == null) return null;
      if (disposed) return null;

      // Generate and upload thumbnail
      String? thumbnailUrl;
      try {
        final thumbBytes = await captureVideoThumbnail(
          bytes,
          mimeType: contentType,
        );
        if (thumbBytes != null && !disposed) {
          thumbnailUrl = await _upload(
            category: category,
            bytes: thumbBytes,
            contentType: 'image/jpeg',
          );
        }
      } catch (e) {
        debugPrint('[MediaUpload] thumbnail generation failed: $e');
        // Non-fatal: video uploaded successfully, thumbnail is optional
      }

      return (videoUrl: videoUrl, thumbnailUrl: thumbnailUrl);
    } catch (e) {
      debugPrint('[MediaUpload] pickAndUploadVideo error: $e');
      if (!disposed) {
        state = const MediaUploadState(
          error: 'Failed to upload video. Please try again.',
        );
      }
      return null;
    }
  }

  /// Pick an audio file using the browser's native file input.
  Future<String?> pickAndUploadAudio({required UploadCategory category}) async {
    if (state.isUploading) return null;

    try {
      final result = await pickFileFromBrowser(
        accept: 'audio/*,.mp3,.m4a,.ogg,.webm,.wav',
      );

      if (result == null) return null;
      if (disposed) return null;

      final (bytes, _) = result;

      final contentType = mimeFromBytes(bytes);
      if (contentType == null || !contentType.startsWith('audio/')) {
        state = const MediaUploadState(
          error: 'Unsupported audio format. Use MP3, M4A, OGG, or WebM.',
        );
        return null;
      }

      return await _upload(
        category: category,
        bytes: bytes,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint('[MediaUpload] pickAndUploadAudio error: $e');
      if (!disposed) {
        state = const MediaUploadState(
          error: 'Failed to upload audio. Please try again.',
        );
      }
      return null;
    }
  }

  Future<String?> _upload({
    required UploadCategory category,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (disposed) return null;
    state = const MediaUploadState(isUploading: true, progress: 0);

    final mutationResult = await _gqlClient.mutate(
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

    if (mutationResult.hasException) {
      debugPrint(
        '[MediaUpload] getUploadUrl error: '
        '${mutationResult.exception?.graphqlErrors.firstOrNull?.message}',
      );
      state = const MediaUploadState(
        error: 'Failed to prepare upload. Please try again.',
      );
      return null;
    }

    final data = mutationResult.data?['getUploadUrl'] as Map<String, dynamic>?;
    if (data == null) {
      state = const MediaUploadState(
        error: 'Failed to prepare upload. Please try again.',
      );
      return null;
    }

    final uploadUrl = data['uploadUrl'] as String;
    final publicUrl = data['publicUrl'] as String;

    if (!isAllowedUploadUrl(uploadUrl) || !isAllowedPublicUrl(publicUrl)) {
      debugPrint(
        '[MediaUpload] URL validation failed: $uploadUrl / $publicUrl',
      );
      state = const MediaUploadState(
        error: 'Failed to prepare upload. Please try again.',
      );
      return null;
    }

    state = const MediaUploadState(isUploading: true, progress: 0.5);

    final response = await _httpClient.put(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': contentType,
        'Content-Length': bytes.length.toString(),
      },
      body: bytes,
    );

    if (disposed) return null;

    if (response.statusCode != 200) {
      debugPrint('[MediaUpload] R2 PUT failed: ${response.statusCode}');
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

  /// Convenience method to pick and upload based on media type.
  /// Returns ({mediaUrl, thumbnailUrl}) for all types.
  /// Centralizes the pick logic so create_post and edit_post don't duplicate.
  Future<({String mediaUrl, String? thumbnailUrl})?> pickByMediaType(
    MediaType mediaType,
  ) async {
    switch (mediaType) {
      case MediaType.image:
        final url = await pickAndUploadImage(
          category: UploadCategory.media,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 75,
        );
        if (url == null) return null;
        return (mediaUrl: url, thumbnailUrl: null);
      case MediaType.video:
        final result = await pickAndUploadVideo(category: UploadCategory.media);
        if (result == null) return null;
        return (mediaUrl: result.videoUrl, thumbnailUrl: result.thumbnailUrl);
      case MediaType.audio:
        final url = await pickAndUploadAudio(category: UploadCategory.media);
        if (url == null) return null;
        return (mediaUrl: url, thumbnailUrl: null);
      default:
        return null;
    }
  }

  @visibleForTesting
  static bool isAllowedUploadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    return uri.host.endsWith('.r2.cloudflarestorage.com');
  }

  @visibleForTesting
  static bool isAllowedPublicUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    final host = uri.host;
    return host.endsWith('.r2.dev') || host.endsWith('.gleisner.app');
  }
}

final mediaUploadProvider =
    NotifierProvider<MediaUploadNotifier, MediaUploadState>(
      MediaUploadNotifier.new,
    );
