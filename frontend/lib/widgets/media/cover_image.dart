import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';

/// Displays a cover image: real image if URL is provided,
/// otherwise a generative cover (gradient + decorative circles).
class CoverImage extends StatelessWidget {
  final String? imageUrl;
  final String seed;
  final double height;
  final VoidCallback? onTap;

  const CoverImage({
    super.key,
    this.imageUrl,
    required this.seed,
    this.height = 200,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    final content = hasImage
        ? Image.network(
            imageUrl!,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => CustomPaint(
              size: Size(double.infinity, height),
              painter: _CoverPainter(seed: seed),
            ),
          )
        : CustomPaint(
            size: Size(double.infinity, height),
            painter: _CoverPainter(seed: seed),
          );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            content,
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: spaceSm,
                  vertical: spaceXs,
                ),
                decoration: BoxDecoration(
                  color: colorSurface0.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(radiusMd),
                  border: Border.all(color: colorBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt, size: 16, color: colorTextSecondary),
                    const SizedBox(width: spaceXs),
                    Text(
                      context.l10n.editCover,
                      style: const TextStyle(color: colorTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return content;
  }
}

/// Generative cover art: gradient + decorative circles based on username seed.
class _CoverPainter extends CustomPainter {
  final String seed;

  _CoverPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = DeterministicRng(seed);
    final hue = rng.next() * 360;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        HSLColor.fromAHSL(1.0, hue, 0.6, 0.15).toColor(),
        HSLColor.fromAHSL(1.0, (hue + 60) % 360, 0.4, 0.1).toColor(),
      ],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );

    for (int i = 0; i < 6; i++) {
      final cx = rng.next() * size.width;
      final cy = rng.next() * size.height;
      final r = 20.0 + rng.next() * 40;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = HSLColor.fromAHSL(
            0.08,
            (hue + rng.next() * 120) % 360,
            0.5,
            0.5,
          ).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_CoverPainter oldDelegate) => oldDelegate.seed != seed;
}
