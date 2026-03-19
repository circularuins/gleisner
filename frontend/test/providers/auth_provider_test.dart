import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_ce/hive.dart';

import 'package:gleisner_web/providers/auth_provider.dart';

class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A Link that returns a predetermined result or throws an error.
class _MockLink extends Link {
  final Map<String, dynamic>? data;
  final List<GraphQLError>? errors;
  final Exception? exception;

  _MockLink({this.data, this.errors, this.exception});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    if (exception != null) {
      return Stream.error(exception!);
    }
    return Stream.value(Response(data: data, errors: errors, response: {}));
  }
}

GraphQLClient _clientWith({
  Map<String, dynamic>? data,
  List<GraphQLError>? errors,
  Exception? exception,
}) {
  return GraphQLClient(
    link: _MockLink(data: data, errors: errors, exception: exception),
    cache: GraphQLCache(store: InMemoryStore()),
  );
}

void main() {
  late MockSecureStorage mockStorage;
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('gleisner_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  setUp(() {
    mockStorage = MockSecureStorage();
  });

  group('AuthNotifier', () {
    test('initial state is loading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = AuthNotifier(
        container.read(_refProvider),
        _clientWith(),
        storage: mockStorage,
      );

      expect(notifier.state.status, AuthStatus.loading);
      expect(notifier.state.user, isNull);
      expect(notifier.state.error, isNull);
    });

    test('initialize without JWT sets unauthenticated', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = AuthNotifier(
        container.read(_refProvider),
        _clientWith(),
        storage: mockStorage,
      );

      await notifier.initialize();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
    });

    test('initialize with JWT but non-error response stays authenticated',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await mockStorage.write(key: 'jwt', value: 'valid-token');

      // Non-error response: catch block treats as network issue, keeps JWT
      final client = _clientWith(data: {'me': null});

      final notifier = AuthNotifier(
        container.read(_refProvider),
        client,
        storage: mockStorage,
      );

      await notifier.initialize();

      // With a valid JWT, non-GraphQL-error responses keep authenticated
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(await mockStorage.read(key: 'jwt'), 'valid-token');
    });

    test('initialize with JWT but GraphQL me=null deletes JWT', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await mockStorage.write(key: 'jwt', value: 'expired-token');

      // GraphQL error means server rejected
      final client = _clientWith(
        errors: [const GraphQLError(message: 'Unauthorized')],
      );

      final notifier = AuthNotifier(
        container.read(_refProvider),
        client,
        storage: mockStorage,
      );

      await notifier.initialize();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(await mockStorage.read(key: 'jwt'), isNull);
    });

    test('initialize with JWT but GraphQL error deletes JWT', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await mockStorage.write(key: 'jwt', value: 'bad-token');
      final client = _clientWith(
        errors: [const GraphQLError(message: 'Not authenticated')],
      );

      final notifier = AuthNotifier(
        container.read(_refProvider),
        client,
        storage: mockStorage,
      );

      await notifier.initialize();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(await mockStorage.read(key: 'jwt'), isNull);
    });

    test('initialize with JWT but network error preserves JWT', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await mockStorage.write(key: 'jwt', value: 'valid-token');
      final client = _clientWith(
        exception: const SocketException('Connection refused'),
      );

      final notifier = AuthNotifier(
        container.read(_refProvider),
        client,
        storage: mockStorage,
      );

      await notifier.initialize();

      expect(await mockStorage.read(key: 'jwt'), 'valid-token');
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.error, 'Network unavailable');
    });

    test('logout clears JWT from storage', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await mockStorage.write(key: 'jwt', value: 'test-token');

      final notifier = AuthNotifier(
        container.read(_refProvider),
        _clientWith(),
        storage: mockStorage,
      );

      await notifier.logout();

      // JWT must be deleted regardless of provider re-creation
      expect(await mockStorage.read(key: 'jwt'), isNull);
    });
  });
}

final _refProvider = Provider<Ref>((ref) => ref);
