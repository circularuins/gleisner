import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import 'disposable_notifier.dart';
import '../graphql/queries/auth.dart';
import '../graphql/mutations/user.dart';
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

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

class AuthNotifier extends Notifier<AuthState> with DisposableNotifier {
  late GraphQLClient _client;
  late FlutterSecureStorage _storage;

  @override
  AuthState build() {
    _client = ref.watch(graphqlClientProvider);
    _storage = ref.watch(secureStorageProvider);
    initDisposable();
    return const AuthState();
  }

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
    required String birthYearMonth,
    String? displayName,
    String? inviteCode,
  }) async {
    await _executeMutation(
      mutation: signupMutation,
      variables: {
        'email': email,
        'password': password,
        'username': username,
        'birthYearMonth': birthYearMonth,
        if (displayName case final dn?) 'displayName': dn,
        if (inviteCode case final ic?) 'inviteCode': ic,
      },
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
      debugPrint('[AuthNotifier] _executeMutation error: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: fallbackError,
      );
    }
  }

  Future<bool> updateProfile({
    Object? displayName = sentinel,
    Object? bio = sentinel,
    Object? avatarUrl = sentinel,
    String? profileVisibility,
  }) async {
    final variables = <String, dynamic>{};
    if (displayName != sentinel) variables['displayName'] = displayName;
    if (bio != sentinel) variables['bio'] = bio;
    if (avatarUrl != sentinel) variables['avatarUrl'] = avatarUrl;
    if (profileVisibility != null) {
      variables['profileVisibility'] = profileVisibility;
    }

    try {
      final result = await _client.mutate(
        MutationOptions(document: gql(updateMeMutation), variables: variables),
      );

      if (result.hasException) {
        return false;
      }

      final data = result.data?['updateMe'] as Map<String, dynamic>?;
      if (data == null) return false;

      final currentUser = state.user;
      if (currentUser == null) return false;

      state = state.copyWith(
        user: currentUser.copyWith(
          displayName: data['displayName'] as String?,
          bio: data['bio'] as String?,
          avatarUrl: data['avatarUrl'] as String?,
          profileVisibility: data['profileVisibility'] as String?,
          updatedAt: DateTime.parse(data['updatedAt'] as String),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[AuthNotifier] updateProfile error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt');
    _client.cache.store.reset();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Delete the current user's account. Requires password re-confirmation.
  /// Returns null on success, error message on failure.
  ///
  /// Does NOT call logout() — the caller must navigate away first,
  /// then call logout() to avoid triggering a rebuild of the current
  /// screen while it's being disposed (see PR #204 crash fix).
  Future<String?> deleteAccount(String password) async {
    try {
      final result = await _client.mutate(
        MutationOptions(
          document: gql(deleteAccountMutation),
          variables: {'password': password},
        ),
      );
      if (result.hasException) {
        debugPrint('[Auth] deleteAccount error: ${result.exception}');
        return 'Failed to delete account';
      }
      return null; // success — caller handles navigation + logout
    } catch (e) {
      debugPrint('[Auth] deleteAccount error: $e');
      return 'Something went wrong. Please try again.';
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
