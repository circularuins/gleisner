import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../theme/gleisner_tokens.dart';

/// Metadata for each [ConnectionType].
extension ConnectionTypeMeta on ConnectionType {
  String get label => switch (this) {
        ConnectionType.reference => 'Reference',
        ConnectionType.evolution => 'Evolution',
        ConnectionType.remix => 'Remix',
        ConnectionType.reply => 'Reply',
      };

  IconData get icon => switch (this) {
        ConnectionType.reference => Icons.bookmark_outline,
        ConnectionType.evolution => Icons.trending_up,
        ConnectionType.remix => Icons.shuffle,
        ConnectionType.reply => Icons.reply,
      };

  String get description => switch (this) {
        ConnectionType.reference => 'Inspired by or related to',
        ConnectionType.evolution => 'Next version of this piece',
        ConnectionType.remix => 'A remix or reinterpretation',
        ConnectionType.reply => 'A response to this post',
      };
}

/// Shows a bottom sheet to pick a connection type.
/// Returns the selected type, or null if dismissed.
Future<ConnectionType?> showConnectionTypePicker(BuildContext context) {
  return showModalBottomSheet<ConnectionType>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ConnectionTypePicker(),
  );
}

class _ConnectionTypePicker extends StatelessWidget {
  const _ConnectionTypePicker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
      ),
      padding: const EdgeInsets.fromLTRB(spaceXl, spaceLg, spaceXl, spaceXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorTextMuted.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(radiusFull),
              ),
            ),
          ),
          const SizedBox(height: spaceLg),
          const Text(
            'Connection Type',
            style: TextStyle(
              color: colorTextPrimary,
              fontSize: fontSizeLg,
              fontWeight: weightBold,
            ),
          ),
          const SizedBox(height: spaceMd),
          ...ConnectionType.values.map((type) {
            return Padding(
              padding: const EdgeInsets.only(bottom: spaceSm),
              child: InkWell(
                borderRadius: BorderRadius.circular(radiusMd),
                onTap: () => Navigator.pop(context, type),
                child: Container(
                  padding: const EdgeInsets.all(spaceMd),
                  decoration: BoxDecoration(
                    color: colorSurface0,
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border.all(color: colorBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(type.icon, size: 20, color: colorInteractive),
                      const SizedBox(width: spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.label,
                              style: const TextStyle(
                                color: colorTextPrimary,
                                fontSize: fontSizeMd,
                                fontWeight: weightMedium,
                              ),
                            ),
                            Text(
                              type.description,
                              style: const TextStyle(
                                color: colorTextMuted,
                                fontSize: fontSizeXs,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: spaceSm),
        ],
      ),
    );
  }
}
