import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Capture the first frame of a video as a JPEG thumbnail.
/// Returns the JPEG bytes, or null on failure.
Future<Uint8List?> captureVideoThumbnail(Uint8List videoBytes) async {
  final completer = Completer<Uint8List?>();

  // Create a blob URL from the video bytes
  final blob = web.Blob(
    [videoBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'video/mp4'),
  );
  final blobUrl = web.URL.createObjectURL(blob);

  final video = web.HTMLVideoElement()
    ..src = blobUrl
    ..muted = true
    ..playsInline = true
    ..preload = 'auto';

  void cleanup() {
    video.pause();
    video.src = '';
    web.URL.revokeObjectURL(blobUrl);
  }

  video.onLoadedData.listen((_) {
    // Seek to 0.5s to avoid black first frames
    video.currentTime = 0.5;
  });

  video.onSeeked.listen((_) {
    try {
      final canvas = web.HTMLCanvasElement()
        ..width = video.videoWidth
        ..height = video.videoHeight;
      final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
      ctx.drawImage(video, 0, 0);

      // Convert canvas to JPEG blob
      canvas.toBlob(
        ((web.Blob blob) {
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
          reader.readAsArrayBuffer(blob);
        }).toJS,
        'image/jpeg',
        0.75.toJS,
      );
    } catch (_) {
      cleanup();
      completer.complete(null);
    }
  });

  video.onError.listen((_) {
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

  // Trigger load
  video.load();

  return completer.future;
}
