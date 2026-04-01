import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/utils/validators.dart';

void main() {
  group('validateUsername', () {
    test('rejects empty', () {
      expect(validateUsername(''), isNotNull);
      expect(validateUsername(null), isNotNull);
    });

    test('accepts 2-char username (backend minimum)', () {
      expect(validateUsername('ab'), isNull);
    });

    test('accepts 30-char username', () {
      expect(validateUsername('a' * 30), isNull);
    });

    test('rejects 1-char username', () {
      expect(validateUsername('a'), isNotNull);
    });

    test('rejects 31-char username', () {
      expect(validateUsername('a' * 31), isNotNull);
    });

    test('accepts letters, numbers, underscores', () {
      expect(validateUsername('user_123'), isNull);
      expect(validateUsername('ABC'), isNull);
    });

    test('rejects special characters', () {
      expect(validateUsername('user@name'), isNotNull);
      expect(validateUsername('user name'), isNotNull);
      expect(validateUsername('user-name'), isNotNull);
    });
  });

  group('validateEmail', () {
    test('rejects empty', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail(null), isNotNull);
    });

    test('accepts valid email', () {
      expect(validateEmail('user@example.com'), isNull);
    });

    test('rejects invalid email', () {
      expect(validateEmail('not-an-email'), isNotNull);
      expect(validateEmail('@no-user.com'), isNotNull);
    });
  });

  group('validatePassword', () {
    test('rejects empty', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword(null), isNotNull);
    });

    test('rejects too short', () {
      expect(validatePassword('1234567'), isNotNull);
    });

    test('accepts 8+ chars', () {
      expect(validatePassword('12345678'), isNull);
    });
  });

  group('validateInviteCode', () {
    test('accepts null and empty (optional)', () {
      expect(validateInviteCode(null), isNull);
      expect(validateInviteCode(''), isNull);
    });

    test('accepts valid 20-char hex', () {
      expect(validateInviteCode('a1b2c3d4e5f6a7b8c9d0'), isNull);
    });

    test('rejects invalid format', () {
      expect(validateInviteCode('too-short'), isNotNull);
      expect(validateInviteCode('UPPERCASE12345678901'), isNotNull);
    });
  });
}
