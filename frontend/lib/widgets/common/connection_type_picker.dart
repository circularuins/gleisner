import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';

/// The four connection types supported by the backend.
const connectionTypes = [
  (
    'reference',
    'Reference',
    Icons.bookmark_outline,
    'Inspired by or related to',
  ),
  ('evolution', 'Evolution', Icons.trending_up, 'Next version of this piece'),
  ('remix', 'Remix', Icons.shuffle, 'A remix or reinterpretation'),
  ('reply', 'Reply', Icons.reply, 'A response to this post'),
];

/// Shows a bottom sheet to pick a connection type.
/// Returns the selected type string, or null if dismissed.
Future<String?> showConnectionTypePicker(BuildContext context) {
  return showModalBottomSheet<String>(
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
          ...connectionTypes.map((t) {
            final (type, label, icon, description) = t;
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
                      Icon(icon, size: 20, color: colorInteractive),
                      const SizedBox(width: spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: colorTextPrimary,
                                fontSize: fontSizeMd,
                                fontWeight: weightMedium,
                              ),
                            ),
                            Text(
                              description,
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

/// Returns a human-readable label for a connection type.
String connectionTypeLabel(String type) {
  for (final (t, label, _, _) in connectionTypes) {
    if (t == type) return label;
  }
  return type;
}

/// Returns an icon for a connection type.
IconData connectionTypeIcon(String type) {
  for (final (t, _, icon, _) in connectionTypes) {
    if (t == type) return icon;
  }
  return Icons.link;
}
