import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';

/// Empty-state placeholder shown above the media upload area:
/// a muted icon (centered) with an optional limit hint beneath.
///
/// Shared between create_post and edit_post so the container styling
/// (height, surface color, corner radius) stays in lockstep.
class UploadPlaceholderContent extends StatelessWidget {
  final IconData icon;
  final String? hint;

  const UploadPlaceholderContent({super.key, required this.icon, this.hint});

  @override
  Widget build(BuildContext context) {
    final localHint = hint;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colorSurface2,
        borderRadius: BorderRadius.circular(radiusLg),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorTextMuted.withValues(alpha: 0.4)),
            if (localHint != null) ...[
              const SizedBox(height: spaceSm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: spaceMd),
                child: Text(
                  localHint,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSizeXs,
                    color: colorTextMuted.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
