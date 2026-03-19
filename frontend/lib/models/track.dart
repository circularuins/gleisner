import 'package:flutter/material.dart';

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

  Color get displayColor {
    try {
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF808080);
    }
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
