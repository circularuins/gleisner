import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';

/// A thumbnail tile for an uploaded image with a remove button.
class ImageTile extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;

  const ImageTile({super.key, required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radiusMd),
            child: Image.network(
              url,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              cacheWidth: 200,
              errorBuilder: (_, _, _) => Container(
                color: colorSurface2,
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: colorTextMuted,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tile with a "+" icon to add more images.
class AddImageTile extends StatelessWidget {
  final VoidCallback onTap;

  const AddImageTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: colorSurface2,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: colorBorder),
        ),
        child: const Center(
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: colorInteractive,
          ),
        ),
      ),
    );
  }
}

/// A circular arrow button for carousel navigation.
class CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double padding;

  const CarouselArrow({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 24,
    this.padding = spaceXs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
