import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/guardian_provider.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/account_switch_helper.dart';

/// Shell wrapper providing bottom navigation for the main app tabs.
///
/// Each branch (Timeline, Discover, Profile) has its own Scaffold with AppBar.
/// This outer Scaffold holds only the NavigationBar — the nested Scaffold
/// pattern is intentional and standard for StatefulShellRoute with per-tab
/// AppBars (see go_router docs).
///
/// When the user is operating in child account mode, a persistent banner
/// is displayed above all tab content to prevent accidental actions
/// on the wrong account.
class BottomNavShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isChild = user?.isChildAccount ?? false;
    final guardianLoading = ref.watch(guardianProvider).isLoading;

    return Scaffold(
      body: Column(
        children: [
          if (isChild)
            _ChildModeBanner(
              childName: user?.displayName ?? user?.username ?? '',
              isLoading: guardianLoading,
              onReturn: () async {
                final success = await ref
                    .read(guardianProvider.notifier)
                    .switchBackToGuardian();
                if (!success) return;
                await reloadAfterAccountSwitch(ref);
                ref
                    .read(guardianProvider.notifier)
                    .loadChildren(forceReload: true);
              },
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: colorSurface1,
        indicatorColor: Colors.transparent,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined, color: colorInteractiveMuted),
            selectedIcon: Icon(Icons.grid_view, color: colorTextPrimary),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.search, color: colorInteractiveMuted),
            selectedIcon: Icon(Icons.search, color: colorTextPrimary),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: colorInteractiveMuted),
            selectedIcon: Icon(Icons.person, color: colorTextPrimary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Compact persistent banner shown across all tabs when in child account mode.
class _ChildModeBanner extends StatelessWidget {
  final String childName;
  final bool isLoading;
  final VoidCallback onReturn;

  const _ChildModeBanner({
    required this.childName,
    this.isLoading = false,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + spaceXs,
        bottom: spaceXs,
        left: spaceLg,
        right: spaceSm,
      ),
      decoration: BoxDecoration(
        color: colorAccentGold.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(color: colorAccentGold.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.child_care, size: 16, color: colorAccentGold),
          const SizedBox(width: spaceSm),
          Expanded(
            child: Text(
              'Acting as $childName',
              style: const TextStyle(
                color: colorAccentGold,
                fontSize: fontSizeSm,
                fontWeight: weightMedium,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: isLoading ? null : onReturn,
            icon: const Icon(Icons.swap_horiz, size: 14),
            label: const Text('Exit'),
            style: TextButton.styleFrom(
              foregroundColor: colorAccentGold,
              padding: const EdgeInsets.symmetric(horizontal: spaceSm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: fontSizeSm,
                fontWeight: weightMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
