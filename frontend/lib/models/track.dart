import 'package:flutter/material.dart';

import '../theme/gleisner_tokens.dart';

const fallbackTrackColor = colorTrackFallback;

/// Parse a hex color string (e.g. "#ff5500" or "ff5500") to a Color.
Color parseHexColor(String? hex, {Color fallback = fallbackTrackColor}) {
  if (hex == null) return fallback;
  try {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;
    return Color(int.parse('FF$cleaned', radix: 16));
  } catch (_) {
    return fallback;
  }
}

class Track {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;

  const Track({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  Color get displayColor => parseHexColor(color);

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
