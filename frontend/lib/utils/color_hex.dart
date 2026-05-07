import 'package:flutter/material.dart';

/// Validates a `#RRGGBB` HEX string. Mirrors the backend regex in
/// `backend/src/graphql/types/track.ts` so the client rejects bad input
/// before sending the mutation.
final hexColor6Regex = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Whether [value] is a valid `#RRGGBB` HEX color (6 hex digits, leading `#`).
/// Alpha-prefixed `#AARRGGBB` is intentionally rejected — Track.color is
/// stored as `varchar(7)` in the DB and the regex enforces the same shape
/// on both ends.
bool isValidHex6(String? value) =>
    value != null && hexColor6Regex.hasMatch(value);

/// Converts a [Color] to a 6-digit `#RRGGBB` string, dropping the alpha
/// channel.
///
/// `flutter_colorpicker` returns ARGB-encoded `Color` values
/// (`0xAARRGGBB`). Track.color is RGB-only, so masking off the alpha
/// byte is required to match the backend regex `/^#[0-9A-Fa-f]{6}$/`
/// and the `varchar(7)` column shape.
String colorToHex6(Color color) {
  // `toARGB32()` returns the 32-bit ARGB representation. Masking with
  // 0xFFFFFF drops the alpha byte so a fully opaque color does not
  // become `#FF...` and an inadvertently semi-transparent picker
  // output does not truncate into a different RGB value.
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';
}

/// Parses a `#RRGGBB` string into an opaque [Color]. Returns `null` for
/// invalid input rather than throwing — callers typically want to fall
/// back to a default presentation color (e.g. [colorTrackFallback]).
Color? hex6ToColor(String? value) {
  if (!isValidHex6(value)) return null;
  final rgb = int.parse(value!.substring(1), radix: 16);
  return Color(0xFF000000 | rgb);
}
