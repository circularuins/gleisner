import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';

/// A spotlight overlay that highlights a target widget and shows a tooltip.
/// Uses CompositedTransformFollower for pixel-perfect alignment with the target.
class TutorialSpotlight extends StatefulWidget {
  final bool visible;
  final VoidCallback onDismiss;
  final String message;
  final String? subtitle;

  /// LayerLink connected to the target via CompositedTransformTarget.
  final LayerLink link;

  /// Size of the target widget.
  final Size targetSize;

  const TutorialSpotlight({
    super.key,
    required this.visible,
    required this.onDismiss,
    required this.message,
    this.subtitle,
    required this.link,
    this.targetSize = const Size(56, 56),
  });

  @override
  State<TutorialSpotlight> createState() => _TutorialSpotlightState();
}

class _TutorialSpotlightState extends State<TutorialSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Semi-transparent backdrop (no cutout — simple approach)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return ColoredBox(
                  color: const Color(0xCC000000),
                );
              },
            ),
          ),

          // Glow ring following the target
          CompositedTransformFollower(
            link: widget.link,
            offset: Offset(
              -12, // padding around target
              -12,
            ),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final v = _pulse.value;
                final size = widget.targetSize.width + 24;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorAccentGold.withValues(alpha: 0.3 + v * 0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorAccentGold.withValues(alpha: 0.2 + v * 0.15),
                        blurRadius: 16 + v * 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Tooltip above the target, aligned to right edge
          CompositedTransformFollower(
            link: widget.link,
            offset: Offset(
              -(280 - widget.targetSize.width), // right-align tooltip with target
              -170, // above the target
            ),
            child: _Tooltip(
              message: widget.message,
              subtitle: widget.subtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tooltip extends StatelessWidget {
  final String message;
  final String? subtitle;

  const _Tooltip({required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(spaceLg),
      decoration: BoxDecoration(
        color: colorSurface1,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(
          color: colorAccentGold.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: colorAccentGold.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: colorTextPrimary,
              fontSize: fontSizeMd,
              fontWeight: weightSemibold,
              height: 1.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: spaceXs),
            Text(
              subtitle!,
              style: const TextStyle(
                color: colorTextMuted,
                fontSize: fontSizeSm,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: spaceSm),
          Text(
            'Tap anywhere to continue',
            style: TextStyle(
              color: colorAccentGold.withValues(alpha: 0.6),
              fontSize: fontSizeXs,
            ),
          ),
        ],
      ),
    );
  }
}
