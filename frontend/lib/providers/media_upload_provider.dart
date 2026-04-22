import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../graphql/client.dart';
import '../graphql/mutations/media.dart';
import '../l10n/l10n.dart';
import '../models/post.dart' show MediaType;
import '../utils/media_limits.dart';
import '../utils/heic_converter.dart';
import '../utils/image_sanitizer.dart';
import '../utils/video_thumbnail.dart';
import '../utils/audio_duration.dart';
import '../utils/web_file_picker.dart';
import 'disposable_notifier.dart';

typedef ImageSanitizer =
    Future<({Uint8List bytes, String contentType})?> Function(
      Uint8List bytes, {
      required String contentType,
      double quality,
    });

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

  // ISO Base Media File Format: MP4/M4A/HEIC (ftyp box at offset 4)
  if (bytes.length >= 12 && _matchesAt(bytes, 4, _ftypMagic)) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    // Audio brands: M4A (audio), M4B (audiobook), M4P (protected audio)
    if (brand.startsWith('M4A') ||
        brand.startsWith('M4B') ||
        brand.startsWith('M4P')) {
      return 'audio/mp4';
    }
    // HEIC/HEIF still-image brands (ISO 14496-12).
    // Note: hevc/hevx are HEVC video sequences (ISO 23008-12), not still images.
    const heicBrands = {'heic', 'heif', 'heix', 'mif1', 'msf1', 'heis'};
    if (heicBrands.contains(brand)) return 'image/heic';
    // Default: treat remaining ftyp brands (isom, mp41, M4V, f4v, etc.) as video
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

/// DI for image EXIF / XMP metadata sanitization (allows test override).
final imageSanitizerProvider = Provider<ImageSanitizer>(
  (ref) => sanitizeImageMetadata,
);

/// Maximum JPEG/WebP quality passed to image_picker. Above 85 some platforms
/// skip re-encoding, which would leave EXIF intact. Clamping here enforces
/// re-encoding regardless of caller-provided quality.
const _maxImageQuality = 85;

// ── Notifier ──

