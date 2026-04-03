import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/gleisner_tokens.dart';

class AuthHeader extends StatelessWidget {
  final String subtitle;

  const AuthHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset('assets/images/logo-icon.svg', height: 60),
        const SizedBox(height: spaceMd),
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
