import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_assets.dart';
import '../../theme/gleisner_tokens.dart';

/// Hero section showing Gleisner's value propositions.
/// Used on login/signup screens to communicate what Gleisner is about.
class GleisnerHero extends StatelessWidget {
  /// If true, renders a compact vertical list (for narrow screens).
  /// If false, renders full layout with branding header (for wide screens).
  final bool compact;

  /// Called when the user taps the "Try it first" link.
  /// Navigation is handled by the caller, not this widget.
  final VoidCallback? onTryIt;

  const GleisnerHero({super.key, this.compact = false, this.onTryIt});

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildFull(BuildContext context) {
    return Container(
      color: colorSurface0,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                GleisnerAssets.logoFull,
                height: 80,
                semanticsLabel: context.l10n.gleisnerLogoLabel,
              ),
              const SizedBox(width: spaceLg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.appTitle,
                    style: GoogleFonts.urbanist(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: colorTextPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    context.l10n.yourCreativeUniverse,
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: colorTextMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: spaceXxl + spaceLg),
          ..._propositions(
            context,
          ).expand((p) => [p, const SizedBox(height: spaceXl)]),
          if (onTryIt != null) ...[
            const SizedBox(height: spaceLg),
            _TryItLink(onTap: onTryIt!),
          ],
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: spaceXl,
        vertical: spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: colorBorder, height: 1),
          const SizedBox(height: spaceLg),
          ..._propositions(context).map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: spaceMd),
              child: p,
            ),
          ),
          if (onTryIt != null) ...[
            const SizedBox(height: spaceSm),
            _TryItLink(onTap: onTryIt!),
          ],
        ],
      ),
    );
  }

  List<Widget> _propositions(BuildContext context) => [
    _Proposition(
      icon: Icons.shield_outlined,
      title: context.l10n.ownCreativeIdentity,
      description: context.l10n.keepArtKeepControl,
    ),
    _Proposition(
      icon: Icons.auto_awesome,
      title: context.l10n.mapYourJourney,
      description: context.l10n.multipleProjectsOnePlaceTitle,
    ),
    _Proposition(
      icon: Icons.hub_outlined,
      title: context.l10n.watchConnectionsEmerge,
      description: context.l10n.seeHowIdeasRelate,
    ),
  ];
}

class _Proposition extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _Proposition({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorAccentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          child: Icon(icon, size: 18, color: colorAccentGold),
        ),
        const SizedBox(width: spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textHeading.copyWith(fontSize: 15)),
              const SizedBox(height: spaceXxs),
              Text(
                description,
                style: textCaption.copyWith(
                  color: colorTextSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TryItLink extends StatelessWidget {
  final VoidCallback onTap;

  const _TryItLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.tryItFirst,
            style: textBody.copyWith(color: colorInteractive, fontSize: 14),
          ),
          const SizedBox(width: spaceXs),
          const Icon(Icons.arrow_forward, size: 16, color: colorInteractive),
        ],
      ),
    );
  }
}
