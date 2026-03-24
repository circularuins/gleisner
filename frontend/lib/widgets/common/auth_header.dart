import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/gleisner_tokens.dart';

class AuthHeader extends StatelessWidget {
  final String subtitle;

  const AuthHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Gleisner',
          style: GoogleFonts.urbanist(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: colorTextPrimary,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: spaceXxs),
        Text(
          'Your creative universe',
          style: textCaption.copyWith(color: colorTextMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: spaceLg),
        Text(
          subtitle,
          style: textBody.copyWith(color: colorTextSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
