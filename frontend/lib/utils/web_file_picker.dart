import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Pick a file using the browser's native file input (Web only).
/// Returns (bytes, filename) or null if cancelled or timed out.
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
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final bytes = (result as JSArrayBuffer).toDart.asUint8List();
      if (!completer.isCompleted) completer.complete((bytes, file.name));
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();

  // Cancel detection: when user dismisses the file dialog, window regains
  // focus but onChange never fires. Use a delayed check after focus returns.
  void onFocus(web.Event _) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete(null);
    });
  }

  final onFocusJs = onFocus.toJS; // single reference for add/remove
  web.window.addEventListener('focus', onFocusJs);

  // Clean up focus listener after completion
  completer.future.then((_) {
    web.window.removeEventListener('focus', onFocusJs);
  });

  return completer.future;
}
