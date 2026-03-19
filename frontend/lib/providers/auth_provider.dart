import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/auth.dart';
import '../models/user.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({this.status = AuthStatus.loading, this.user, this.error});

  AuthState copyWith({AuthStatus? status, User? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final GraphQLClient _client;
  final FlutterSecureStorage _storage;

  AuthNotifier(this._client, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      super(const AuthState());

  Future<void> initialize() async {
    final token = await _storage.read(key: 'jwt');
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final result = await _client.query(QueryOptions(document: gql(meQuery)));

      if (result.hasException || result.data?['me'] == null) {
        await _storage.delete(key: 'jwt');
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final user = User.fromJson(result.data!['me'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      await _storage.delete(key: 'jwt');
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String username,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(signupMutation),
          variables: {
            'email': email,
            'password': password,
            'username': username,
          },
        ),
      );

      if (result.hasException) {
        final message =
            result.exception?.graphqlErrors.firstOrNull?.message ??
            'Signup failed';
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: message,
        );
        return;
      }

      final data = result.data!['signup'] as Map<String, dynamic>;
      await _storage.write(key: 'jwt', value: data['token'] as String);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(loginMutation),
          variables: {'email': email, 'password': password},
        ),
      );

      if (result.hasException) {
        final message =
            result.exception?.graphqlErrors.firstOrNull?.message ??
            'Login failed';
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: message,
        );
        return;
      }

      final data = result.data!['login'] as Map<String, dynamic>;
      await _storage.write(key: 'jwt', value: data['token'] as String);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt');
    _client.cache.store.reset();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.read(graphqlClientProvider);
  return AuthNotifier(client);
});
