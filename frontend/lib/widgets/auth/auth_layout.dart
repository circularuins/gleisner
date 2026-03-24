import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';
import 'gleisner_hero.dart';

/// Responsive layout shared by login and signup screens.
/// Wide (>= 800px): hero left + form right, side by side.
/// Narrow (< 800px): form on top, compact hero below.
class AuthLayout extends StatelessWidget {
  final Widget form;

  /// Called when the user taps "Try it first" in the hero.
  /// Navigation is handled by the caller (Screen level).
  final VoidCallback? onTryIt;

  const AuthLayout({super.key, required this.form, this.onTryIt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorSurface0,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: GleisnerHero(onTryIt: onTryIt)),
                  Container(width: 1, color: colorBorder),
                  Expanded(child: Center(child: form)),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
