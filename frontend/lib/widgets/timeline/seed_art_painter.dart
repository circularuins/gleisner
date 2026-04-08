import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';

/// CustomPainter that generates deterministic art from a seed string.
/// Renders different visual styles based on media type.
/// Colors are derived from the seed (not track color) to simulate
/// the visual variety of real uploaded media.
class SeedArtPainter extends CustomPainter {
  final Color trackColor;
  final String seed;
  final MediaType? mediaType;

  SeedArtPainter({
    required this.trackColor,
    required this.seed,
    this.mediaType,
  });

  /// Generate a deterministic color from the RNG, independent of track color.
  static Color _seedColor(DeterministicRng rng) {
    // HSL with constrained saturation/lightness for pleasant dark-theme colors
    final hue = rng.next() * 360;
    final sat = 0.3 + rng.next() * 0.5; // 30-80% saturation
    final light = 0.25 + rng.next() * 0.3; // 25-55% lightness
    return HSLColor.fromAHSL(1.0, hue, sat, light).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (mediaType) {
      case MediaType.image:
        _paintImageStyle(canvas, size);
      case MediaType.video:
        _paintVideoStyle(canvas, size);
      case MediaType.audio:
        _paintAudioStyle(canvas, size);
      default:
        _paintDefaultStyle(canvas, size);
    }
  }

  /// Image: warm, photo-like layered gradients with seed-derived colors
  void _paintImageStyle(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);
    final primary = _seedColor(rng);
    final secondary = _seedColor(rng);

    // Warm dark background
    final bgPaint = Paint()
      ..color = Color.fromARGB(
        255,
        (15 + rng.next() * 10).toInt(),
        (12 + rng.next() * 8).toInt(),
        (10 + rng.next() * 6).toInt(),
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Large soft shapes with mixed colors
    for (int i = 0; i < 3; i++) {
      final cx = size.width * (0.1 + rng.next() * 0.8);
      final cy = size.height * (0.1 + rng.next() * 0.8);
      final radius = size.width * (0.4 + rng.next() * 0.4);
      final color = i == 1 ? secondary : primary;

      final gradient = RadialGradient(
        center: Alignment(
          (cx / size.width) * 2 - 1,
          (cy / size.height) * 2 - 1,
        ),
        radius: radius / size.width,
        colors: [
          color.withValues(alpha: 0.15 + rng.next() * 0.1),
          color.withValues(alpha: 0),
        ],
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = gradient.createShader(Offset.zero & size),
      );
    }

    // Scattered warm particles (photo grain feel)
    final count = 6 + (rng.next() * 8).toInt();
    for (int i = 0; i < count; i++) {
      final color = i % 3 == 0 ? secondary : primary;
      final alpha = 0.04 + rng.next() * 0.08;
      final x = rng.next() * size.width;
      final y = rng.next() * size.height;
      final s = 4 + rng.next() * 25;
      canvas.drawCircle(
        Offset(x, y),
        s,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  /// Video: cinematic dark tone with letterbox bars and lens flare
  void _paintVideoStyle(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);
    final primary = _seedColor(rng);
    final secondary = _seedColor(rng);

    // Very dark background
    canvas.drawRect(Offset.zero & size, Paint()..color = colorSurface0);

    // Subtle ambient light
    for (int i = 0; i < 2; i++) {
      final cx = size.width * (0.2 + rng.next() * 0.6);
      final cy = size.height * (0.3 + rng.next() * 0.4);
      final color = i == 0 ? primary : secondary;
      final gradient = RadialGradient(
        center: Alignment(
          (cx / size.width) * 2 - 1,
          (cy / size.height) * 2 - 1,
        ),
        radius: 0.6 + rng.next() * 0.3,
        colors: [
          color.withValues(alpha: 0.08 + rng.next() * 0.06),
          color.withValues(alpha: 0),
        ],
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = gradient.createShader(Offset.zero & size),
      );
    }

    // Letterbox bars (cinematic aspect)
    final barHeight = size.height * (0.08 + rng.next() * 0.04);
    final barPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, barHeight), barPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - barHeight, size.width, barHeight),
      barPaint,
    );