class MediaUploadNotifier extends Notifier<MediaUploadState>
    with DisposableNotifier<MediaUploadState> {
  late GraphQLClient _gqlClient;
  late http.Client _httpClient;
  late ImageSanitizer _sanitizer;

  @override
  MediaUploadState build() {
    _gqlClient = ref.watch(graphqlClientProvider);
    _httpClient = ref.watch(httpClientProvider);
    _sanitizer = ref.watch(imageSanitizerProvider);
    initDisposable();
    return const MediaUploadState();
  }

  /// Pick an image and upload to R2.
  Future<String?> pickAndUploadImage({
    required UploadCategory category,
    required AppLocalizations l10n,
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
        imageQuality: (imageQuality ?? 75).clamp(1, _maxImageQuality),
      );

      if (picked == null) return null;
      if (disposed) return null;

      final bytes = await picked.readAsBytes();
      if (disposed) return null;

      final prepared = await _prepareImageBytes(bytes, l10n: l10n);
      if (prepared == null) return null;

      return await _upload(
        category: category,
        bytes: prepared.bytes,
        contentType: prepared.contentType,
        l10n: l10n,
      );
    } catch (e) {
      debugPrint('[MediaUpload] pickAndUploadImage error: $e');
      if (!disposed) {
        state = MediaUploadState(error: l10n.uploadImageFailed);
      }
      return null;
    }
  }

  /// Pick multiple images via image_picker and upload each to R2 sequentially.
  /// Returns list of uploaded URLs on success, null on failure.
  /// Uploads are sequential to maintain accurate isUploading state.
  Future<List<String>?> pickAndUploadMultipleImages({
    required UploadCategory category,
    required AppLocalizations l10n,
    int maxCount = maxImagesPerPost,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    if (state.isUploading) return null;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(
        maxWidth: maxWidth ?? 1280,
        maxHeight: maxHeight ?? 1280,
        imageQuality: (imageQuality ?? 75).clamp(1, _maxImageQuality),
      );

      if (picked.isEmpty) return null;
      if (disposed) return null;

      if (picked.length > maxCount) {
        state = MediaUploadState(error: l10n.maxImagesAllowed(maxCount));
        return null;
      }

      state = const MediaUploadState(isUploading: true);

      final urls = <String>[];
      for (final file in picked) {
        if (disposed) return null;

        final bytes = await file.readAsBytes();
        if (disposed) return null;

        // If sanitization fails mid-loop, previously uploaded images in
        // `urls` become R2 orphans (same semantics as HEIC conversion
        // failure in pickAndUploadImage).
        final prepared = await _prepareImageBytes(bytes, l10n: l10n);
        if (prepared == null) return null;

        final url = await _upload(
          category: category,
          bytes: prepared.bytes,
          contentType: prepared.contentType,
          l10n: l10n,
        );
        if (url == null) return null;
        urls.add(url);
        // Re-assert isUploading after each _upload() completes,
        // because _upload() resets isUploading: false internally.
        if (!disposed) {
          state = const MediaUploadState(isUploading: true);
        }
      }

      state = const MediaUploadState();
      return urls;
    } catch (e) {
      debugPrint('[MediaUpload] pickAndUploadMultipleImages error: $e');
      if (!disposed) {
        state = MediaUploadState(error: l10n.uploadImagesFailed);
      }
      return null;
    }
  }

  /// Pick a video via image_picker and upload to R2.
  /// Returns (videoUrl, thumbnailUrl, durationSeconds) on success, null on failure.
  Future<({String videoUrl, String? thumbnailUrl, int? durationSeconds})?>
  pickAndUploadVideo({
    required UploadCategory category,
    required AppLocalizations l10n,
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
        state = MediaUploadState(error: l10n.unsupportedVideoFormat);
        return null;
      }

      // Extract thumbnail + duration before upload to avoid R2 orphans
      int? durationSeconds;
      Uint8List? thumbnailBytes;
      try {
        final meta = await captureVideoThumbnail(bytes, mimeType: contentType);
        durationSeconds = meta.durationSeconds;
        thumbnailBytes = meta.thumbnail;
      } catch (e) {
        debugPrint('[MediaUpload] thumbnail/duration extraction failed: $e');
      }
      if (disposed) return null;

      // Block upload if duration is unknown — cannot verify limit (ADR 025)
      if (durationSeconds == null) {
        if (!disposed) {
          state = MediaUploadState(error: l10n.videoDurationUnknown);
        }
        return null;
      }

      // Enforce video duration limit (ADR 025) — reject before upload
      if (durationSeconds > maxVideoDurationSeconds) {
        if (!disposed) {
          state = MediaUploadState(
            error: l10n.videoTooLong(maxVideoDurationSeconds ~/ 60),
          );
        }
        return null;
      }

      // Upload video
      final videoUrl = await _upload(
        category: category,
        bytes: bytes,
        contentType: contentType,
        l10n: l10n,
      );
      if (videoUrl == null) return null;
      if (disposed) return null;

      // Upload thumbnail
      String? thumbnailUrl;
      if (thumbnailBytes != null && !disposed) {
        thumbnailUrl = await _upload(
          category: category,
          bytes: thumbnailBytes,
          contentType: 'image/jpeg',
          l10n: l10n,
        );
      }

      return (
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      debugPrint('[MediaUpload] pickAndUploadVideo error: $e');
      if (!disposed) {
        state = MediaUploadState(error: l10n.uploadVideoFailed);
      }
      return null;
    }
  }

  /// Pick an audio file using the browser's native file input.
  /// Returns (audioUrl, durationSeconds) on success, null on failure.
  Future<({String audioUrl, int? durationSeconds})?> pickAndUploadAudio({
    required UploadCategory category,
    required AppLocalizations l10n,
  }) async {
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
        state = MediaUploadState(error: l10n.unsupportedAudioFormat);
        return null;
      }

      // Extract duration before upload to avoid R2 orphans
      final durationSeconds = await extractAudioDuration(
        bytes,
        mimeType: contentType,
      );
      if (disposed) return null;

      // Block upload if duration is unknown — cannot verify limit (ADR 025)
      if (durationSeconds == null) {
        if (!disposed) {
          state = MediaUploadState(error: l10n.audioDurationUnknown);
        }
        return null;
      }

      // Enforce audio duration limit (ADR 025) — reject before upload
      if (durationSeconds > maxAudioDurationSeconds) {
        if (!disposed) {
          state = MediaUploadState(
            error: l10n.audioTooLong(maxAudioDurationSeconds ~/ 60),
          );
        }
        return null;
      }

      // Upload after duration check passes
      final url = await _upload(
        category: category,
        bytes: bytes,
        contentType: contentType,
        l10n: l10n,
      );
      if (disposed || url == null) return null;

      return (audioUrl: url, durationSeconds: durationSeconds);
    } catch (e) {
      debugPrint('[MediaUpload] pickAndUploadAudio error: $e');
      if (!disposed) {
        state = MediaUploadState(error: l10n.uploadAudioFailed);
      }
      return null;
    }
  }

  /// Validate MIME from magic bytes, convert HEIC → JPEG on Web, and strip
  /// EXIF / XMP via the sanitizer. Sets `state.error` on failure.
  ///
  /// Must run BEFORE `_upload()` because the R2 presigned URL signs
  /// `ContentLength`; sanitizing inside `_upload()` would produce
  /// `SignatureDoesNotMatch` errors.
  ///
  /// Returns null if the caller should abort (either disposed or an error
  /// is already surfaced via `state`).
  Future<({Uint8List bytes, String contentType})?> _prepareImageBytes(
    Uint8List bytes, {
    required AppLocalizations l10n,
  }) async {
    final detected = mimeFromBytes(bytes);
    if (detected == null || !detected.startsWith('image/')) {
      state = MediaUploadState(error: l10n.unsupportedImageFormat);
      return null;
    }

    // HEIC/HEIF: convert to JPEG via browser Canvas API (Safari). On
    // iOS/Android native, image_picker already converts to JPEG, so this
    // branch only triggers on Web. Canvas re-encoding already strips EXIF,
    // so we skip the sanitizer pass to avoid double-encoding quality loss.
    if (detected == 'image/heic' || detected == 'image/heif') {
      if (!kIsWeb) {
        state = MediaUploadState(error: l10n.heicNotSupported);
        return null;
      }
      final jpegBytes = await convertHeicToJpeg(bytes);
      if (disposed) return null;
      if (jpegBytes == null) {
        state = MediaUploadState(error: l10n.heicConversionFailed);
        return null;
      }
      return (bytes: jpegBytes, contentType: 'image/jpeg');
    }

    final sanitized = await _sanitizer(bytes, contentType: detected);
    if (disposed) return null;
    if (sanitized == null) {
      state = MediaUploadState(error: l10n.imageProcessingFailed);
      return null;
    }
    return sanitized;
  }

  Future<String?> _upload({
    required UploadCategory category,
    required Uint8List bytes,
    required String contentType,
    required AppLocalizations l10n,
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
      state = MediaUploadState(error: l10n.uploadPreparationFailed);
      return null;
    }

    final data = mutationResult.data?['getUploadUrl'] as Map<String, dynamic>?;
    if (data == null) {
      state = MediaUploadState(error: l10n.uploadPreparationFailed);
      return null;
    }

    final uploadUrl = data['uploadUrl'] as String;
    final publicUrl = data['publicUrl'] as String;

    if (!isAllowedUploadUrl(uploadUrl) || !isAllowedPublicUrl(publicUrl)) {
      debugPrint(
        '[MediaUpload] URL validation failed: $uploadUrl / $publicUrl',
      );
      state = MediaUploadState(error: l10n.uploadPreparationFailed);
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
      state = MediaUploadState(error: l10n.uploadFileFailed);
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
  /// Returns ({mediaUrl, thumbnailUrl, durationSeconds}) for all types.
  /// Centralizes the pick logic so create_post and edit_post don't duplicate.
  ///
  /// `l10n` is required because image/video/audio branches all surface
  /// localized errors. The `default` branch never uses it.
  Future<({String mediaUrl, String? thumbnailUrl, int? durationSeconds})?>
  pickByMediaType(MediaType mediaType, {required AppLocalizations l10n}) async {
    switch (mediaType) {
      case MediaType.image:
        final url = await pickAndUploadImage(
          category: UploadCategory.media,
          l10n: l10n,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 75,
        );
        if (url == null) return null;
        return (mediaUrl: url, thumbnailUrl: null, durationSeconds: null);
      case MediaType.video:
        final result = await pickAndUploadVideo(
          category: UploadCategory.media,
          l10n: l10n,
        );
        if (result == null) return null;
        return (
          mediaUrl: result.videoUrl,
          thumbnailUrl: result.thumbnailUrl,
          durationSeconds: result.durationSeconds,
        );
      case MediaType.audio:
        final result = await pickAndUploadAudio(
          category: UploadCategory.media,
          l10n: l10n,
        );
        if (result == null) return null;
        return (
          mediaUrl: result.audioUrl,
          thumbnailUrl: null,
          durationSeconds: result.durationSeconds,
        );
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
