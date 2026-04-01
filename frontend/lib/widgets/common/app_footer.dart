import 'package:flutter/material.dart';

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
          const Text(
            'Gleisner',
            style: TextStyle(
              color: colorTextMuted,
              fontSize: fontSizeXs,
              fontWeight: weightMedium,
            ),
          ),
          const SizedBox(height: spaceXxs),
          GestureDetector(
            onTap: onAboutTap,
            child: const Text(
              'About / External Services',
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
