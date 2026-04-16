import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';

/// Shared fallback view when an artist profile is not found.
/// Used in artist_page_screen and public_timeline_screen.
class ArtistNotFoundView extends StatelessWidget {
  final bool showBackButton;

  const ArtistNotFoundView({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              color: colorAccentGold.withValues(alpha: 0.4),
              size: 56,
            ),
            const SizedBox(height: spaceXl),
            Text(
              context.l10n.artistHasntArrivedYet,
              style: const TextStyle(
                color: colorTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: spaceMd),
            Text(
              context.l10n.starsStillAligning,
              style: const TextStyle(color: colorTextMuted, fontSize: 14),
            ),
            if (showBackButton) ...[
              const SizedBox(height: spaceXl),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  context.l10n.goBack,
                  style: const TextStyle(color: colorAccentGold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
