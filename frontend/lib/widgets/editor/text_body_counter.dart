import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../theme/gleisner_tokens.dart';

/// Live character counter for the Quill rich text editor.
/// Backend limit: 10,000 plain-text chars / 100KB delta JSON.
/// Only visible when the user has written 100+ characters.
class TextBodyCounter extends StatefulWidget {
  final QuillController controller;
  final int maxChars;

  const TextBodyCounter({
    super.key,
    required this.controller,
    this.maxChars = 10000,
  });

  @override
  State<TextBodyCounter> createState() => _TextBodyCounterState();
}

class _TextBodyCounterState extends State<TextBodyCounter> {
  int _charCount = 0;
  StreamSubscription<dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _update();
    _subscription = widget.controller.document.changes.listen((_) => _update());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _update() {
    final count = widget.controller.document.toPlainText().trimRight().length;
    if (count != _charCount && mounted) {
      setState(() => _charCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNearLimit = _charCount > widget.maxChars * 0.9;
    final isOver = _charCount > widget.maxChars;
    if (_charCount < 100) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: spaceMd, top: spaceXs),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$_charCount / ${widget.maxChars}',
          style: TextStyle(
            fontSize: fontSizeXs,
            color: isOver
                ? colorError
                : isNearLimit
                ? colorAccentGold
                : colorTextMuted.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
