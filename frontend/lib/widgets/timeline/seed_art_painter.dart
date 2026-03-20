import 'dart:math';

import 'package:flutter/material.dart';

import '../../utils/deterministic_rng.dart';

/// CustomPainter that generates deterministic abstract art from a seed string.
/// Port of the HTML mock's drawThumb() function.
class SeedArtPainter extends CustomPainter {
  final Color trackColor;
  final String seed;

  SeedArtPainter({required this.trackColor, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);
    final cr = (trackColor.r * 255.0).roundToDouble();
    final cg = (trackColor.g * 255.0).roundToDouble();
    final cb = (trackColor.b * 255.0).roundToDouble();

    // Dark background
    final bgPaint = Paint()
      ..color = Color.fromARGB(
        255,
        (12 + rng.next() * 8).toInt(),
        (12 + rng.next() * 8).toInt(),
        (16 + rng.next() * 8).toInt(),
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 4 radial gradients
    for (int i = 0; i < 4; i++) {
      final cx = size.width * (0.1 + rng.next() * 0.8);
      final cy = size.height * (0.1 + rng.next() * 0.8);
      final radius = size.width * (0.3 + rng.next() * 0.5);
      final alpha = 0.1 + rng.next() * 0.2;

      final gradient = RadialGradient(
        center: Alignment(
          (cx / size.width) * 2 - 1,
          (cy / size.height) * 2 - 1,
        ),
        radius: radius / size.width,
        colors: [
          trackColor.withValues(alpha: alpha),
          trackColor.withValues(alpha: 0),
        ],
      );

      final paint = Paint()..shader = gradient.createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, paint);
    }

    // 5–11 random ellipses
    final count = 5 + (rng.next() * 6).toInt();
    for (int i = 0; i < count; i++) {
      final alpha = 0.03 + rng.next() * 0.08;
      final r = (cr + rng.next() * 40 - 20).clamp(0, 255).toInt();
      final g = (cg + rng.next() * 40 - 20).clamp(0, 255).toInt();
      final b = (cb + rng.next() * 40 - 20).clamp(0, 255).toInt();

      final x = rng.next() * size.width;
      final y = rng.next() * size.height;
      final rotation = rng.next() * pi * 2;
      final s = 8 + rng.next() * 40;
      final ratio = 0.4 + rng.next() * 0.6;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final paint = Paint()
        ..color = Color.fromARGB((alpha * 255).toInt(), r, g, b);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: s * 2,
          height: s * ratio * 2,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SeedArtPainter oldDelegate) =>
      trackColor != oldDelegate.trackColor || seed != oldDelegate.seed;
}

/// Widget wrapper for SeedArtPainter.
class SeedArtCanvas extends StatelessWidget {
  final double width;
  final double height;
  final Color trackColor;
  final String seed;

  const SeedArtCanvas({
    super.key,
    required this.width,
    required this.height,
    required this.trackColor,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: SeedArtPainter(trackColor: trackColor, seed: seed),
      ),
    );
  }
}
