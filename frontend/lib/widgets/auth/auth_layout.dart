import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/gleisner_tokens.dart';
import 'gleisner_hero.dart';

/// Responsive layout shared by login and signup screens.
/// Wide (>= 800px): hero left + form right, side by side.
/// Narrow (< 800px): form on top, compact hero below.
class AuthLayout extends StatelessWidget {
  final Widget form;

  const AuthLayout({super.key, required this.form});

  // TODO(featured-artist): Replace with featured/demo artist from API
  void _handleTryIt(BuildContext context) => context.go('/@seeduser');

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
                  Expanded(
                    child: GleisnerHero(
                      onTryIt: () => _handleTryIt(context),
                    ),
                  ),
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
                  GleisnerHero(
                    compact: true,
                    onTryIt: () => _handleTryIt(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
