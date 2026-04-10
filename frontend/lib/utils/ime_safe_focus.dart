import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Create a FocusNode that blocks Tab key during IME composition.
///
/// IMPORTANT: [controller] must outlive the returned [FocusNode].
/// Dispose the FocusNode before disposing [controller].
///
/// On Flutter Web, pressing Tab while the IME has uncommitted text
/// (e.g. Japanese kanji candidates) causes the composition to commit
/// AND focus to move simultaneously. This corrupts the text editing
/// state, causing "Range end N is out of text of length 0" assertions.
///
/// This FocusNode intercepts Tab during active composition and consumes
/// the event, forcing the user to confirm IME input before Tab-navigating.
FocusNode createImeSafeFocusNode(TextEditingController controller) {
  return FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          controller.value.composing != TextRange.empty) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );
}
