import 'package:flutter_test/flutter_test.dart';

/// Tests for the redirect logic patterns used in router.dart.
/// We test the RegExp pattern directly since GoRouter redirect is hard to
/// unit test without widget context.
void main() {
  final publicProfilePattern = RegExp(r'^/@[^/]+$');

  group('Public profile route matching', () {
    test('matches /@username', () {
      expect(publicProfilePattern.hasMatch('/@seeduser'), isTrue);
      expect(publicProfilePattern.hasMatch('/@alice'), isTrue);
      expect(publicProfilePattern.hasMatch('/@a'), isTrue);
    });

    test('rejects /@username/subpath', () {
      expect(publicProfilePattern.hasMatch('/@seeduser/settings'), isFalse);
      expect(publicProfilePattern.hasMatch('/@seeduser/admin'), isFalse);
      expect(publicProfilePattern.hasMatch('/@user/posts/123'), isFalse);
    });

    test('rejects non-profile paths', () {
      expect(publicProfilePattern.hasMatch('/login'), isFalse);
      expect(publicProfilePattern.hasMatch('/timeline'), isFalse);
      expect(publicProfilePattern.hasMatch('/@'), isFalse);
      expect(publicProfilePattern.hasMatch('/'), isFalse);
    });
  });

  group('Auth redirect rules', () {
    // Simulates the redirect logic from router.dart
    String? redirect({
      required String path,
      required String status, // 'loading', 'authenticated', 'unauthenticated'
    }) {
      if (status == 'loading') {
        return path == '/splash' ? null : '/splash';
      }

      final isAuthRoute = path == '/login' || path == '/signup';
      final isPublicProfile = RegExp(r'^/@[^/]+$').hasMatch(path);

      if (status == 'unauthenticated') {
        return (isAuthRoute || isPublicProfile) ? null : '/login';
      }

      // authenticated
      if (isAuthRoute || path == '/splash') return '/timeline';
      return null;
    }

    test('loading redirects to splash', () {
      expect(redirect(path: '/timeline', status: 'loading'), '/splash');
      expect(redirect(path: '/splash', status: 'loading'), isNull);
    });

    test('unauthenticated can access auth routes', () {
      expect(redirect(path: '/login', status: 'unauthenticated'), isNull);
      expect(redirect(path: '/signup', status: 'unauthenticated'), isNull);
    });

    test('unauthenticated can access public profiles', () {
      expect(
        redirect(path: '/@seeduser', status: 'unauthenticated'),
        isNull,
      );
      expect(redirect(path: '/@alice', status: 'unauthenticated'), isNull);
    });

    test('unauthenticated cannot access protected routes', () {
      expect(
        redirect(path: '/timeline', status: 'unauthenticated'),
        '/login',
      );
      expect(
        redirect(path: '/create-post', status: 'unauthenticated'),
        '/login',
      );
    });

    test('unauthenticated cannot access public profile subpaths', () {
      expect(
        redirect(path: '/@seeduser/settings', status: 'unauthenticated'),
        '/login',
      );
    });

    test('authenticated redirects auth pages to timeline', () {
      expect(
        redirect(path: '/login', status: 'authenticated'),
        '/timeline',
      );
      expect(
        redirect(path: '/signup', status: 'authenticated'),
        '/timeline',
      );
      expect(
        redirect(path: '/splash', status: 'authenticated'),
        '/timeline',
      );
    });

    test('authenticated can access all routes', () {
      expect(
        redirect(path: '/timeline', status: 'authenticated'),
        isNull,
      );
      expect(
        redirect(path: '/create-post', status: 'authenticated'),
        isNull,
      );
      expect(
        redirect(path: '/@seeduser', status: 'authenticated'),
        isNull,
      );
    });
  });
}
