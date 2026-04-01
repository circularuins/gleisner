import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
        title: const Text('About Gleisner'),
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
            _section(
              'Operator',
              'This service is operated as a personal project.\n'
                  'Contact: gleisner.app@gmail.com',
            ),
            const SizedBox(height: spaceXl),
            _section(
              'External Services (Third-party data transmission)',
              'Gleisner uses the following external services. '
                  'Your data may be transmitted to these services '
                  'in the course of normal operation:\n\n'
                  '1. Cloudflare (CDN, media storage)\n'
                  '   - Purpose: Content delivery, image/video hosting\n'
                  '   - Data: Page requests, uploaded media\n\n'
                  '2. Claude API (Anthropic)\n'
                  '   - Purpose: AI-assisted title generation\n'
                  '   - Data: Post content (title/body) for processing\n\n'
                  '3. Railway\n'
                  '   - Purpose: Application hosting, database\n'
                  '   - Data: All application data is stored on Railway servers',
            ),
            const SizedBox(height: spaceXl),
            _section(
              'About',
              'Gleisner is a platform for artists to share their '
                  'multifaceted creative activities through a DAW-style '
                  'multi-track timeline.\n\n'
                  'Named after the Gleisner robots in Greg Egan\'s '
                  '"Diaspora" — bridging the physical and digital worlds.',
            ),
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
