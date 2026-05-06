import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'image_quality.dart';

/// Diagnostic — last reason `sanitizeImageMetadata` returned null. Set on
/// every failure path (and cleared on success) so the provider can surface
/// the stage in the user-visible error during Phase 0 launch debugging.
/// Phase 1 cleanup: drop this once we have proper structured-error
/// plumbing through the provider.
String? lastSanitizerFailureStage;

/// Re-encode image bytes via Canvas API on Web to strip EXIF / XMP / IPTC
/// metadata (GPS coordinates, camera identifiers, timestamps).
///
/// Contract:
/// - Input and output `contentType` are always equal on success.
/// - Returns `null` on any failure (fail-closed for privacy). In particular,
///   if Canvas re-encoded bytes still carry any marker detected by
///   [containsMetadataMarkers], the function returns `null` instead of
///   surfacing bytes that may leak EXIF/XMP.
///
/// Platform behaviour:
/// - Web: Canvas re-encode strips all metadata from JPEG / PNG / WebP; GIFs
///   are passed through only if no Application / Comment Extension blocks
///   are present (Canvas would flatten animation, so we reject rather than
///   re-encode).
/// - Native: `image_picker`'s `imageQuality` re-encoding only strips EXIF
///   from **JPEG**. To stay fail-closed, PNG / WebP / HEIC are rejected on
///   native until explicit sanitization via the `image` package lands
///   (Issue #227). JPEG pass-through requires callers to clamp
///   `imageQuality` to 1-85; GIF is checked for metadata blocks.
Future<({Uint8List bytes, String contentType})?> sanitizeImageMetadata(
  Uint8List bytes, {
  required String contentType,
  double quality = kImageSanitizeJpegQuality,
}) async {
  void fail(String stage) {
    lastSanitizerFailureStage = stage;
    debugPrint(
      '[sanitizer] fail at: $stage (contentType=$contentType, '
      'size=${bytes.length})',
    );
  }

  if (!kIsWeb) {
    if (contentType == 'image/jpeg') {
      lastSanitizerFailureStage = null;
      return (bytes: bytes, contentType: contentType);
    }
    if (contentType == 'image/gif') {
      if (gifContainsMetadataBlocks(bytes)) {
        fail('native-gif-has-metadata');
        return null;
      }
      lastSanitizerFailureStage = null;
      return (bytes: bytes, contentType: contentType);
    }
    fail('native-unsupported-$contentType');
    return null;
  }

  if (contentType == 'image/gif') {
    if (gifContainsMetadataBlocks(bytes)) {
      fail('web-gif-has-metadata');
      return null;
    }
    lastSanitizerFailureStage = null;
    return (bytes: bytes, contentType: contentType);
  }

  if (contentType != 'image/jpeg' &&
      contentType != 'image/png' &&
      contentType != 'image/webp') {
    fail('web-unsupported-$contentType');
    return null;
  }

  final reencoded = await _canvasReencode(
    bytes,
    contentType: contentType,
    quality: quality,
  );
  if (reencoded == null) {
    // _canvasReencode sets a fine-grained stage; only set fallback if not.
    lastSanitizerFailureStage ??= 'canvas-reencode-null';
    return null;
  }

  if (!_matchesMagicBytes(reencoded, contentType)) {
    fail('reencoded-magic-mismatch');
    return null;
  }
  if (containsMetadataMarkers(reencoded)) {
    fail('reencoded-still-has-markers');
    return null;
  }

  lastSanitizerFailureStage = null;
  return (bytes: reencoded, contentType: contentType);
}

