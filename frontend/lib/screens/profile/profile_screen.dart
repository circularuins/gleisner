import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../graphql/client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../theme/gleisner_tokens.dart';
import 'register_artist_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final artist = ref.watch(timelineProvider).artist;

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
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showRegisterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
      ),
      builder: (_) => RegisterArtistSheet(
        onRegistered: (artistUsername) {
          // Reload artist data on timeline
          ref.read(timelineProvider.notifier).loadArtist(artistUsername);
        },
      ),
    );
  }
}
