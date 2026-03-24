import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/post.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';

/// CustomPainter that generates deterministic art from a seed string.
/// Renders different visual styles based on media type.
class SeedArtPainter extends CustomPainter {
  final Color trackColor;
  final String seed;
  final MediaType? mediaType;

  SeedArtPainter({
    required this.trackColor,
    required this.seed,
    this.mediaType,
  });

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

  /// Image: warm, photo-like layered gradients with complementary accent color
  void _paintImageStyle(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);

    // Warm dark background
    final bgPaint = Paint()
      ..color = Color.fromARGB(
        255,
        (15 + rng.next() * 10).toInt(),
        (12 + rng.next() * 8).toInt(),
        (10 + rng.next() * 6).toInt(),
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Complementary accent: shift hue by ~120 degrees via RGB rotation
    final accent = _shiftHue(trackColor, rng.next() * 0.4 + 0.2);

    // Large soft shapes with mixed colors
    for (int i = 0; i < 3; i++) {
      final cx = size.width * (0.1 + rng.next() * 0.8);
      final cy = size.height * (0.1 + rng.next() * 0.8);
      final radius = size.width * (0.4 + rng.next() * 0.4);
      final useAccent = i == 1;
      final color = useAccent ? accent : trackColor;

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
      final color = i % 3 == 0 ? accent : trackColor;
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

    // Very dark background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080810),
    );

    // Subtle ambient light
    final accent = _shiftHue(trackColor, 0.3);
    for (int i = 0; i < 2; i++) {
      final cx = size.width * (0.2 + rng.next() * 0.6);
      final cy = size.height * (0.3 + rng.next() * 0.4);
      final color = i == 0 ? trackColor : accent;
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
      colors: [
        trackColor.withValues(alpha: 0.2),
        trackColor.withValues(alpha: 0),
      ],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = flareGradient.createShader(Offset.zero & size),
    );
  }

  /// Audio: dark with horizontal wave lines
  void _paintAudioStyle(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);

    canvas.drawRect(Offset.zero & size, Paint()..color = colorSurface1);

    // Subtle gradient base
    final accent = _shiftHue(trackColor, 0.15);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        trackColor.withValues(alpha: 0.06),
        accent.withValues(alpha: 0.04),
      ],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );

    // Horizontal wave lines
    final lineCount = 8 + (rng.next() * 6).toInt();
    for (int i = 0; i < lineCount; i++) {
      final y = size.height * (0.1 + (i / lineCount) * 0.8);
      final amplitude = 2 + rng.next() * 8;
      final alpha = 0.06 + rng.next() * 0.1;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x < size.width; x += 4) {
        final dy =
            sin((x / size.width) * pi * (2 + rng.next() * 4) + i) * amplitude;
        path.lineTo(x, y + dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = trackColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  /// Default: abstract ellipses (for text, link, or unknown)
  void _paintDefaultStyle(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);

    // Dark background
    final bgPaint = Paint()
      ..color = Color.fromARGB(
        255,
        (12 + rng.next() * 8).toInt(),
        (12 + rng.next() * 8).toInt(),
        (16 + rng.next() * 8).toInt(),
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Radial gradients with accent variation
    final accent = _shiftHue(trackColor, 0.25);
    for (int i = 0; i < 4; i++) {
      final cx = size.width * (0.1 + rng.next() * 0.8);
      final cy = size.height * (0.1 + rng.next() * 0.8);
      final radius = size.width * (0.3 + rng.next() * 0.5);
      final alpha = 0.1 + rng.next() * 0.2;
      final color = i == 2 ? accent : trackColor;

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
      final useAccent = i % 3 == 0;
      final baseColor = useAccent ? accent : trackColor;
      final alpha = 0.03 + rng.next() * 0.08;
      final r =
          ((useAccent ? baseColor.r : trackColor.r) * 255.0 +
                  rng.next() * 40 -
                  20)
              .clamp(0, 255)
              .toInt();
      final g =
          ((useAccent ? baseColor.g : trackColor.g) * 255.0 +
                  rng.next() * 40 -
                  20)
              .clamp(0, 255)
              .toInt();
      final b =
          ((useAccent ? baseColor.b : trackColor.b) * 255.0 +
                  rng.next() * 40 -
                  20)
              .clamp(0, 255)
              .toInt();

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
        Paint()..color = Color.fromARGB((alpha * 255).toInt(), r, g, b),
      );
      canvas.restore();
    }
  }

  /// Shift a color's hue by rotating RGB channels with a blend factor.
  static Color _shiftHue(Color color, double amount) {
    final r = color.r;
    final g = color.g;
    final b = color.b;
    // Simple channel rotation blend for hue shift effect
    return Color.fromARGB(
      255,
      ((r * (1 - amount) + b * amount) * 255).round().clamp(0, 255),
      ((g * (1 - amount) + r * amount) * 255).round().clamp(0, 255),
      ((b * (1 - amount) + g * amount) * 255).round().clamp(0, 255),
    );
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
