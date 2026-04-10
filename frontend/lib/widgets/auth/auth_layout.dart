import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';
import '../common/app_footer.dart';
import 'gleisner_hero.dart';

/// Responsive layout shared by login and signup screens.
/// Wide (tablet+): hero left + form right, side by side.
/// Narrow (mobile): form on top, compact hero below.
class AuthLayout extends StatelessWidget {
  final Widget form;

  /// Called when the user taps "Try it first" in the hero.
  /// Navigation is handled by the caller (Screen level).
  final VoidCallback? onTryIt;

  /// Called when the user taps "About" in the footer.
  final VoidCallback? onAboutTap;

  const AuthLayout({
    super.key,
    required this.form,
    this.onTryIt,
    this.onAboutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorSurface0,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = isTabletOrWider(constraints.maxWidth);

            if (isWide) {
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: GleisnerHero(onTryIt: onTryIt)),
                        Container(width: 1, color: colorBorder),
                        Expanded(child: Center(child: form)),
                      ],
                    ),
                  ),
                  AppFooter(onAboutTap: onAboutTap),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: spaceXxl),
                  form,
                  const SizedBox(height: spaceLg),
                  GleisnerHero(compact: true, onTryIt: onTryIt),
                  const SizedBox(height: spaceLg),
                  AppFooter(onAboutTap: onAboutTap),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
