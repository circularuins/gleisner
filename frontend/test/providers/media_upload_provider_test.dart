import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/providers/media_upload_provider.dart';

void main() {
  group('mimeFromBytes', () {
    test('detects JPEG from magic bytes', () {
      final bytes = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, // JPEG magic + JFIF marker
        0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      ]);
      expect(mimeFromBytes(bytes), 'image/jpeg');
    });

    test('detects PNG from magic bytes', () {
      final bytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, // PNG magic
        0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      ]);
      expect(mimeFromBytes(bytes), 'image/png');
    });

    test('detects WebP from magic bytes', () {
      final bytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // "RIFF"
        0x00, 0x00, 0x00, 0x00, // file size (placeholder)
        0x57, 0x45, 0x42, 0x50, // "WEBP"
      ]);
      expect(mimeFromBytes(bytes), 'image/webp');
    });

    test('detects GIF from magic bytes', () {
      final bytes = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, // "GIF8"
        0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00,
      ]);
      expect(mimeFromBytes(bytes), 'image/gif');
    });

    test('returns null for unknown format', () {
      final bytes = Uint8List.fromList([
        0x25, 0x50, 0x44, 0x46, // PDF magic "%PDF"
        0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25, 0xE2, 0xE3,
      ]);
      expect(mimeFromBytes(bytes), null);
    });

    test('returns null for too-short data', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8]);
      expect(mimeFromBytes(bytes), null);
    });

    test('returns null for empty data', () {
      final bytes = Uint8List.fromList([]);
      expect(mimeFromBytes(bytes), null);
    });

    test('detects MP4 video from ftyp box', () {
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x1C, // box size
        0x66, 0x74, 0x79, 0x70, // "ftyp"
        0x69, 0x73, 0x6F, 0x6D, // "isom" brand
      ]);
      expect(mimeFromBytes(bytes), 'video/mp4');
    });

    test('detects M4A audio from ftyp box', () {
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x20, // box size
        0x66, 0x74, 0x79, 0x70, // "ftyp"
        0x4D, 0x34, 0x41, 0x20, // "M4A " brand
      ]);
      expect(mimeFromBytes(bytes), 'audio/mp4');
    });

    // ADR 025 / #146: iOS captures produce HEIC/HEIF with an `ftyp` box, so
    // without brand checks they would be mis-detected as video/mp4. Verify
    // each ISO 14496-12 / ISO 23008-12 image brand resolves to image/heic:
    //   still images:   heic, heif, heix, mif1, heis
    //   image sequence: msf1 (HEIF Image Sequence — bursts / Live Photos)
    // hevc / hevx (HEVC video sequences) are intentionally excluded and
    // covered by the regression test below.
    const heicBrands = <String>['heic', 'heif', 'heix', 'mif1', 'msf1', 'heis'];
    for (final brand in heicBrands) {
      test('detects HEIC/HEIF from ftyp brand "$brand"', () {
        final brandBytes = brand.codeUnits;
        final bytes = Uint8List.fromList([
          0x00, 0x00, 0x00, 0x18, // box size
          0x66, 0x74, 0x79, 0x70, // "ftyp"
          brandBytes[0], brandBytes[1], brandBytes[2], brandBytes[3],
        ]);
        expect(mimeFromBytes(bytes), 'image/heic');
      });
    }

    test('ftyp brand "mp41" still maps to video/mp4 (not HEIC)', () {
      // Regression guard: HEIC brand check must not accidentally swallow
      // non-HEIC ftyp brands commonly used by MP4 containers.
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, // box size
        0x66, 0x74, 0x79, 0x70, // "ftyp"
        0x6D, 0x70, 0x34, 0x31, // "mp41" brand
      ]);
      expect(mimeFromBytes(bytes), 'video/mp4');
    });

    test('ftyp brand "hevc" stays on video/mp4 (HEVC video sequence)', () {
      // hevc/hevx carry HEVC video sequences (ISO 23008-12), not still
      // images. They must not be treated as HEIC.
      final bytes = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x18, // box size
        0x66, 0x74, 0x79, 0x70, // "ftyp"
        0x68, 0x65, 0x76, 0x63, // "hevc" brand
      ]);
      expect(mimeFromBytes(bytes), 'video/mp4');
    });

    test('detects MP3 from ID3 header', () {
      final bytes = Uint8List.fromList([
        0x49, 0x44, 0x33, 0x03, // "ID3" + version
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);
      expect(mimeFromBytes(bytes), 'audio/mpeg');
    });

    test('detects Ogg audio', () {
      final bytes = Uint8List.fromList([
        0x4F, 0x67, 0x67, 0x53, // "OggS"
        0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]);
      expect(mimeFromBytes(bytes), 'audio/ogg');
    });

    test('detects WebM video', () {
      final bytes = Uint8List.fromList([
        0x1A, 0x45, 0xDF, 0xA3, // EBML header
        0x93, 0x42, 0x82, 0x88, 0x6D, 0x61, 0x74, 0x72,
      ]);
      expect(mimeFromBytes(bytes), 'video/webm');
    });

    test('rejects RIFF without WEBP signature', () {
      final bytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // "RIFF"
        0x00, 0x00, 0x00, 0x00,
        0x41, 0x56, 0x49, 0x20, // "AVI " (not WEBP)
      ]);
      expect(mimeFromBytes(bytes), null);
    });

    test('rejects executable disguised with wrong extension', () {
      // MZ header (Windows executable)
      final bytes = Uint8List.fromList([
        0x4D,
        0x5A,
        0x90,
        0x00,
        0x03,
        0x00,
        0x00,
        0x00,
        0x04,
        0x00,
        0x00,
        0x00,
      ]);
      expect(mimeFromBytes(bytes), null);
    });
  });

  group('MediaUploadNotifier URL validation', () {
    test('_isAllowedUploadUrl accepts R2 storage URLs', () {
      expect(
        MediaUploadNotifier.isAllowedUploadUrl(
          'https://account.r2.cloudflarestorage.com/bucket/key?signature=abc',
        ),
        true,
      );
    });

    test('_isAllowedUploadUrl rejects non-R2 URLs', () {
      expect(
        MediaUploadNotifier.isAllowedUploadUrl('https://evil.com/steal-data'),
        false,
      );
    });

    test('_isAllowedUploadUrl rejects HTTP URLs', () {
      expect(
        MediaUploadNotifier.isAllowedUploadUrl(
          'http://account.r2.cloudflarestorage.com/bucket/key',
        ),
        false,
      );
    });

    test('_isAllowedPublicUrl accepts gleisner.app domain', () {
      expect(
        MediaUploadNotifier.isAllowedPublicUrl(
          'https://media-dev.gleisner.app/avatars/user/file.jpg',
        ),
        true,
      );
    });

    test('_isAllowedPublicUrl accepts r2.dev domain', () {
      expect(
        MediaUploadNotifier.isAllowedPublicUrl(
          'https://pub-abc123.r2.dev/avatars/user/file.jpg',
        ),
        true,
      );
    });

    test('_isAllowedPublicUrl rejects HTTP URLs', () {
      expect(
        MediaUploadNotifier.isAllowedPublicUrl(
          'http://media-dev.gleisner.app/avatars/user/file.jpg',
        ),
        false,
      );
    });

    test('_isAllowedPublicUrl rejects arbitrary domains', () {
      expect(
        MediaUploadNotifier.isAllowedPublicUrl(
          'https://attacker.com/malware.jpg',
        ),
        false,
      );
    });
  });
}
