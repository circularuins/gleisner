import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';

/// Top-level instance reused across builds — `OrderedTraversalPolicy` is
/// stateless so a single instance is safe and avoids the per-build
/// allocation that the inline `OrderedTraversalPolicy()` would incur.
final FocusTraversalPolicy _orderedTraversalPolicy = OrderedTraversalPolicy();

/// Three-row form for link-type posts: URL + title + caption, wrapped in
/// a `FocusTraversalGroup` so Tab navigation stays inside the group
/// (works around the Flutter Web IME / Tab assertion described in
/// `frontend/lib/utils/ime_safe_focus.dart`). Focus nodes must be
/// IME-safe (\`createImeSafeFocusNode\`) to avoid the same assertion.
///
/// **Ownership contract**: this widget does NOT own any of the controllers
/// or focus nodes it receives — they are constructed and disposed by the
/// surrounding screen (`create_post_screen` / `edit_post_screen`). New
/// callers must do the same. Disposing inside this widget would crash on
/// the next build cycle in the parent.
///
/// The URL validator trims whitespace before parsing, requires a non-empty
/// host, and accepts only http / https — this is the stricter behaviour
/// that lived in the edit screen prior to extraction (the create screen
/// used \`value.isEmpty\` and accepted a host-less \`https:\` URI). Both
/// screens now share the strict form.
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
  /// Owned by the parent — this widget does not dispose it.
  final TextEditingController urlController;

  /// Title input controller. Capped at 100 characters by the field.
  /// Owned by the parent — this widget does not dispose it.
  final TextEditingController titleController;

  /// Caption input controller. Capped at 500 characters by the field.
  /// Owned by the parent — this widget does not dispose it.
  final TextEditingController captionController;

  /// All three nodes should be created via \`createImeSafeFocusNode\` so
  /// Tab during IME composition is consumed instead of asserting.
  /// Owned by the parent — this widget does not dispose them.
  final FocusNode urlFocusNode;
  final FocusNode titleFocusNode;
  final FocusNode captionFocusNode;

  /// Focus the URL field on mount.
  ///
  /// Default \`false\` is the conservative choice — calling \`autofocus: true\`
  /// from a context where the user is mid-task (edit screen, modal layered
  /// on existing focus) would steal selection from whatever they were
  /// already editing. Only the create screen passes \`true\` because the
  /// form is the first thing a brand-new \"link-type post\" interaction shows.
  final bool autofocusUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FocusTraversalGroup(
      policy: _orderedTraversalPolicy,
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
          // Reject `http:` / `https:` without a host — `Uri.tryParse`
          // accepts those as syntactically valid URIs but they're useless
          // for OGP fetch and would cause `safeFetch` to reject them
          // server-side anyway. Catching it client-side surfaces a
          // friendlier error.
          if (uri == null ||
              !['http', 'https'].contains(uri.scheme) ||
              uri.host.isEmpty) {
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
