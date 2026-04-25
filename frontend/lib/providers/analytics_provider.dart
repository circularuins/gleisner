import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/mutations/analytics.dart';

/// Generates a cryptographically random session ID (32 hex chars).
String _generateSessionId() {
  final rng = Random.secure();
  final bytes = List.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class AnalyticsNotifier extends Notifier<void> {
  late GraphQLClient _client;
  late String _sessionId;

  @override
  void build() {
    _client = ref.watch(graphqlClientProvider);
    _sessionId = _generateSessionId();
  }

  /// Fire-and-forget analytics event. Errors are silently logged.
  /// Works for both authenticated and unauthenticated users —
  /// the backend trackEvent mutation does not require auth.
  void trackEvent(String eventType, {Map<String, dynamic>? metadata}) {
    unawaited(
      _client
          .mutate(
            MutationOptions(
              document: gql(trackEventMutation),
              variables: {
                'eventType': eventType,
                'sessionId': _sessionId,
                'metadata': ?metadata,
              },
            ),
          )
          .catchError((e) {
            debugPrint('[Analytics] trackEvent failed: $e');
            return QueryResult.internal(
              parserFn: (_) => null,
              source: QueryResultSource.network,
            );
          }),
    );
  }

  /// Track a page view. [page] should use placeholders for PII
  /// (e.g., '/artist/:username' instead of '/artist/john').
  void trackPageView(String page, {Map<String, dynamic>? metadata}) {
    trackEvent('page_view', metadata: {'page': page, ...?metadata});
  }
}

final analyticsProvider = NotifierProvider<AnalyticsNotifier, void>(
  AnalyticsNotifier.new,
);
