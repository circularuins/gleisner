import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';
import '../../utils/deterministic_rng.dart';

/// Displays a user/artist avatar: real image if URL is provided,
/// otherwise a generative avatar (colored circle with initial).
class AvatarImage extends StatelessWidget {
  final String? imageUrl;
  final String seed;
  final double size;
  final VoidCallback? onTap;

  const AvatarImage({
    super.key,
    this.imageUrl,
    required this.seed,
    this.size = 48,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final widget = imageUrl != null && imageUrl!.isNotEmpty
        ? ClipOval(
            child: Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _GenerativeFallback(seed: seed, size: size),
            ),
          )
        : _GenerativeFallback(seed: seed, size: size);

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            widget,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorSurface1,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorBorder, width: 1.5),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: size * 0.2,
                  color: colorTextSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return widget;
  }
}

class _GenerativeFallback extends StatelessWidget {
  final String seed;
  final double size;

  const _GenerativeFallback({required this.seed, required this.size});

  @override
  Widget build(BuildContext context) {
    final rng = DeterministicRng(seed);
    final hue = rng.next() * 360;
    final color = HSLColor.fromAHSL(1.0, hue, 0.5, 0.3).toColor();
    final initial = seed.isNotEmpty ? seed[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
