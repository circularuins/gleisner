import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/utils/color_hex.dart';

void main() {
  group('isValidHex6', () {
    test('accepts canonical lowercase 6-digit HEX', () {
      expect(isValidHex6('#f97316'), isTrue);
    });

    test('accepts uppercase 6-digit HEX', () {
      expect(isValidHex6('#F97316'), isTrue);
    });

    test('accepts mixed-case 6-digit HEX', () {
      expect(isValidHex6('#aB12Cd'), isTrue);
    });

    test('rejects null', () {
      expect(isValidHex6(null), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidHex6(''), isFalse);
    });

    test('rejects HEX without leading #', () {
      expect(isValidHex6('f97316'), isFalse);
    });

    test('rejects 3-digit short HEX', () {
      expect(isValidHex6('#fff'), isFalse);
    });

    test('rejects 8-digit ARGB HEX', () {
      // Backend column is varchar(7) RGB-only; ARGB must not pass.
      expect(isValidHex6('#FFf97316'), isFalse);
    });

    test('rejects non-hex characters', () {
      expect(isValidHex6('#zzzzzz'), isFalse);
    });

    test('rejects extra trailing whitespace', () {
      // Callers are expected to trim before calling — the regex itself
      // is anchored, so any surrounding noise must be rejected.
      expect(isValidHex6('#f97316 '), isFalse);
    });
  });

  group('colorToHex6', () {
    test('serializes a fully-opaque color without the alpha byte', () {
      final result = colorToHex6(const Color(0xFFF97316));
      expect(result, '#F97316');
    });

    test('strips alpha from a semi-transparent color', () {
      // flutter_colorpicker can return ARGB values where alpha != FF if
      // a downstream caller flips enableAlpha to true. We must never
      // forward those as 8-digit HEX into a varchar(7) column.
      final result = colorToHex6(const Color(0x80F97316));
      expect(result, '#F97316');
    });

    test('zero-pads short RGB values to 6 digits', () {
      // 0x000001 would otherwise serialize as '#1'.
      final result = colorToHex6(const Color(0xFF000001));
      expect(result, '#000001');
    });

    test('always emits uppercase output', () {
      final result = colorToHex6(const Color(0xFFabcdef));
      expect(result, '#ABCDEF');
    });
  });

  group('hex6ToColor', () {
    test('parses canonical lowercase HEX into an opaque color', () {
      final result = hex6ToColor('#f97316');
      expect(result, isNotNull);
      // Reconstructed color is always alpha=FF, RGB matches input.
      expect(colorToHex6(result!), '#F97316');
    });

    test('parses uppercase HEX', () {
      final result = hex6ToColor('#F97316');
      expect(result, isNotNull);
      expect(colorToHex6(result!), '#F97316');
    });

    test('returns null for invalid input', () {
      expect(hex6ToColor('not a color'), isNull);
      expect(hex6ToColor(''), isNull);
      expect(hex6ToColor(null), isNull);
      expect(hex6ToColor('#fff'), isNull);
    });

    test('round-trips colorToHex6 ↔ hex6ToColor for all preset values', () {
      const presets = [
        '#f97316',
        '#a78bfa',
        '#22d3ee',
        '#84cc16',
        '#ef4444',
        '#fbbf24',
        '#ec4899',
        '#14b8a6',
        '#8b5cf6',
        '#f43f5e',
      ];
      for (final hex in presets) {
        final color = hex6ToColor(hex);
        expect(color, isNotNull, reason: 'failed to parse $hex');
        expect(
          colorToHex6(color!).toLowerCase(),
          hex.toLowerCase(),
          reason: '$hex did not round-trip',
        );
      }
    });
  });
}
