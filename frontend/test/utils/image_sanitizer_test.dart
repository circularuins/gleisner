import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/utils/image_sanitizer.dart';

void main() {
  // Note: flutter test runs on Chrome (kIsWeb == true). The Web Canvas
  // re-encode path cannot be exercised with synthetic byte arrays — Canvas
  // needs a decodable image. Actual EXIF stripping is verified manually
  // with exiftool (see PR description). Here we test the metadata
  // detection helpers and GIF-rejection logic, which are platform-agnostic.

  group('sanitizeImageMetadata rejection paths (platform-agnostic)', () {
    test('rejects unsupported contentType', () async {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      final result = await sanitizeImageMetadata(
        bytes,
        contentType: 'image/svg+xml',
      );
      expect(result, isNull);
    });

    test('rejects GIF with Application Extension', () async {
      final bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"
        0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, // LSD
        0x21, 0xFF, 0x0B, // Application Extension
      ]);
      final result = await sanitizeImageMetadata(
        bytes,
        contentType: 'image/gif',
      );
      expect(result, isNull);
    });

    test('accepts GIF without metadata blocks', () async {
      final bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"
        0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, // LSD
        0x2C, 0x00, 0x00, // image descriptor start
      ]);
      final result = await sanitizeImageMetadata(
        bytes,
        contentType: 'image/gif',
      );
      expect(result, isNotNull);
      expect(result!.bytes, equals(bytes));
      expect(result.contentType, 'image/gif');
    });
  });

  group('gifContainsMetadataBlocks', () {
    Uint8List gifHeader() {
      // "GIF89a" (6) + logical screen descriptor (7) = 13 bytes
      return Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, // "GIF89a"
        0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, // LSD
      ]);
    }

    test('returns false for GIF without extension blocks', () {
      final bytes = Uint8List.fromList([
        ...gifHeader(),
        0x2C, 0x00, 0x00, // image descriptor start
      ]);
      expect(gifContainsMetadataBlocks(bytes), false);
    });

    test('detects Application Extension (0x21 0xFF)', () {
      final bytes = Uint8List.fromList([
        ...gifHeader(),
        0x21, 0xFF, 0x0B, // Application Extension marker
      ]);
      expect(gifContainsMetadataBlocks(bytes), true);
    });

    test('detects Comment Extension (0x21 0xFE)', () {
      final bytes = Uint8List.fromList([
        ...gifHeader(),
        0x21, 0xFE, 0x04, // Comment Extension marker
      ]);
      expect(gifContainsMetadataBlocks(bytes), true);
    });

    test('ignores Graphic Control Extension (0x21 0xF9)', () {
      // 0xF9 is standard animation timing, not metadata
      final bytes = Uint8List.fromList([
        ...gifHeader(),
        0x21, 0xF9, 0x04, // GCE — animation only
      ]);
      expect(gifContainsMetadataBlocks(bytes), false);
    });

    test('returns false for too-short GIF', () {
      final bytes = Uint8List.fromList([0x47, 0x49, 0x46]);
      expect(gifContainsMetadataBlocks(bytes), false);
    });
  });

  group('containsMetadataMarkers', () {
    Uint8List withPrefix(List<int> markerBytes) {
      final prefix = [0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x20];
      return Uint8List.fromList([...prefix, ...markerBytes]);
    }

    test('detects EXIF APP1 marker (Exif + 2 NUL bytes)', () {
      // "Exif" + 0x00 0x00 + "MM" (big-endian TIFF start)
      final exifMarker = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0x4D, 0x4D];
      expect(containsMetadataMarkers(withPrefix(exifMarker)), true);
    });

    test('detects XMP namespace URI', () {
      final bytes = withPrefix('http://ns.adobe.com/xap/1.0/'.codeUnits);
      expect(containsMetadataMarkers(bytes), true);
    });

    test('detects GPSLatitude marker', () {
      final bytes = withPrefix(
        '<exif:GPSLatitude>35.6</exif:GPSLatitude>'.codeUnits,
      );
      expect(containsMetadataMarkers(bytes), true);
    });

    test('detects GPSLongitude marker', () {
      final bytes = withPrefix(
        '<exif:GPSLongitude>139.7</exif:GPSLongitude>'.codeUnits,
      );
      expect(containsMetadataMarkers(bytes), true);
    });

    test('returns false for clean JPEG bytes', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, // SOI + DQT
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06,
      ]);
      expect(containsMetadataMarkers(bytes), false);
    });
  });
}
