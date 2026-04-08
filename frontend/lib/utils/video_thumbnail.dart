import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Result of video metadata extraction and thumbnail capture.
typedef VideoMeta = ({Uint8List? thumbnail, int? durationSeconds});

/// Capture the first frame of a video as a JPEG thumbnail and extract
/// its duration in seconds (Web only).
/// [mimeType] should match the actual video format (e.g. 'video/webm').
Future<VideoMeta> captureVideoThumbnail(
  Uint8List videoBytes, {
  String mimeType = 'video/mp4',
}) async {
  final completer = Completer<VideoMeta>();
  Timer? timeout;
  StreamSubscription<web.Event>? onLoadedDataSub;
  StreamSubscription<web.Event>? onSeekedSub;
  StreamSubscription<web.Event>? onErrorSub;
  StreamSubscription<web.Event>? readerSub;

  // Create a blob URL from the video bytes
  final blob = web.Blob(
    [videoBytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final blobUrl = web.URL.createObjectURL(blob);

  final video = web.HTMLVideoElement()
    ..src = blobUrl
    ..muted = true
    ..playsInline = true
    ..preload = 'auto';

  int? durationSeconds;

  void finish(Uint8List? thumbnail) {
    if (completer.isCompleted) return;
    timeout?.cancel();
    onLoadedDataSub?.cancel();
    onSeekedSub?.cancel();
    onErrorSub?.cancel();
    readerSub?.cancel();
    video.pause();
    video.src = '';
    web.URL.revokeObjectURL(blobUrl);
    completer.complete((
      thumbnail: thumbnail,
      durationSeconds: durationSeconds,
    ));
  }

  onLoadedDataSub = video.onLoadedData.listen((_) {
    // Extract duration
    final dur = video.duration;
    if (dur.isFinite && dur > 0) {
      durationSeconds = dur.round().clamp(1, 86400);
    }
    // Seek to 0.5s to avoid black first frames
    video.currentTime = 0.5;
  });

  onSeekedSub = video.onSeeked.listen((_) {
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
          readerSub = reader.onLoadEnd.listen((_) {
            final result = reader.result;
            if (result != null) {
              finish((result as JSArrayBuffer).toDart.asUint8List());
            } else {
              finish(null);
            }
          });
          reader.readAsArrayBuffer(blob);
        }).toJS,
        'image/jpeg',
        0.75.toJS,
      );
    } catch (_) {
      finish(null);
    }
  });

  onErrorSub = video.onError.listen((_) {
    finish(null);
  });

  // Timeout after 10 seconds (cancellable to avoid holding references)
  timeout = Timer(const Duration(seconds: 10), () {
    finish(null);
  });

  // Trigger load
  video.load();

  return completer.future;
}
