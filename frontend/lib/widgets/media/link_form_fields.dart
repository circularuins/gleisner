import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';

/// Three-row form for link-type posts: URL + title + caption, wrapped in
/// a `FocusTraversalGroup` so Tab navigation stays inside the group
/// (works around the Flutter Web IME / Tab assertion described in
/// `frontend/lib/utils/ime_safe_focus.dart`). Focus nodes must be
/// IME-safe (\`createImeSafeFocusNode\`) to avoid the same assertion.
///
/// The URL validator trims whitespace before parsing and accepts only
/// http / https — this is the stricter behaviour that lived in the edit
/// screen prior to extraction (the create screen used \`value.isEmpty\`,
/// which let through a whitespace-only string until the trim landed).
///
/// Issue #178 (and the unfiled \`_buildLinkFields\` duplication noted in
/// the Phase 0 roadmap §3.1) — extracted from create_post_screen and
/// edit_post_screen, which had byte-equivalent implementations modulo
/// the trim and an \`autofocus\` flag.
class LinkFormFields extends StatelessWidget {
  const LinkFormFields({
    super.key,
    required this.urlController,
    required this.titleController,
    required this.captionController,
    required this.urlFocusNode,
    required this.titleFocusNode,
    required this.captionFocusNode,
    this.autofocusUrl = false,
  });

  /// URL input controller. Validation runs on \`.trim()\`.
  final TextEditingController urlController;

  /// Title input controller. Capped at 100 characters by the field.
  final TextEditingController titleController;

  /// Caption input controller. Capped at 500 characters by the field.
  final TextEditingController captionController;

  /// All three nodes should be created via \`createImeSafeFocusNode\` so
  /// Tab during IME composition is consumed instead of asserting.
  final FocusNode urlFocusNode;
  final FocusNode titleFocusNode;
  final FocusNode captionFocusNode;

  /// Focus the URL field on mount. True from the create screen (the
  /// link form is the first thing the user sees), false from edit
  /// (refocusing would steal the user's selection on the field they
  /// actually meant to change).
  final bool autofocusUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        children: [
          _UrlField(
            controller: urlController,
            focusNode: urlFocusNode,
            autofocus: autofocusUrl,
            hintText: l10n.urlPlaceholder,
            requiredErrorText: l10n.urlRequired,
            invalidErrorText: l10n.invalidUrl,
          ),
          const SizedBox(height: spaceSm),
          _TitleField(
            controller: titleController,
            focusNode: titleFocusNode,
            hintText: l10n.titleAutoFilled,
          ),
          const SizedBox(height: spaceSm),
          _CaptionField(
            controller: captionController,
            focusNode: captionFocusNode,
            hintText: l10n.addNote,
          ),
          const SizedBox(height: spaceMd),
        ],
      ),
    );
  }
}

class _UrlField extends StatelessWidget {
  const _UrlField({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.hintText,
    required this.requiredErrorText,
    required this.invalidErrorText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final String hintText;
  final String requiredErrorText;
  final String invalidErrorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: spaceMd),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.next,
        style: TextStyle(
          color: colorTextPrimary,
          fontSize: fontSizeMd,
          fontFamily: monoFontFamily,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: colorTextMuted.withValues(alpha: 0.4),
            fontSize: fontSizeMd,
            fontFamily: monoFontFamily,
          ),
          icon: const Icon(Icons.link_rounded, color: colorTextMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: spaceMd),
        ),
        validator: (value) {
          final trimmed = value?.trim() ?? '';
          if (trimmed.isEmpty) return requiredErrorText;
          final uri = Uri.tryParse(trimmed);
          if (uri == null || !['http', 'https'].contains(uri.scheme)) {
            return invalidErrorText;
          }
          return null;
        },
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: spaceMd),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.next,
        maxLength: 100,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        style: const TextStyle(
          color: colorTextPrimary,
          fontSize: fontSizeLg,
          fontWeight: weightMedium,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: colorTextMuted,
            fontSize: fontSizeLg,
            fontWeight: weightMedium,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: spaceMd),
          counterStyle: TextStyle(
            fontSize: fontSizeXs,
            color: colorTextMuted.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _CaptionField extends StatelessWidget {
  const _CaptionField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: spaceMd),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.done,
        maxLines: 3,
        minLines: 2,
        maxLength: 500,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        style: const TextStyle(
          color: colorTextSecondary,
          fontSize: fontSizeMd,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: colorTextMuted,
            fontSize: fontSizeMd,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: spaceSm),
          counterStyle: TextStyle(
            fontSize: fontSizeXs,
            color: colorTextMuted.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
