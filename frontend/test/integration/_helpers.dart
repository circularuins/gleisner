// Shared infrastructure for integration tests in `test/integration/`.
//
// Why this file exists: most flows beyond the cold-boot smoke test need a
// stub GraphQL link (so `featuredArtistProvider.load()` and `me` queries
// don't hang on the default HttpLink) and a mock secure storage (so
// `AuthNotifier.initialize()` can be driven into authenticated state without
// real keychain access). Test cases override `graphqlClientProvider` and
// `secureStorageProvider` via `ProviderScope.overrides`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'package:gql/ast.dart';

import 'package:gleisner_web/app.dart';
import 'package:gleisner_web/graphql/client.dart';
import 'package:gleisner_web/providers/auth_provider.dart';

/// Mock GraphQL link that responds based on the operation name extracted
/// from the parsed GraphQL AST.
///
/// Tests register handlers via the [responses] map keyed by operation name
/// (e.g. `'Me'`, `'FeaturedArtist'`). The operation name is read from the
/// first `OperationDefinitionNode` in the document AST because
/// graphql_flutter's `Request.operation.operationName` arrives empty on the
/// link side for parsed-document queries. The codebase only uses named
/// single-operation documents (`gql('query Foo { ... }')`) so this is safe;
/// anonymous queries land in the unmatched bucket and surface a warning.
///
/// Unmatched operations log a debug warning and return empty data. The
/// warning is the failure mode for typos / forgotten registrations — silent
/// pass is the worst outcome for an integration test, so tests that want to
/// assert "no operation X" should use [errors] explicitly.
class StubGraphQLLink extends Link {
  final Map<String, Map<String, dynamic>> responses;
  final Map<String, List<GraphQLError>> errors;

  StubGraphQLLink({
    Map<String, Map<String, dynamic>>? responses,
    Map<String, List<GraphQLError>>? errors,
  }) : responses = responses ?? {},
       errors = errors ?? {};

  String _operationName(Request request) {
    final declared = request.operation.operationName;
    if (declared != null && declared.isNotEmpty) return declared;
    for (final def in request.operation.document.definitions) {
      if (def is OperationDefinitionNode) {
        final name = def.name?.value;
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return '';
  }

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    final operationName = _operationName(request);
    final hasResponse = responses.containsKey(operationName);
    final hasError = errors.containsKey(operationName);
    if (!hasResponse && !hasError) {
      // Surface unmatched operations so test typos (e.g. registering
      // `'Mee'` instead of `'Me'`) don't fail silently. Tests that want a
      // "no data" response must register `responses['Foo'] = {}`
      // explicitly.
      debugPrint(
        '[StubGraphQLLink] Unmatched operation "$operationName" — '
        'returning empty data. Register responses["$operationName"] in '
        'the test if this is intentional.',
      );
    }
    return Stream.value(
      Response(
        data: responses[operationName],
        errors: errors[operationName],
        response: const {},
      ),
    );
  }
}

/// Builds a GraphQL client backed by [StubGraphQLLink].
///
/// Note on [FetchPolicy.noCache]: this differs from production
/// (`lib/graphql/client.dart` uses defaults — `cacheFirst` for queries,
/// `networkOnly` for mutations) but is a deliberate choice for integration
/// tests. Cache normalization in graphql_flutter requires every selected
/// field (including `__typename`) to be present in the response or it
/// throws `PartialDataException`. We don't want integration tests to police
/// fixture completeness — that's what provider unit tests
/// (`test/providers/`) cover. `noCache` lets the link's response flow
/// straight to the caller without normalization, keeping the assertion
/// surface focused on routing/UI behaviour.
GraphQLClient stubClient({
  Map<String, Map<String, dynamic>>? responses,
  Map<String, List<GraphQLError>>? errors,
}) {
  return GraphQLClient(
    link: StubGraphQLLink(responses: responses, errors: errors),
    cache: GraphQLCache(store: InMemoryStore()),
    defaultPolicies: DefaultPolicies(
      query: Policies(fetch: FetchPolicy.noCache),
      mutate: Policies(fetch: FetchPolicy.noCache),
    ),
  );
}

/// In-memory secure storage for tests. Mirrors the surface used by
/// [AuthNotifier] / [TutorialNotifier] / [GuardianNotifier]; methods we don't
/// exercise fall back to [Map.remove] / no-op so tests stay deterministic.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  FakeSecureStorage({Map<String, String>? initial}) {
    if (initial != null) _store.addAll(initial);
  }

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
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
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

/// Boots the full app with stubbed GraphQL + secure storage. Pumps until the
/// router has settled (auth init → redirect → first frame of destination
/// screen) so tests can assert against the resulting route.
///
/// Locale is forced to English so assertions can match l10n strings without
/// depending on the developer's machine locale (CI / Chrome on a Japanese
/// Mac would otherwise resolve to ja_JP).
Future<void> pumpApp(
  WidgetTester tester, {
  GraphQLClient? client,
  FakeSecureStorage? storage,
  Size? surfaceSize,
}) async {
  await initHiveForFlutter();
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  // Default to a mobile-sized surface so AuthLayout / BottomNavShell pick the
  // narrow (non-rail, hero-compact) variant. The default test surface
  // (800x600) lands in the tablet breakpoint where `GleisnerHero`'s wide
  // layout overflows and BottomNavShell uses NavigationRail — both of which
  // make assertions noisier than necessary for routing tests.
  await tester.binding.setSurfaceSize(surfaceSize ?? const Size(414, 896));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final effectiveClient = client ?? stubClient();
  final effectiveStorage = storage ?? FakeSecureStorage();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        graphqlClientProvider.overrideWithValue(effectiveClient),
        secureStorageProvider.overrideWithValue(effectiveStorage),
      ],
      child: const GleisnerApp(),
    ),
  );

  // Drive the boot path:
  //   1. SplashScreen schedules `auth.initialize()` via Future.microtask
  //   2. initialize() awaits storage / GraphQL → state becomes (un)authed
  //   3. routerProvider's refreshListenable fires → redirect → navigation
  //   4. Destination screen mounts and runs its initState
  //
  // Strategy: `pumpAndSettle` would settle the splash screen's
  // CircularProgressIndicator and the GoRouter transition, but the post-
  // login TimelineScreen owns a 35-second repeating AnimationController
  // (synapse dots) that never settles — settle would hang for 10 minutes.
  // Wrap it in a short timeout so we get the benefit on the unauth side
  // (where everything settles fast) and fall back to explicit pumps on
  // the authenticated side.
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } on FlutterError {
    // Timeout reached — destination has perpetual animations (Timeline).
    // Fall through; the last few pumps below still flush pending
    // microtasks and the GoRouter transition.
  }
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Shorthand: a `me` query payload representing an authenticated, non-child
/// user with no artist registration. Sufficient to drive the router into
/// `/timeline` and render the bottom-nav shell.
Map<String, dynamic> meUserPayload({
  String id = 'u1',
  String username = 'tester',
  String? displayName,
}) {
  return {
    'me': {
      'id': id,
      'did': 'did:web:gleisner.app:u:$id',
      'email': '$username@test.local',
      'username': username,
      'displayName': displayName,
      'bio': null,
      'avatarUrl': null,
      'profileVisibility': 'public',
      'publicKey': 'pk',
      'birthYearMonth': '1990-01',
      'isChildAccount': false,
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    },
  };
}
