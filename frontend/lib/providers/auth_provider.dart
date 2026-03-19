import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/auth.dart';
import '../models/user.dart';

import '../utils/sentinel.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({this.status = AuthStatus.loading, this.user, this.error});

  AuthState copyWith({
    AuthStatus? status,
    Object? user = sentinel,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user == sentinel ? this.user : user as User?,
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

      if (result.hasException) {
        final hasGraphqlErrors =
            result.exception?.graphqlErrors.isNotEmpty ?? false;
        if (hasGraphqlErrors) {
          await _storage.delete(key: 'jwt');
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
        state = AuthState(
          status: AuthStatus.authenticated,
          error: 'Network unavailable',
        );
        return;
      }

      if (result.data?['me'] == null) {
        await _storage.delete(key: 'jwt');
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      final user = User.fromJson(result.data!['me'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.authenticated,
        error: 'Network unavailable',
      );
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String username,
  }) async {
    await _executeMutation(
      mutation: signupMutation,
      variables: {'email': email, 'password': password, 'username': username},
      resultKey: 'signup',
      fallbackError: 'Signup failed',
    );
  }

  Future<void> login({required String email, required String password}) async {
    await _executeMutation(
      mutation: loginMutation,
      variables: {'email': email, 'password': password},
      resultKey: 'login',
      fallbackError: 'Login failed',
    );
  }

  Future<void> _executeMutation({
    required String mutation,
    required Map<String, dynamic> variables,
    required String resultKey,
    required String fallbackError,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final result = await _client.mutate(
        MutationOptions(document: gql(mutation), variables: variables),
      );

      if (result.hasException) {
        final message =
            result.exception?.graphqlErrors.firstOrNull?.message ??
            fallbackError;
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: message,
        );
        return;
      }

      final payload = result.data?[resultKey] as Map<String, dynamic>?;
      if (payload == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: fallbackError,
        );
        return;
      }

      await _storage.write(key: 'jwt', value: payload['token'] as String);
      final user = User.fromJson(payload['user'] as Map<String, dynamic>);
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
  final client = ref.watch(graphqlClientProvider);
  return AuthNotifier(client);
});
