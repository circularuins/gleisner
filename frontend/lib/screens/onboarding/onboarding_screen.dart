import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/gleisner_tokens.dart';

/// Post-signup onboarding: Welcome → Complete.
/// ADR 013: explains the two-tier account structure before entering the app.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final displayName = user?.displayName ?? user?.username ?? 'there';

    return Scaffold(
      backgroundColor: colorSurface0,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(spaceXl),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _step == 0
                ? _WelcomeStep(
                    key: const ValueKey(0),
                    onNext: () => setState(() => _step = 1),
                  )
                : _CompleteStep(
                    key: const ValueKey(1),
                    displayName: displayName,
                    onExplore: () => context.go('/timeline'),
                    onBecomeArtist: () {
                      context.go('/profile');
                      // Profile screen has "Become an Artist" button
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Step 1: Welcome ──

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Text(
          'Welcome to Gleisner',
          style: TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeTitle,
            fontWeight: weightBold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: spaceSm),
        const Text(
          'Your creative universe awaits',
          style: TextStyle(color: colorTextMuted, fontSize: fontSizeLg),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: spaceXxl),

        // Personal Account card
        _InfoCard(
          icon: Icons.person,
          title: 'Personal Account',
          description:
              'Discover artists, follow tracks, build your timeline. '
              'This is your personal identity on Gleisner.',
          color: colorInteractive,
        ),
        const SizedBox(height: spaceLg),

        // Artist Upgrade card
        _InfoCard(
          icon: Icons.auto_awesome,
          title: '+ Artist Upgrade',
          description:
              'Create an Artist Page, set up tracks, and broadcast your work. '
              'You can upgrade anytime after signup.',
          color: colorAccentGold,
        ),

        const Spacer(),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(
            backgroundColor: colorAccentGold,
            foregroundColor: colorSurface0,
            padding: const EdgeInsets.symmetric(vertical: spaceLg),
          ),
          child: const Text('Get Started'),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(spaceLg),
      decoration: BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: fontSizeMd,
                    fontWeight: weightSemibold,
                  ),
                ),
                const SizedBox(height: spaceXs),
                Text(
                  description,
                  style: const TextStyle(
                    color: colorTextSecondary,
                    fontSize: fontSizeSm,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Complete ──

class _CompleteStep extends StatelessWidget {
  final String displayName;
  final VoidCallback onExplore;
  final VoidCallback onBecomeArtist;

  const _CompleteStep({
    super.key,
    required this.displayName,
    required this.onExplore,
    required this.onBecomeArtist,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(Icons.check_circle, color: colorAccentGold, size: 64),
        const SizedBox(height: spaceXl),
        Text(
          'Welcome, $displayName!',
          style: const TextStyle(
            color: colorTextPrimary,
            fontSize: fontSizeTitle,
            fontWeight: weightBold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: spaceMd),
        const Text(
          'Your personal account is ready.',
          style: TextStyle(color: colorTextMuted, fontSize: fontSizeLg),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: spaceXxl),

        // What's included
        const _FeatureRow(icon: Icons.grid_view, label: 'Timeline'),
        const SizedBox(height: spaceMd),
        const _FeatureRow(icon: Icons.search, label: 'Discover artists'),
        const SizedBox(height: spaceMd),
        const _FeatureRow(icon: Icons.headphones, label: 'Tune In to artists'),

        const SizedBox(height: spaceXxl),

        // Become an Artist CTA
        Container(
          padding: const EdgeInsets.all(spaceLg),
          decoration: BoxDecoration(
            color: colorSurface1,
            borderRadius: BorderRadius.circular(radiusLg),
            border: Border.all(color: colorAccentGold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Text(
                'Ready to share your work?',
                style: TextStyle(
                  color: colorTextPrimary,
                  fontSize: fontSizeMd,
                  fontWeight: weightSemibold,
                ),
              ),
              const SizedBox(height: spaceXs),
              const Text(
                'Your personal account stays — the artist profile is a separate creative identity.',
                style: TextStyle(
                  color: colorTextMuted,
                  fontSize: fontSizeSm,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: spaceLg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBecomeArtist,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Become an Artist'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorAccentGold,
                    side: BorderSide(
                      color: colorAccentGold.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: spaceMd),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),
        FilledButton(
          onPressed: onExplore,
          style: FilledButton.styleFrom(
            backgroundColor: colorAccentGold,
            foregroundColor: colorSurface0,
            padding: const EdgeInsets.symmetric(vertical: spaceLg),
          ),
          child: const Text('Explore Gleisner'),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: colorInteractive, size: 20),
        const SizedBox(width: spaceMd),
        Text(
          label,
          style: const TextStyle(
            color: colorTextSecondary,
            fontSize: fontSizeMd,
          ),
        ),
      ],
    );
  }
}
