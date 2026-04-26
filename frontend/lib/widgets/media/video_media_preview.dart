import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';

/// Video media preview shown in create-post / edit-post forms.
///
/// Displays the captured thumbnail (when available) inside a rounded
/// container, falling back to a video-camera icon placeholder when no
/// thumbnail has been generated yet. A "Replace" badge sits at the top-
/// right; the form's container is the tap target so we don't gesture-
/// detect here — the badge is purely informational.
///
/// This widget intentionally has no awareness of upload state /
/// progress / error messaging — those layers belong to the form. It
/// renders whatever URL it's handed, with `Image.network`'s
/// loadingBuilder/errorBuilder providing a consistent skeleton.
///
/// Issues #174 / #178 — extracted from \`_buildMediaPreview\` in
/// create_post_screen and edit_post_screen, which were byte-identical.
class VideoMediaPreview extends StatelessWidget {
  const VideoMediaPreview({super.key, this.thumbnailUrl});

  /// URL of the captured first-frame thumbnail. When null or empty, a
  /// video-camera icon placeholder is shown instead (e.g. before the
  /// frame extraction has completed).
  final String? thumbnailUrl;

  static const double _thumbnailHeight = 240;
  static const double _placeholderHeight = 200;

  bool get _hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_hasThumbnail)
          ClipRRect(
            borderRadius: BorderRadius.circular(radiusLg),
            child: Image.network(
              thumbnailUrl!,
              width: double.infinity,
              height: _thumbnailHeight,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: _thumbnailHeight,
                  decoration: BoxDecoration(
                    color: colorSurface2,
                    borderRadius: BorderRadius.circular(radiusLg),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                height: _thumbnailHeight,
                decoration: BoxDecoration(
                  color: colorSurface2,
                  borderRadius: BorderRadius.circular(radiusLg),
                ),
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: colorTextMuted,
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            height: _placeholderHeight,
            decoration: BoxDecoration(
              color: colorSurface2,
              borderRadius: BorderRadius.circular(radiusLg),
            ),
            child: const Center(
              child: Icon(
                Icons.videocam_outlined,
                size: 48,
                color: colorAccentGold,
              ),
            ),
          ),
        Positioned(
          top: spaceSm,
          right: spaceSm,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: spaceSm,
              vertical: spaceXs,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
                const SizedBox(width: spaceXs),
                Text(
                  context.l10n.replace,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: fontSizeXs,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
