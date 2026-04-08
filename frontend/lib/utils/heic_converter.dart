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
  Timer? timeout;
  StreamSubscription<web.Event>? onLoadSub;
  StreamSubscription<web.Event>? onErrorSub;
  StreamSubscription<web.Event>? readerSub;

  final blob = web.Blob(
    [heicBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/heic'),
  );
  final blobUrl = web.URL.createObjectURL(blob);

  final img = web.HTMLImageElement()..src = blobUrl;

  void finish(Uint8List? result) {
    if (completer.isCompleted) return;
    timeout?.cancel();
    onLoadSub?.cancel();
    onErrorSub?.cancel();
    readerSub?.cancel();
    web.URL.revokeObjectURL(blobUrl);
    completer.complete(result);
  }

  onLoadSub = img.onLoad.listen((_) {
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
          readerSub = reader.onLoadEnd.listen((_) {
            final result = reader.result;
            if (result != null) {
              finish((result as JSArrayBuffer).toDart.asUint8List());
            } else {
              finish(null);
            }
          });
          reader.readAsArrayBuffer(jpegBlob);
        }).toJS,
        'image/jpeg',
        quality.toJS,
      );
    } catch (_) {
      finish(null);
    }
  });

  onErrorSub = img.onError.listen((_) {
    finish(null);
  });

  // Timeout after 10 seconds (cancellable to avoid holding references)
  timeout = Timer(const Duration(seconds: 10), () {
    finish(null);
  });

  return completer.future;
}
