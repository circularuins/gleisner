import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../providers/auth_provider.dart';
import '../theme/gleisner_assets.dart';
import '../theme/gleisner_tokens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorSurface0,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              GleisnerAssets.logoFull,
              height: 120,
              semanticsLabel: 'Gleisner logo',
            ),
            const SizedBox(height: spaceXl),
            Text(
              'Gleisner',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorTextPrimary,
              ),
            ),
            const SizedBox(height: spaceLg),
            const CircularProgressIndicator(color: colorAccentGold),
          ],
        ),
      ),
    );
  }
}
