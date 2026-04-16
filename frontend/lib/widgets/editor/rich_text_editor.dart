import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../theme/gleisner_tokens.dart';
import '../../l10n/l10n.dart';

/// A WYSIWYG rich text editor wrapping flutter_quill.
///
/// Used for text-type posts: blog, diary, essay, tech writing.
/// Provides formatting toolbar and renders Quill Delta content.
///
/// When [toolbarCollapsed] is true, the toolbar starts hidden and a
/// small format toggle button appears. Tapping it reveals the full
/// toolbar. This keeps the editor lightweight for quick posts while
/// supporting rich formatting on demand.
class RichTextEditor extends StatefulWidget {
  final QuillController controller;
  final bool showToolbar;
  final bool toolbarCollapsed;
  final String? placeholder;
  final FocusNode? focusNode;
  final VoidCallback? onImageInsert;
  final bool autofocus;

  const RichTextEditor({
    super.key,
    required this.controller,
    this.showToolbar = true,
    this.toolbarCollapsed = false,
    this.placeholder,
    this.focusNode,
    this.onImageInsert,
    this.autofocus = false,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late bool _toolbarExpanded;
  FocusNode? _internalFocusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _toolbarExpanded = !widget.toolbarCollapsed;
    _scrollController = ScrollController();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  Widget build(BuildContext context) {
    final showToolbarArea = widget.showToolbar && !widget.controller.readOnly;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showToolbarArea) ...[
          if (_toolbarExpanded) _buildToolbar() else _buildToolbarToggle(),
        ],
        Flexible(child: _buildEditor()),
      ],
    );
  }

  Widget _buildToolbarToggle() {
    return GestureDetector(
      onTap: () => setState(() => _toolbarExpanded = true),
      child: Container(
        decoration: const BoxDecoration(
          color: colorSurface2,
          border: Border(bottom: BorderSide(color: colorBorder)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceSm,
        ),
        child: Row(
          children: [
            Icon(Icons.format_bold, size: 16, color: colorInteractiveMuted),
            const SizedBox(width: spaceXxs),
            Icon(Icons.format_italic, size: 16, color: colorInteractiveMuted),
            const SizedBox(width: spaceXxs),
            Icon(
              Icons.format_list_bulleted,
              size: 16,
              color: colorInteractiveMuted,
            ),
            const SizedBox(width: spaceSm),
            Text(
              context.l10n.formatting,
              style: TextStyle(
                color: colorInteractiveMuted,
                fontSize: fontSizeSm,
              ),
            ),
            const SizedBox(width: spaceXs),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: colorInteractiveMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: const BoxDecoration(
        color: colorSurface2,
        border: Border(bottom: BorderSide(color: colorBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: QuillSimpleToolbar(
              controller: widget.controller,
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
                  if (widget.onImageInsert != null)
                    QuillToolbarCustomButtonOptions(
                      icon: const Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: colorInteractive,
                      ),
                      tooltip: context.l10n.insertImage,
                      onPressed: widget.onImageInsert!,
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
          ),
          // Collapse button
          if (widget.toolbarCollapsed)
            IconButton(
              onPressed: () => setState(() => _toolbarExpanded = false),
              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              color: colorInteractiveMuted,
              tooltip: context.l10n.hideFormatting,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      color: colorSurface1,
      child: QuillEditor(
        controller: widget.controller,
        focusNode: _effectiveFocusNode,
        scrollController: _scrollController,
        config: QuillEditorConfig(
          autoFocus: widget.autofocus,
          expands: true,
          scrollable: true,
          showCursor: !widget.controller.readOnly,
          placeholder: widget.placeholder,
          padding: const EdgeInsets.all(spaceLg),
          customStyles: _editorStyles(),
        ),
      ),
    );
  }

  DefaultStyles _editorStyles() {
    const lineSpacing = VerticalSpacing(0, 0);
    return DefaultStyles(
      placeHolder: DefaultTextBlockStyle(
        TextStyle(
          color: colorTextMuted.withValues(alpha: 0.5),
          fontSize: fontSizeSm,
          height: 1.6,
        ),
        const HorizontalSpacing(0, 0),
        const VerticalSpacing(4, 4),
        lineSpacing,
        null,
      ),
      paragraph: DefaultTextBlockStyle(
        const TextStyle(
          color: colorTextSecondary,
          fontSize: fontSizeSm,
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