Future<Uint8List?> _canvasReencode(
  Uint8List bytes, {
  required String contentType,
  required double quality,
}) async {
  final completer = Completer<Uint8List?>();
  Timer? timeout;
  StreamSubscription<web.Event>? onLoadSub;
  StreamSubscription<web.Event>? onErrorSub;
  StreamSubscription<web.Event>? readerSub;

  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: contentType),
  );
  final blobUrl = web.URL.createObjectURL(blob);

  void finish(Uint8List? result) {
    if (completer.isCompleted) return;
    timeout?.cancel();
    onLoadSub?.cancel();
    onErrorSub?.cancel();
    readerSub?.cancel();
    web.URL.revokeObjectURL(blobUrl);
    completer.complete(result);
  }

  void failStage(String stage) {
    lastSanitizerFailureStage = stage;
    debugPrint('[sanitizer.canvas] fail at: $stage');
  }

  try {
    final img = web.HTMLImageElement()..src = blobUrl;

    onLoadSub = img.onLoad.listen((_) {
      try {
        var w = img.naturalWidth;
        var h = img.naturalHeight;
        if (w <= 0 || h <= 0) {
          failStage('image-decoded-zero-size');
          finish(null);
          return;
        }

        final originalW = w;
        final originalH = h;
        if (w > kImageSanitizeMaxDimension || h > kImageSanitizeMaxDimension) {
          if (w >= h) {
            h = (h * kImageSanitizeMaxDimension / w).round();
            w = kImageSanitizeMaxDimension;
          } else {
            w = (w * kImageSanitizeMaxDimension / h).round();
            h = kImageSanitizeMaxDimension;
          }
        }

        debugPrint(
          '[sanitizer.canvas] decoded ${originalW}x$originalH '
          '-> drawing at ${w}x$h (contentType=$contentType)',
        );

        final canvas = web.HTMLCanvasElement()
          ..width = w
          ..height = h;
        final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
        ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());

        canvas.toBlob(
          ((web.Blob? outBlob) {
            if (completer.isCompleted) return;
            if (outBlob == null) {
              failStage('toblob-returned-null-${w}x$h');
              finish(null);
              return;
            }
            final reader = web.FileReader();
            readerSub = reader.onLoadEnd.listen((_) {
              if (completer.isCompleted) return;
              final result = reader.result;
              if (result != null) {
                finish((result as JSArrayBuffer).toDart.asUint8List());
              } else {
                failStage('filereader-null-result');
                finish(null);
              }
            });
            reader.readAsArrayBuffer(outBlob);
          }).toJS,
          contentType,
          quality.toJS,
        );
      } catch (e) {
        failStage('drawimage-or-toblob-throw-${e.runtimeType}');
        finish(null);
      }
    });

    onErrorSub = img.onError.listen((_) {
      failStage('image-load-error');
      finish(null);
    });

    timeout = Timer(const Duration(seconds: 10), () {
      failStage('canvas-timeout-10s');
      finish(null);
    });

    return await completer.future;
  } catch (e) {
    failStage('outer-throw-${e.runtimeType}');
    finish(null);
    return null;
  }
}

bool _matchesMagicBytes(Uint8List bytes, String contentType) {
  if (bytes.length < 12) return false;
  switch (contentType) {
    case 'image/jpeg':
      return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    case 'image/png':
      return bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47;
    case 'image/webp':
      return bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50;
    default:
      return false;
  }
}

// EXIF APP1 marker bytes: "Exif" + 2 NUL bytes (0x00 0x00).
const _exifMarker = <int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00];

/// Scan the first 64 KB for EXIF / XMP metadata markers.
///
/// Rationale: JPEG stores EXIF in APP1 segments near the file start; PNG
/// and WebP place EXIF / XMP chunks in the header region in practice.
/// Full-file scans cost 5-30 ms on 5 MB images for marginal coverage —
/// any payload buried past 64 KB would need to survive Canvas re-encode
/// first (which drops all non-pixel data).
@visibleForTesting
bool containsMetadataMarkers(Uint8List bytes) {
  final len = bytes.length < 65536 ? bytes.length : 65536;
  // Byte-level scan for EXIF marker to keep source file ASCII-clean
  // (NUL literals in strings would flip git to binary mode).
  for (int i = 0; i + _exifMarker.length <= len; i++) {
    var match = true;
    for (int j = 0; j < _exifMarker.length; j++) {
      if (bytes[i + j] != _exifMarker[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  final ascii = String.fromCharCodes(bytes.sublist(0, len));
  return ascii.contains('http://ns.adobe.com/xap/') ||
      ascii.contains('GPSLatitude') ||
      ascii.contains('GPSLongitude') ||
      ascii.contains('photoshop:') ||
      ascii.contains('xmp:');
}

/// Detect GIF Application Extension (0x21 0xFF) or Comment Extension
/// (0x21 0xFE) blocks. These can carry XMP payloads with GPS data, so
/// GIFs containing them are rejected rather than re-encoded (Canvas
/// re-encoding would flatten animation to a single frame).
///
/// GIF layout: 6-byte signature ("GIF87a"/"GIF89a") + 7-byte logical
/// screen descriptor = 13 bytes before the first data block. Extension
/// blocks start with 0x21 followed by a label byte.
@visibleForTesting
bool gifContainsMetadataBlocks(Uint8List bytes) {
  if (bytes.length < 14) return false;
  for (int i = 13; i < bytes.length - 1; i++) {
    if (bytes[i] == 0x21) {
      final label = bytes[i + 1];
      if (label == 0xFF || label == 0xFE) return true;
    }
  }
  return false;
}
