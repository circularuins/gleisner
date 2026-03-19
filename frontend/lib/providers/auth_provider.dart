import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/queries/auth.dart';
import '../models/user.dart';
import 'timeline_provider.dart';

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
  final Ref _ref;

  AuthNotifier(this._ref, this._client, {FlutterSecureStorage? storage})
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
          // Server explicitly rejected the token
          await _storage.delete(key: 'jwt');
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
        // Network/link error: keep JWT, stay authenticated optimistically
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
      // Any exception during network call: keep JWT, assume network issue
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

      final data = result.data![resultKey] as Map<String, dynamic>;
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
    _ref.invalidate(timelineProvider);
    _ref.invalidate(graphqlClientProvider);
    _ref.invalidate(graphqlClientNotifierProvider);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.read(graphqlClientProvider);
  return AuthNotifier(ref, client);
});
