import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/timeline/timeline_screen.dart';

class _AuthChangeNotifier extends ChangeNotifier {
  AuthStatus _status = AuthStatus.loading;

  void update(AuthStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = _AuthChangeNotifier();

  ref.listen<AuthState>(authProvider, (_, next) {
    authChangeNotifier.update(next.status);
  });

  ref.onDispose(authChangeNotifier.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      final path = state.uri.path;
      final status = ref.read(authProvider).status;

      if (status == AuthStatus.loading) {
        return path == '/splash' ? null : '/splash';
      }

      final isAuthRoute = path == '/login' || path == '/signup';

      if (status == AuthStatus.unauthenticated) {
        return isAuthRoute || path == '/splash' ? null : '/login';
      }

      // authenticated
      if (isAuthRoute || path == '/splash') return '/timeline';
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
        path: '/timeline',
        builder: (context, state) => const TimelineScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);

  return router;
});
