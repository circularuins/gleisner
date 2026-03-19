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

void main() {
  late MockSecureStorage mockStorage;
  late GraphQLClient client;
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
    client = GraphQLClient(
      link: HttpLink('http://localhost:4000/graphql'),
      cache: GraphQLCache(store: InMemoryStore()),
    );
  });

  group('AuthNotifier', () {
    test('initial state is loading', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = AuthNotifier(
        container.read(_refProvider),
        client,
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
        client,
        storage: mockStorage,
      );

      await notifier.initialize();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
    });

    test('logout clears JWT and resets state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await mockStorage.write(key: 'jwt', value: 'test-token');

      final notifier = AuthNotifier(
        container.read(_refProvider),
        client,
        storage: mockStorage,
      );

      await notifier.logout();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
      expect(await mockStorage.read(key: 'jwt'), isNull);
    });
  });
}

final _refProvider = Provider<Ref>((ref) => ref);
