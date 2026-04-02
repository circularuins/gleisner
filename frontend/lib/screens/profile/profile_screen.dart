import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../graphql/client.dart';
import '../../models/user.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discover_provider.dart';
import '../../providers/edit_artist_provider.dart';
import '../../providers/guardian_provider.dart';
import '../../providers/my_artist_provider.dart';
import '../../providers/timeline_provider.dart';
import '../../providers/tune_in_provider.dart';
import '../../providers/tutorial_provider.dart';
import '../../providers/unassigned_posts_provider.dart';
import '../../theme/gleisner_tokens.dart';
import 'create_child_sheet.dart';
import 'edit_profile_sheet.dart';
import 'register_artist_wizard.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analyticsProvider.notifier).trackPageView('/profile');
      // Load children if not a child account
      final user = ref.read(authProvider).user;
      if (user != null && !user.isChildAccount) {
        ref.read(guardianProvider.notifier).loadChildren();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    // Use myArtistProvider (own artist) instead of timelineProvider
    // which may hold another artist's data in fan mode
    final artist = ref.watch(myArtistProvider);
    final tuneInState = ref.watch(tuneInProvider);
    final guardianState = ref.watch(guardianProvider);

    if (user == null) return const SizedBox.shrink();

    final isChild = user.isChildAccount;

    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: const Text('Profile', style: TextStyle(color: colorTextPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: colorTextSecondary),
            onPressed: () => _showEditSheet(context, user),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(spaceXl),
        children: [
          // Child mode banner
          if (isChild) ...[
            Container(
              padding: const EdgeInsets.all(spaceLg),
              decoration: BoxDecoration(
                color: colorAccentGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(radiusMd),
                border: Border.all(
                  color: colorAccentGold.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.child_care,
                        size: 18,
                        color: colorAccentGold,
                      ),
                      const SizedBox(width: spaceSm),
                      Text(
                        'Child Account Mode',
                        style: textLabel.copyWith(color: colorAccentGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: spaceSm),
                  Text(
                    'You are viewing as ${user.displayName ?? user.username}. '
                    'All actions are performed on behalf of this child account.',
                    style: textCaption.copyWith(
                      color: colorAccentGold.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: spaceMd),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _switchBackToGuardian,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Return to My Account'),
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
            const SizedBox(height: spaceLg),
          ],

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
                      '@${user.username}',
                      style: textCaption.copyWith(color: colorTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: spaceLg),
            Text(
              user.bio!,
              style: textBody.copyWith(color: colorTextSecondary),
            ),
          ],

          // Meta: Joined + Tuned In
          const SizedBox(height: spaceMd),
          Wrap(
            spacing: spaceLg,
            children: [
              Text(
                'Joined ${_formatJoinDate(user.createdAt)}',
                style: textCaption.copyWith(color: colorTextMuted),
              ),
              if (tuneInState.tunedInArtists.isNotEmpty)
                Text(
                  '${tuneInState.tunedInArtists.length} Tuned In',
                  style: textCaption.copyWith(color: colorTextMuted),
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
                  // Artist visibility toggle
                  const SizedBox(height: spaceMd),
                  Row(
                    children: [
                      Icon(
                        artist.profileVisibility == 'private'
                            ? Icons.lock_outline
                            : Icons.public,
                        size: 14,
                        color: colorTextMuted,
                      ),
                      const SizedBox(width: spaceXs),
                      Text(
                        artist.profileVisibility == 'private'
                            ? 'Private'
                            : 'Public',
                        style: textCaption.copyWith(color: colorTextMuted),
                      ),
                      const Spacer(),
                      Switch(
                        value: artist.profileVisibility == 'public',
                        activeColor: colorAccentGold,
                        onChanged: (isPublic) async {
                          final v = isPublic ? 'public' : 'private';
                          await ref
                              .read(editArtistProvider.notifier)
                              .updateArtist(profileVisibility: v);
                          ref.read(discoverProvider.notifier).loadInitial();
                        },
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: spaceSm),
                    child: Text(
                      artist.profileVisibility == 'private'
                          ? 'Your artist page is hidden from Discover and search. Only existing fans and direct links can access it.'
                          : 'Your artist page is visible in Discover and search. Anyone can view your profile and Tune In.',
                      style: textCaption.copyWith(
                        color: colorTextMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: spaceSm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/artist/${artist.artistUsername}'),
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
              onTap: () => _showRegisterSheet(context),
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

          // Guardian section: child accounts (not shown for child accounts)
          if (!isChild) ...[
            const SizedBox(height: spaceXxl),
            Row(
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 18,
                  color: colorTextMuted,
                ),
                const SizedBox(width: spaceSm),
                Text(
                  'Child Accounts',
                  style: textHeading.copyWith(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: spaceMd),
            if (guardianState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(spaceLg),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              // Child cards
              ...guardianState.children.map(
                (child) => Padding(
                  padding: const EdgeInsets.only(bottom: spaceSm),
                  child: _buildChildCard(child),
                ),
              ),
              // Add child button
              OutlinedButton.icon(
                onPressed: () => _showCreateChildSheet(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Child Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorTextSecondary,
                  side: const BorderSide(color: colorBorder),
                ),
              ),
            ],
          ],

          const SizedBox(height: spaceXxl),

          // Child mode: show "Return to My Account" prominently above Logout
          if (isChild) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _switchBackToGuardian,
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Return to My Account'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorAccentGold,
                  foregroundColor: colorSurface0,
                  padding: const EdgeInsets.symmetric(vertical: spaceMd),
                ),
              ),
            ),
            const SizedBox(height: spaceMd),
          ],

          // Logout
          OutlinedButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              ref.invalidate(graphqlClientProvider);
              ref.invalidate(timelineProvider);
              ref.invalidate(myArtistProvider);
              ref.invalidate(tuneInProvider);
              ref.invalidate(discoverProvider);
              ref.invalidate(unassignedPostsProvider);
              ref.invalidate(analyticsProvider);
              ref.invalidate(guardianProvider);
              await ref.read(tutorialProvider.notifier).reset();
              ref.invalidate(tutorialProvider);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(User child) {
    return Container(
      padding: const EdgeInsets.all(spaceMd),
      decoration: BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorSurface2,
            child: Text(
              child.username[0].toUpperCase(),
              style: textLabel.copyWith(color: colorTextPrimary),
            ),
          ),
          const SizedBox(width: spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.displayName ?? child.username,
                  style: textBody.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  '@${child.username}',
                  style: textCaption.copyWith(color: colorTextMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _switchToChild(child.id),
            child: Text(
              'Switch',
              style: textLabel.copyWith(color: colorAccentGold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _switchToChild(String childId) async {
    final success = await ref
        .read(guardianProvider.notifier)
        .switchToChild(childId);
    if (!success || !mounted) return;
    await _reloadAfterSwitch();
  }

  Future<void> _switchBackToGuardian() async {
    final success = await ref
        .read(guardianProvider.notifier)
        .switchBackToGuardian();
    if (!success || !mounted) return;
    await _reloadAfterSwitch();
    // Reload children list for guardian view
    ref.read(guardianProvider.notifier).loadChildren();
  }

  /// Invalidate all user-specific providers and reload data after JWT switch.
  /// Similar to the artist registration flow — explicit reload is needed
  /// because StatefulShellRoute tabs don't auto-refresh on invalidate.
  Future<void> _reloadAfterSwitch() async {
    ref.invalidate(myArtistProvider);
    ref.invalidate(timelineProvider);
    ref.invalidate(tuneInProvider);
    ref.invalidate(discoverProvider);
    ref.invalidate(unassignedPostsProvider);
    // Explicitly reload data with new JWT
    await ref.read(myArtistProvider.notifier).load();
    if (!mounted) return;
    ref.read(discoverProvider.notifier).loadInitial();
    ref.read(tuneInProvider.notifier).loadMyTuneIns();
  }

  static String _formatJoinDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _showEditSheet(BuildContext context, User user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(
        initialDisplayName: user.displayName,
        initialBio: user.bio,
        initialAvatarUrl: user.avatarUrl,
        initialProfileVisibility: user.profileVisibility,
        isChildAccount: user.isChildAccount,
      ),
    );
  }

  Future<void> _showRegisterSheet(BuildContext context) async {
    final artistUsername = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => RegisterArtistWizard(onRegistered: (_) {}),
      ),
    );
    if (artistUsername == null || !context.mounted) return;

    await ref.read(myArtistProvider.notifier).load();
    await ref.read(timelineProvider.notifier).loadArtist(artistUsername);
    if (!context.mounted) return;
    context.go('/timeline');
  }

  void _showCreateChildSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateChildSheet(),
    );
  }
}
