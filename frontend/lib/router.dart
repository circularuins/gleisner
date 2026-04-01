import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/artist/artist_page_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/create_post/create_post_screen.dart';
import 'screens/edit_post/edit_post_screen.dart';
import 'models/post.dart';
import 'screens/discover/discover_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/about/about_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/timeline/public_timeline_screen.dart';
import 'screens/timeline/timeline_screen.dart';
import 'widgets/common/bottom_nav_shell.dart';

final _authNotifierProvider = Provider<ValueNotifier<AuthStatus>>((ref) {
  final notifier = ValueNotifier(AuthStatus.loading);
  ref.listen<AuthState>(authProvider, (prev, next) {
    notifier.value = next.status;
  });
  // Also set the current value immediately
  notifier.value = ref.read(authProvider).status;
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Matches /@username exactly (no subpaths like /@user/settings).
final _publicProfilePattern = RegExp(r'^/@[^/]+$');

/// Valid username: alphanumeric + underscore, 1-39 chars.
final _validUsernamePattern = RegExp(r'^[a-zA-Z0-9_]{1,39}$');

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(_authNotifierProvider);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final path = state.uri.path;
      final status = authNotifier.value;

      if (status == AuthStatus.loading) {
        return path == '/splash' ? null : '/splash';
      }

      final isAuthRoute = path == '/login' || path == '/signup';
      final isPublicProfile = _publicProfilePattern.hasMatch(path);
      final isPublicPage = path == '/about';
      final isOnboarding = path == '/onboarding';

      if (status == AuthStatus.unauthenticated) {
        return (isAuthRoute || isPublicProfile || isPublicPage)
            ? null
            : '/login';
      }

      // authenticated — redirect auth/splash pages, but allow onboarding + public profiles
      if (path == '/signup') {
        return '/onboarding'; // Signup success → onboarding
      }
      if (path == '/login' || path == '/splash') return '/timeline';
      if (isOnboarding) return null; // Allow onboarding for authenticated users
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),

      // Main app with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BottomNavShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timeline',
                builder: (context, state) => const TimelineScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const DiscoverScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Onboarding (after signup, before main app)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Full-screen routes (outside bottom nav)
      GoRoute(
        path: '/create-post',
        builder: (context, state) => const CreatePostScreen(),
      ),
      // Edit post
      GoRoute(
        path: '/edit-post',
        redirect: (context, state) {
          if (state.extra is! Post) return '/timeline';
          return null;
        },
        builder: (context, state) {
          return EditPostScreen(post: state.extra! as Post);
        },
      ),
      // Artist Page (from Discover, authenticated)
      GoRoute(
        path: '/artist/:username',
        redirect: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          if (!_validUsernamePattern.hasMatch(username)) return '/discover';
          return null;
        },
        builder: (context, state) {
          final username = state.pathParameters['username']!;
          return ArtistPageScreen(username: username);
        },
      ),
      // Public timeline (unauthenticated access via /@username)
      GoRoute(
        path: '/@:username',
        redirect: (context, state) {
          final username = state.pathParameters['username'] ?? '';
          if (!_validUsernamePattern.hasMatch(username)) return '/login';
          return null;
        },
        builder: (context, state) {
          final username = state.pathParameters['username']!;
          return PublicTimelineScreen(username: username);
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});
