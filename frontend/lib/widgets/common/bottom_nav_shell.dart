import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/gleisner_tokens.dart';

/// Shell wrapper providing bottom navigation for the main app tabs.
///
/// Each branch (Timeline, Discover, Profile) has its own Scaffold with AppBar.
/// This outer Scaffold holds only the NavigationBar — the nested Scaffold
/// pattern is intentional and standard for StatefulShellRoute with per-tab
/// AppBars (see go_router docs).
class BottomNavShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
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
