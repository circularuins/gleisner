import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../graphql/client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discover_provider.dart';
import '../../providers/my_artist_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../theme/gleisner_tokens.dart';
import 'register_artist_wizard.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    // Use myArtistProvider (own artist) instead of timelineProvider
    // which may hold another artist's data in fan mode
    final artist = ref.watch(myArtistProvider);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: const Text('Profile', style: TextStyle(color: colorTextPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(spaceXl),
        children: [
          // User info
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: colorSurface2,
                child: Text(
                  user.username[0].toUpperCase(),
                  style: textTitle.copyWith(color: colorTextPrimary),
                ),
              ),
              const SizedBox(width: spaceLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName ?? user.username, style: textHeading),
                    const SizedBox(height: spaceXxs),
                    Text(
                      user.email,
                      style: textCaption.copyWith(color: colorTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: spaceXxl),

          // Artist section
          if (artist != null) ...[
            // Registered artist info
            Container(
              padding: const EdgeInsets.all(spaceLg),
              decoration: BoxDecoration(
                color: colorSurface1,
                borderRadius: BorderRadius.circular(radiusLg),
                border: Border.all(color: colorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: colorAccentGold,
                      ),
                      const SizedBox(width: spaceSm),
                      Text(
                        'Artist',
                        style: textLabel.copyWith(color: colorAccentGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: spaceMd),
                  Text(
                    artist.displayName ?? artist.artistUsername,
                    style: textHeading,
                  ),
                  const SizedBox(height: spaceXxs),
                  Text(
                    '@${artist.artistUsername}',
                    style: textCaption.copyWith(color: colorTextMuted),
                  ),
                  if (artist.tracks.isNotEmpty) ...[
                    const SizedBox(height: spaceMd),
                    Text(
                      '${artist.tracks.length} track${artist.tracks.length == 1 ? '' : 's'}',
                      style: textCaption.copyWith(color: colorTextSecondary),
                    ),
                  ],
                  const SizedBox(height: spaceLg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/artist/${artist.artistUsername}',
                      ),
                      icon: const Icon(Icons.person, size: 16),
                      label: const Text('View Artist Page'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorAccentGold,
                        side: BorderSide(
                          color: colorAccentGold.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Become an artist CTA
            GestureDetector(
              onTap: () => _showRegisterSheet(context, ref),
              child: Container(
                padding: const EdgeInsets.all(spaceLg),
                decoration: BoxDecoration(
                  color: colorSurface1,
                  borderRadius: BorderRadius.circular(radiusLg),
                  border: Border.all(
                    color: colorAccentGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorAccentGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(radiusMd),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: colorAccentGold,
                      ),
                    ),
                    const SizedBox(width: spaceLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Become an Artist', style: textHeading),
                          const SizedBox(height: spaceXxs),
                          Text(
                            'Start sharing your creative journey',
                            style: textCaption.copyWith(
                              color: colorTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: colorInteractiveMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: spaceXxl),

          // Logout
          OutlinedButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              ref.invalidate(graphqlClientProvider);
              ref.invalidate(timelineProvider);
              ref.invalidate(myArtistProvider);
              ref.invalidate(tuneInProvider);
              ref.invalidate(discoverProvider);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showRegisterSheet(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RegisterArtistWizard(
          onRegistered: (artistUsername) {
            // Reload artist data on timeline
            ref.read(timelineProvider.notifier).loadArtist(artistUsername);
          },
        ),
      ),
    );
  }
}
