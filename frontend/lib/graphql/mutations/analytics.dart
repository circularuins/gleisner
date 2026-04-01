const trackEventMutation = '''
  mutation TrackEvent(\$eventType: String!, \$sessionId: String!, \$metadata: JSON) {
    trackEvent(eventType: \$eventType, sessionId: \$sessionId, metadata: \$metadata)
  }
''';
