import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';

/// Minimal footer for public-facing pages (login, signup, public timeline).
/// Shows operator info and a link to the About page.
class AppFooter extends StatelessWidget {
  final VoidCallback? onAboutTap;

  const AppFooter({super.key, this.onAboutTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: spaceLg,
        vertical: spaceMd,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: colorBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.appTitle,
            style: const TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeXs,
              fontWeight: weightMedium,
            ),
          ),
          const SizedBox(height: spaceXxs),
          GestureDetector(
            onTap: onAboutTap,
            child: Text(
              context.l10n.aboutExternal,
              style: TextStyle(
                color: colorInteractive,
                fontSize: fontSizeXs,
                decoration: TextDecoration.underline,
                decorationColor: colorInteractive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
