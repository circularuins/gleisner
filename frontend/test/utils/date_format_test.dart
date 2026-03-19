import 'package:flutter_test/flutter_test.dart';

import 'package:gleisner_web/utils/date_format.dart';

void main() {
  final now = DateTime(2026, 3, 20, 12, 0, 0);

  group('formatRelativeDate', () {
    test('returns "now" for less than 1 minute ago', () {
      final date = now.subtract(const Duration(seconds: 30));
      expect(formatRelativeDate(date, now: now), 'now');
    });

    test('returns minutes for less than 1 hour ago', () {
      final date = now.subtract(const Duration(minutes: 45));
      expect(formatRelativeDate(date, now: now), '45m');
    });

    test('returns hours for less than 1 day ago', () {
      final date = now.subtract(const Duration(hours: 5));
      expect(formatRelativeDate(date, now: now), '5h');
    });

    test('returns days for less than 7 days ago', () {
      final date = now.subtract(const Duration(days: 3));
      expect(formatRelativeDate(date, now: now), '3d');
    });

    test('returns month/day for same year', () {
      final date = DateTime(2026, 1, 15);
      expect(formatRelativeDate(date, now: now), '1/15');
    });

    test('returns year/month/day for different year', () {
      final date = DateTime(2025, 12, 25);
      expect(formatRelativeDate(date, now: now), '2025/12/25');
    });
  });
}
