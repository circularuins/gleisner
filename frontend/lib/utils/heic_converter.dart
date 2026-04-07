import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Convert HEIC/HEIF image bytes to JPEG using the browser's Canvas API.
/// Works on Safari (macOS/iOS) which supports HEIC decoding natively.
/// Returns JPEG bytes on success, or null if the browser can't decode HEIC.
Future<Uint8List?> convertHeicToJpeg(
  Uint8List heicBytes, {
  double quality = 0.85,
  int maxDimension = 1280,
}) async {
  final completer = Completer<Uint8List?>();

  final blob = web.Blob(
    [heicBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/heic'),
  );
  final blobUrl = web.URL.createObjectURL(blob);

  final img = web.HTMLImageElement()..src = blobUrl;

  void cleanup() {
    web.URL.revokeObjectURL(blobUrl);
  }

  img.onLoad.listen((_) {
    try {
      // Compute scaled dimensions (preserve aspect ratio, cap at maxDimension)
      var w = img.naturalWidth;
      var h = img.naturalHeight;
      if (w > maxDimension || h > maxDimension) {
        if (w >= h) {
          h = (h * maxDimension / w).round();
          w = maxDimension;
        } else {
          w = (w * maxDimension / h).round();
          h = maxDimension;
        }
      }

      final canvas = web.HTMLCanvasElement()
        ..width = w
        ..height = h;
      final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
      ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());

      canvas.toBlob(
        ((web.Blob jpegBlob) {
          final reader = web.FileReader();
          reader.onLoadEnd.listen((_) {
            final result = reader.result;
            if (result != null) {
              final bytes = (result as JSArrayBuffer).toDart.asUint8List();
              cleanup();
              completer.complete(bytes);
            } else {
              cleanup();
              completer.complete(null);
            }
          });
          reader.readAsArrayBuffer(jpegBlob);
        }).toJS,
        'image/jpeg',
        quality.toJS,
      );
    } catch (_) {
      cleanup();
      completer.complete(null);
    }
  });

  img.onError.listen((_) {
    cleanup();
    if (!completer.isCompleted) completer.complete(null);
  });

  // Timeout after 10 seconds
  Future.delayed(const Duration(seconds: 10), () {
    if (!completer.isCompleted) {
      cleanup();
      completer.complete(null);
    }
  });

  return completer.future;
}
