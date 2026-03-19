import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gleisner_web/models/track.dart';

void main() {
  group('Track.displayColor', () {
    test('parses valid hex color with hash prefix', () {
      final track = Track(
        id: '1',
        name: 'Test',
        color: '#FF6633',
        createdAt: DateTime.now(),
      );

      expect(track.displayColor, const Color(0xFFFF6633));
    });

    test('falls back to grey on invalid hex', () {
      final track = Track(
        id: '1',
        name: 'Test',
        color: '#ZZZZZZ',
        createdAt: DateTime.now(),
      );

      expect(track.displayColor, fallbackTrackColor);
    });

    test('falls back to grey on empty string', () {
      final track = Track(
        id: '1',
        name: 'Test',
        color: '',
        createdAt: DateTime.now(),
      );

      expect(track.displayColor, fallbackTrackColor);
    });
  });

  group('Track.fromJson', () {
    test('parses valid JSON', () {
      final track = Track.fromJson({
        'id': 'track-1',
        'name': 'Music',
        'color': '#6C63FF',
        'createdAt': '2026-03-01T00:00:00Z',
      });

      expect(track.id, 'track-1');
      expect(track.name, 'Music');
      expect(track.color, '#6C63FF');
    });
  });
}
