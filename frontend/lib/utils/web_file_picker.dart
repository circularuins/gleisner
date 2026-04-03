import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Pick a file using the browser's native file input.
/// Returns (bytes, filename) or null if cancelled.
Future<(Uint8List, String)?> pickFileFromBrowser({
  required String accept,
}) async {
  final completer = Completer<(Uint8List, String)?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result == null) {
        completer.complete(null);
        return;
      }
      final bytes = (result as JSArrayBuffer).toDart.asUint8List();
      completer.complete((bytes, file.name));
    });
    reader.readAsArrayBuffer(file);
  });

  // Also handle cancel (input loses focus without selection)
  // Use a delayed check since there's no cancel event
  input.click();

  return completer.future;
}
