import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/mutations/guardian.dart';
import '../models/user.dart';
import 'auth_provider.dart';
import 'disposable_notifier.dart';

class GuardianState {
  final List<User> children;
  final bool isLoading;
  final bool isLoaded;
  final String? error;

  const GuardianState({
    this.children = const [],
    this.isLoading = false,
    this.isLoaded = false,
    this.error,
  });

  GuardianState copyWith({
    List<User>? children,
    bool? isLoading,
    bool? isLoaded,
    String? error,
  }) {
    return GuardianState(
      children: children ?? this.children,
      isLoading: isLoading ?? this.isLoading,
      isLoaded: isLoaded ?? this.isLoaded,
      error: error,
    );
  }
}

class GuardianNotifier extends Notifier<GuardianState>
    with DisposableNotifier<GuardianState> {
  late GraphQLClient _client;
  late FlutterSecureStorage _storage;

  @override
  GuardianState build() {
    _client = ref.watch(graphqlClientProvider);
    _storage = ref.watch(secureStorageProvider);
    initDisposable();
    return const GuardianState();
  }

  Future<void> loadChildren({bool forceReload = false}) async {
    // Skip if already loaded (avoids re-fetch on every tab switch)
    if (state.isLoaded && !forceReload) return;

    state = state.copyWith(isLoading: true, error: null);

    final result = await _client.query(
      QueryOptions(
        document: gql(myChildrenQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (disposed) return;

    if (result.hasException) {
      debugPrint('[Guardian] loadChildren error: ${result.exception}');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load children.',
      );
      return;
    }

    final list = result.data?['myChildren'] as List<dynamic>? ?? [];
    final children = list
        .map((json) => User.fromJson(json as Map<String, dynamic>))
        .toList();

    state = GuardianState(children: children, isLoaded: true);
  }

  Future<bool> createChild({
    required String username,
    String? displayName,
    required String birthYearMonth,
    required String guardianPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _client.mutate(
      MutationOptions(
        document: gql(createChildAccountMutation),
        variables: {
          'username': username,
          'displayName': displayName,
          'birthYearMonth': birthYearMonth,
          'guardianPassword': guardianPassword,
        },
      ),
    );

    if (disposed) return false;

    if (result.hasException) {
      debugPrint('[Guardian] createChild error: ${result.exception}');
      // Map known business errors to user-friendly messages
      final serverMsg =
          result.exception?.graphqlErrors.firstOrNull?.message ?? '';
      final String message;
      if (serverMsg.contains('Username already taken')) {
        message = 'That username is already taken. Please choose another.';
      } else if (serverMsg.contains('Invalid password')) {
        message = 'Incorrect password. Please try again.';
      } else if (serverMsg.contains('Maximum of')) {
        message = 'You have reached the maximum number of child accounts.';
      } else {
        message = 'Failed to create child account. Please try again.';
      }
      state = state.copyWith(isLoading: false, error: message);
      return false;
    }

    // Reload children list
    await loadChildren(forceReload: true);
    return true;
  }

  Future<bool> switchToChild(String childId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _client.mutate(
      MutationOptions(
        document: gql(switchToChildMutation),
        variables: {'childId': childId},
      ),
    );

    if (disposed) return false;

    if (result.hasException) {
      debugPrint('[Guardian] switchToChild error: ${result.exception}');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to switch to child account.',
      );
      return false;
    }

    final data = result.data?['switchToChild'] as Map<String, dynamic>?;
    if (data == null) return false;

    final token = data['token'] as String;
    await _storage.write(key: 'jwt', value: token);

    if (disposed) return false;

    // Re-initialize auth with new JWT
    ref.invalidate(graphqlClientProvider);
    await ref.read(authProvider.notifier).initialize();

    state = const GuardianState();
    return true;
  }

  Future<bool> switchBackToGuardian() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _client.mutate(
      MutationOptions(document: gql(switchBackToGuardianMutation)),
    );

    if (disposed) return false;

    if (result.hasException) {
      debugPrint('[Guardian] switchBackToGuardian error: ${result.exception}');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to switch back to guardian.',
      );
      return false;
    }

    final data = result.data?['switchBackToGuardian'] as Map<String, dynamic>?;
    if (data == null) return false;

    final token = data['token'] as String;
    await _storage.write(key: 'jwt', value: token);

    if (disposed) return false;

    // Re-initialize auth with new JWT
    ref.invalidate(graphqlClientProvider);
    await ref.read(authProvider.notifier).initialize();

    state = const GuardianState();
    return true;
  }
}

final guardianProvider = NotifierProvider<GuardianNotifier, GuardianState>(
  GuardianNotifier.new,
);
