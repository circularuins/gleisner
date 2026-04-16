import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_assets.dart';
import '../../theme/gleisner_tokens.dart';

/// About page — operator info + external services disclosure.
/// Required by Japanese Telecommunications Business Act (Article 27-12)
/// for Phase 0 even as a personal site.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aboutGleisner),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: spaceXl),
                child: SvgPicture.asset(
                  GleisnerAssets.logoFull,
                  height: 100,
                  semanticsLabel: context.l10n.gleisnerLogoLabel,
                ),
              ),
            ),
            _section(
              context.l10n.aboutOperatorTitle,
              context.l10n.aboutOperatorBody,
            ),
            const SizedBox(height: spaceXl),
            _section(
              context.l10n.aboutExternalTitle,
              context.l10n.aboutExternalBody,
            ),
            const SizedBox(height: spaceXl),
            _section(context.l10n.about, context.l10n.aboutDescription),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeLg,
            fontWeight: weightBold,
          ),
        ),
        const SizedBox(height: spaceSm),
        Text(
          body,
          style: const TextStyle(
            color: colorTextSecondary,
            fontSize: fontSizeMd,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
