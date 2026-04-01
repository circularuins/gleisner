import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../graphql/client.dart';
import '../graphql/mutations/analytics.dart';

/// Generates a unique session ID (UUID v4 format using DateTime + hashCode).
String _generateSessionId() {
  final now = DateTime.now();
  return '${now.millisecondsSinceEpoch}-${now.hashCode.toRadixString(36)}';
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
  void trackEvent(String eventType, {Map<String, dynamic>? metadata}) {
    _client
        .mutate(
          MutationOptions(
            document: gql(trackEventMutation),
            variables: {
              'eventType': eventType,
              'sessionId': _sessionId,
              if (metadata != null) 'metadata': metadata,
            },
          ),
        )
        .catchError((e) {
          debugPrint('[Analytics] trackEvent failed: $e');
          return QueryResult.internal(
            parserFn: (_) => null,
            source: QueryResultSource.network,
          );
        });
  }

  void trackPageView(String page) {
    trackEvent('page_view', metadata: {'page': page});
  }
}

final analyticsProvider = NotifierProvider<AnalyticsNotifier, void>(
  AnalyticsNotifier.new,
);
