import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Extract duration in seconds from audio bytes using HTMLAudioElement (Web only).
/// Returns null if duration cannot be determined.
Future<int?> extractAudioDuration(
  Uint8List audioBytes, {
  required String mimeType,
}) async {
  final completer = Completer<int?>();
  Timer? timeout;
  StreamSubscription<web.Event>? onLoadedMetadataSub;
  StreamSubscription<web.Event>? onErrorSub;

  final blob = web.Blob(
    [audioBytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final blobUrl = web.URL.createObjectURL(blob);

  final audio = web.HTMLAudioElement()
    ..src = blobUrl
    ..preload = 'metadata';

  void finish(int? result) {
    if (completer.isCompleted) return;
    timeout?.cancel();
    onLoadedMetadataSub?.cancel();
    onErrorSub?.cancel();
    audio.src = '';
    web.URL.revokeObjectURL(blobUrl);
    completer.complete(result);
  }

  onLoadedMetadataSub = audio.onLoadedMetadata.listen((_) {
    final dur = audio.duration;
    if (dur.isFinite && dur > 0) {
      finish(dur.round().clamp(1, 86400));
    } else {
      finish(null);
    }
  });

  onErrorSub = audio.onError.listen((_) {
    finish(null);
  });

  // Timeout after 10 seconds
  timeout = Timer(const Duration(seconds: 10), () {
    finish(null);
  });

  return completer.future;
}