    // Lens flare
    final flareX = size.width * (0.3 + rng.next() * 0.4);
    final flareY = size.height * (0.3 + rng.next() * 0.4);
    final flareGradient = RadialGradient(
      center: Alignment(
        (flareX / size.width) * 2 - 1,
        (flareY / size.height) * 2 - 1,
      ),
      radius: 0.15,
      colors: [primary.withValues(alpha: 0.2), primary.withValues(alpha: 0)],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = flareGradient.createShader(Offset.zero & size),
    );
  }

  /// Audio: dark with horizontal wave lines
  void _paintAudioStyle(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);
    final primary = _seedColor(rng);
    final secondary = _seedColor(rng);

    // Dark background
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Color.fromARGB(
          255,
          (10 + rng.next() * 8).toInt(),
          (8 + rng.next() * 6).toInt(),
          (14 + rng.next() * 10).toInt(),
        ),
    );

    // Soft radial glow — gives depth like a vinyl record under stage light
    for (int i = 0; i < 2; i++) {
      final cx = size.width * (0.3 + rng.next() * 0.4);
      final cy = size.height * (0.3 + rng.next() * 0.4);
      final color = i == 0 ? primary : secondary;
      final gradient = RadialGradient(
        center: Alignment(
          (cx / size.width) * 2 - 1,
          (cy / size.height) * 2 - 1,
        ),
        radius: 0.8 + rng.next() * 0.4,
        colors: [
          color.withValues(alpha: 0.18 + rng.next() * 0.08),
          color.withValues(alpha: 0),
        ],
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = gradient.createShader(Offset.zero & size),
      );
    }

    // Broad, smooth wave lines — like sound waves / EQ curves
    final lineCount = 3 + (rng.next() * 2).toInt();
    for (int i = 0; i < lineCount; i++) {
      final y = size.height * (0.25 + (i / lineCount) * 0.5);
      final amplitude = 12 + rng.next() * 20;
      final frequency = 1.0 + rng.next() * 1.5;
      final phase = rng.next() * pi * 2;
      final alpha = 0.12 + rng.next() * 0.12;
      final width = 1.5 + rng.next() * 1.5;
      final color = i.isEven ? primary : secondary;

      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 2) {
        final t = x / size.width;
        final dy = sin(t * pi * 2 * frequency + phase) * amplitude;
        path.lineTo(x, y + dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Default: abstract ellipses (for text, link, or unknown)
  void _paintDefaultStyle(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);
    final primary = _seedColor(rng);
    final secondary = _seedColor(rng);

    // Dark background
    final bgPaint = Paint()
      ..color = Color.fromARGB(
        255,
        (12 + rng.next() * 8).toInt(),
        (12 + rng.next() * 8).toInt(),
        (16 + rng.next() * 8).toInt(),
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Radial gradients
    for (int i = 0; i < 4; i++) {
      final cx = size.width * (0.1 + rng.next() * 0.8);
      final cy = size.height * (0.1 + rng.next() * 0.8);
      final radius = size.width * (0.3 + rng.next() * 0.5);
      final alpha = 0.1 + rng.next() * 0.2;
      final color = i == 2 ? secondary : primary;

      final gradient = RadialGradient(
        center: Alignment(
          (cx / size.width) * 2 - 1,
          (cy / size.height) * 2 - 1,
        ),
        radius: radius / size.width,
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      );
      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = gradient.createShader(Offset.zero & size),
      );
    }

    // Ellipses with color variation
    final count = 5 + (rng.next() * 6).toInt();
    for (int i = 0; i < count; i++) {
      final color = i % 3 == 0 ? secondary : primary;
      final alpha = 0.03 + rng.next() * 0.08;

      final x = rng.next() * size.width;
      final y = rng.next() * size.height;
      final rotation = rng.next() * pi * 2;
      final s = 8 + rng.next() * 40;
      final ratio = 0.4 + rng.next() * 0.6;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: s * 2,
          height: s * ratio * 2,
        ),
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SeedArtPainter oldDelegate) =>
      trackColor != oldDelegate.trackColor ||
      seed != oldDelegate.seed ||
      mediaType != oldDelegate.mediaType;
}

/// Widget wrapper for SeedArtPainter.
class SeedArtCanvas extends StatelessWidget {
  final double width;
  final double height;
  final Color trackColor;
  final String seed;
  final MediaType? mediaType;

  const SeedArtCanvas({
    super.key,
    required this.width,
    required this.height,
    required this.trackColor,
    required this.seed,
    this.mediaType,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: SeedArtPainter(
          trackColor: trackColor,
          seed: seed,
          mediaType: mediaType,
        ),
      ),
    );
  }
}
