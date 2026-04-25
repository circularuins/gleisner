import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:hive_ce/hive.dart';

import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/providers/auth_provider.dart';
import 'package:gleisner_web/utils/validators.dart' as gleisner_validators;

class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
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
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLink extends Link {
  final Map<String, dynamic>? data;
  final List<GraphQLError>? errors;
  final Exception? exception;

  /// Captured variables from the last request (for assertion).
  Map<String, dynamic>? lastVariables;

  _MockLink({this.data, this.errors, this.exception});

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    lastVariables = request.variables;
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

ProviderContainer _createContainer({
  required GraphQLClient client,
  required MockSecureStorage storage,
}) {
  return ProviderContainer(
    overrides: [
      graphqlClientProvider.overrideWithValue(client),
      secureStorageProvider.overrideWithValue(storage),
    ],
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
      final container = _createContainer(
        client: _clientWith(),
        storage: mockStorage,
      );
      addTearDown(container.dispose);

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.loading);
      expect(state.user, isNull);
      expect(state.error, isNull);
    });

    test('initialize without JWT sets unauthenticated', () async {
      final container = _createContainer(
        client: _clientWith(),
        storage: mockStorage,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).initialize();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(container.read(authProvider).user, isNull);
    });

    test(
      'initialize with JWT keeps authenticated on non-GraphQL errors (network assumed)',
      () async {
        await mockStorage.write(key: 'jwt', value: 'valid-token');

        final container = _createContainer(
          client: _clientWith(data: {'me': null}),
          storage: mockStorage,
        );
        addTearDown(container.dispose);

        await container.read(authProvider.notifier).initialize();

        expect(container.read(authProvider).status, AuthStatus.authenticated);
        expect(await mockStorage.read(key: 'jwt'), 'valid-token');
      },
    );

    test('initialize with JWT but GraphQL me=null deletes JWT', () async {
      await mockStorage.write(key: 'jwt', value: 'expired-token');

      final container = _createContainer(
        client: _clientWith(
          errors: [const GraphQLError(message: 'Unauthorized')],
        ),
        storage: mockStorage,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).initialize();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(await mockStorage.read(key: 'jwt'), isNull);
    });

    test('initialize with JWT but GraphQL error deletes JWT', () async {
      await mockStorage.write(key: 'jwt', value: 'bad-token');

      final container = _createContainer(
        client: _clientWith(
          errors: [const GraphQLError(message: 'Not authenticated')],
        ),
        storage: mockStorage,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).initialize();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(await mockStorage.read(key: 'jwt'), isNull);
    });

    test('initialize with JWT but network error preserves JWT', () async {
      await mockStorage.write(key: 'jwt', value: 'valid-token');

      final container = _createContainer(
        client: _clientWith(
          exception: const SocketException('Connection refused'),
        ),
        storage: mockStorage,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).initialize();

      expect(await mockStorage.read(key: 'jwt'), 'valid-token');
      expect(container.read(authProvider).status, AuthStatus.authenticated);
      expect(container.read(authProvider).error, 'Network unavailable');
    });

    test('logout clears JWT from storage', () async {
      await mockStorage.write(key: 'jwt', value: 'test-token');

      final container = _createContainer(
        client: _clientWith(),
        storage: mockStorage,
      );
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).logout();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(await mockStorage.read(key: 'jwt'), isNull);
    });
  });

  group('signup inviteCode handling', () {
    const signupResponse = {
      'signup': {
        'token': 'test-jwt-token',
        'user': {
          'id': 'u1',
          'did': 'did:web:gleisner.app:u:u1',
          'email': 'test@test.com',
          'username': 'testuser',
          'displayName': null,
          'bio': null,
          'avatarUrl': null,
          'profileVisibility': 'public',
          'publicKey': 'pk',
          'createdAt': '2026-01-01T00:00:00Z',
          'updatedAt': '2026-01-01T00:00:00Z',
        },
      },
    };

    late _MockLink link;
    late ProviderContainer container;

    setUp(() {
      link = _MockLink(data: signupResponse);
      final client = GraphQLClient(
        link: link,
        cache: GraphQLCache(store: InMemoryStore()),
      );
      container = _createContainer(client: client, storage: mockStorage);
    });

    tearDown(() => container.dispose());

    test('includes inviteCode in mutation variables when provided', () async {
      await container
          .read(authProvider.notifier)
          .signup(
            email: 'test@test.com',
            password: 'password123',
            username: 'testuser',
            birthYearMonth: '2000-01',
            inviteCode: 'abc123',
          );

      expect(link.lastVariables?['inviteCode'], 'abc123');
    });

    test('omits inviteCode from variables when null', () async {
      await container
          .read(authProvider.notifier)
          .signup(
            email: 'test@test.com',
            password: 'password123',
            username: 'testuser',
            birthYearMonth: '2000-01',
          );

      expect(link.lastVariables?.containsKey('inviteCode'), isFalse);
    });
  });

  group('validateInviteCode', () {
    // Import the validator function for boundary tests
    String? validate(String? v) => gleisner_validators.validateInviteCode(v);

    test('accepts null (optional field)', () {
      expect(validate(null), isNull);
    });

    test('accepts empty string', () {
      expect(validate(''), isNull);
    });

    test('accepts valid 20-char hex', () {
      expect(validate('a1b2c3d4e5f6a7b8c9d0'), isNull);
    });

    test('rejects 19-char hex (too short)', () {
      expect(validate('a1b2c3d4e5f6a7b8c9d'), isNotNull);
    });

    test('rejects 21-char hex (too long)', () {
      expect(validate('a1b2c3d4e5f6a7b8c9d0e'), isNotNull);
    });

    test('rejects uppercase hex', () {
      expect(validate('A1B2C3D4E5F6A7B8C9D0'), isNotNull);
    });

    test('rejects non-hex characters', () {
      expect(validate('a1b2c3d4e5f6a7b8c9gx'), isNotNull);
    });
  });
}
