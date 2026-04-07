import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../theme/gleisner_tokens.dart';

/// A WYSIWYG rich text editor wrapping flutter_quill.
///
/// Used for text-type posts: blog, diary, essay, tech writing.
/// Provides formatting toolbar and renders Quill Delta content.
class RichTextEditor extends StatelessWidget {
  final QuillController controller;
  final bool showToolbar;
  final String? placeholder;
  final FocusNode? focusNode;
  final VoidCallback? onImageInsert;
  final bool autofocus;

  const RichTextEditor({
    super.key,
    required this.controller,
    this.showToolbar = true,
    this.placeholder,
    this.focusNode,
    this.onImageInsert,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showToolbar && !controller.readOnly) _buildToolbar(),
        Expanded(child: _buildEditor()),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: colorSurface2,
        border: Border(bottom: BorderSide(color: colorBorder)),
      ),
      child: QuillSimpleToolbar(
        controller: controller,
        config: QuillSimpleToolbarConfig(
          showAlignmentButtons: false,
          showBackgroundColorButton: false,
          showCenterAlignment: false,
          showClearFormat: false,
          showColorButton: false,
          showDirection: false,
          showDividers: false,
          showFontFamily: false,
          showFontSize: false,
          showIndent: false,
          showJustifyAlignment: false,
          showLeftAlignment: false,
          showRightAlignment: false,
          showSearchButton: false,
          showSmallButton: false,
          showStrikeThrough: false,
          showSubscript: false,
          showSuperscript: false,
          showUndo: false,
          showRedo: false,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: false,
          showHeaderStyle: true,
          showListBullets: true,
          showListNumbers: true,
          showCodeBlock: true,
          showInlineCode: true,
          showQuote: true,
          showLink: true,
          showClipboardCut: false,
          showClipboardCopy: false,
          showClipboardPaste: false,
          customButtons: [
            if (onImageInsert != null)
              QuillToolbarCustomButtonOptions(
                icon: const Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: colorInteractive,
                ),
                tooltip: 'Insert image',
                onPressed: onImageInsert!,
              ),
          ],
          buttonOptions: const QuillSimpleToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              iconSize: 18,
              iconButtonFactor: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return QuillEditor(
      controller: controller,
      focusNode: focusNode ?? FocusNode(),
      scrollController: ScrollController(),
      config: QuillEditorConfig(
        autoFocus: autofocus,
        expands: false,
        scrollable: true,
        showCursor: !controller.readOnly,
        placeholder: placeholder,
        padding: const EdgeInsets.all(spaceLg),
        customStyles: _editorStyles(),
      ),
    );
  }

  DefaultStyles _editorStyles() {
    const lineSpacing = VerticalSpacing(0, 0);
    return DefaultStyles(
      paragraph: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextSecondary,
          fontSize: fontSizeMd,
          height: 1.6,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(4, 4),
        lineSpacing,
        null,
      ),
      h1: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextPrimary,
          fontSize: fontSizeTitle,
          fontWeight: weightBold,
          height: 1.4,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(16, 8),
        lineSpacing,
        null,
      ),
      h2: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextPrimary,
          fontSize: fontSizeXl,
          fontWeight: weightSemibold,
          height: 1.4,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(12, 6),
        lineSpacing,
        null,
      ),
      h3: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextPrimary,
          fontSize: fontSizeLg,
          fontWeight: weightMedium,
          height: 1.4,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(8, 4),
        lineSpacing,
        null,
      ),
      quote: DefaultTextBlockStyle(
        TextStyle(
          color: colorTextMuted,
          fontSize: fontSizeMd,
          fontStyle: FontStyle.italic,
          height: 1.6,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(8, 8),
        lineSpacing,
        BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colorAccentGold.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
      ),
      code: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextSecondary,
          fontSize: fontSizeSm,
          fontFamily: 'monospace',
          height: 1.5,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(8, 8),
        lineSpacing,
        BoxDecoration(
          color: colorSurface2,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      bold: const TextStyle(fontWeight: weightBold),
      italic: const TextStyle(fontStyle: FontStyle.italic),
      link: TextStyle(
        color: colorAccentGold,
        decoration: TextDecoration.underline,
        decorationColor: colorAccentGold.withValues(alpha: 0.5),
      ),
    );
  }
}
