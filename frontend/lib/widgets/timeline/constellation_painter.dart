import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';
import '../../utils/constellation_layout.dart';

/// Paints the background layer: date spine line + synapse connections.
///
/// A continuous animation sends glowing dots along visible synapses.
/// Dot count, direction, and motion style vary by connection type:
///
/// - **reference** (1 dot): steady flow source→target — a quiet pointer.
/// - **evolution** (2 dots): ease-in acceleration — growth picking up speed.
/// - **remix** (3–4 dots): bidirectional flow — material mixing back and forth.
/// - **reply** (2–3 dots): pulsing alpha — rhythmic call-and-response.
class ConstellationPainter extends CustomPainter {
  final LayoutResult layout;
  final Set<String>? constellationPostIds;

  /// Raw animation value (0.0–1.0), repeating.
  final double animationValue;

  /// How many connections animate simultaneously.
  final int simultaneousDots;

  /// Scroll offset and viewport height — restrict animation to visible area.
  final double scrollOffset;
  final double viewportHeight;

  ConstellationPainter({
    required this.layout,
    this.constellationPostIds,
    this.animationValue = 0.0,
    this.simultaneousDots = 3,
    this.scrollOffset = 0,
    this.viewportHeight = double.infinity,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawSpineLine(canvas, size);
    _drawSynapses(canvas);
  }

  void _drawSpineLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorBorder
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(18, 0), Offset(18, size.height), paint);
  }

  // ── Testable static helpers ─────────────────────────────────────

  /// Evaluate a cubic bezier at parameter [t].
  @visibleForTesting
  static Offset bezierAt(
          double t, Offset p0, Offset p1, Offset p2, Offset p3) {
    final u = 1 - t;
    final uu = u * u;
    final uuu = uu * u;
    final tt = t * t;
    final ttt = tt * t;
    return p0 * uuu + p1 * (3 * uu * t) + p2 * (3 * u * tt) + p3 * ttt;
  }

  /// Whether a synapse overlaps the visible viewport (with margin).
  @visibleForTesting
  static bool isInViewport(
    SynapseConnection conn, {
    required double scrollOffset,
    required double viewportHeight,
    double margin = 100.0,
  }) {
    if (viewportHeight == double.infinity) return true;
    final top = scrollOffset - margin;
    final bottom = scrollOffset + viewportHeight + margin;
    final minY = conn.start.dy < conn.end.dy ? conn.start.dy : conn.end.dy;
    final maxY = conn.start.dy > conn.end.dy ? conn.start.dy : conn.end.dy;
    return maxY >= top && minY <= bottom;
  }

  // ── Connection-type dot configuration ──────────────────────────

  /// Number of dots travelling along a connection.
  @visibleForTesting
  static int dotCount(String type) => switch (type) {
        'reference' => 1,
        'evolution' => 2,
        'remix' => 4,
        'reply' => 3,
        _ => 1,
      };

  /// Apply easing per type. Returns adjusted progress (0–1).
  @visibleForTesting
  static double applyEasing(String type, double t) => switch (type) {
        // evolution: ease-in — slow start, accelerating finish
        'evolution' => t * t,
        _ => t,
      };

  /// Alpha multiplier for pulsing (reply type).
  @visibleForTesting
  static double pulseAlpha(String type, double t) => switch (type) {
        // reply: sinusoidal pulse — 0.5–1.0 oscillation
        'reply' => 0.5 + 0.5 * sin(t * pi * 4),
        _ => 1.0,
      };

  /// Whether this type has dots flowing in both directions.
  @visibleForTesting
  static bool isBidirectional(String type) => type == 'remix';

  // ────────────────────────────────────────────────────────────────

  void _drawSynapses(Canvas canvas) {
    const sw = ConstellationLayout.spineWidth;
    final filter = constellationPostIds;

    // Build list of filtered connections
    final allVisible = <SynapseConnection>[];
    for (final conn in layout.connections) {
      if (filter != null &&
          (!filter.contains(conn.sourcePostId) ||
              !filter.contains(conn.targetPostId))) {
        continue;
      }
      allVisible.add(conn);
    }

    // Draw all synapse lines
    for (final conn in allVisible) {
      final startColor = conn.color.withValues(alpha: conn.opacity);
      final endColor = conn.endColor.withValues(alpha: conn.opacity);

      final paint = Paint()
        ..strokeWidth = conn.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..shader = ui.Gradient.linear(
          Offset(conn.start.dx + sw, conn.start.dy),
          Offset(conn.end.dx + sw, conn.end.dy),
          [startColor, endColor],
        );

      final path = Path()
        ..moveTo(conn.start.dx + sw, conn.start.dy)
        ..cubicTo(
          conn.cp1.dx + sw,
          conn.cp1.dy,
          conn.cp2.dx + sw,
          conn.cp2.dy,
          conn.end.dx + sw,
          conn.end.dy,
        );
      canvas.drawPath(path, paint);
    }

    // Animate dots on viewport-visible connections
    final animatable =
        allVisible.where((c) => isInViewport(c, scrollOffset: scrollOffset, viewportHeight: viewportHeight)).toList(growable: false);
    if (animatable.isEmpty) return;

    final activeCount = simultaneousDots < animatable.length
        ? simultaneousDots
        : animatable.length;
    for (var i = 0; i < activeCount; i++) {
      final phase = (animationValue + i / activeCount) % 1.0;
      final totalSlots = animatable.length;
      final scaled = phase * totalSlots;
      final connIdx = scaled.floor() % totalSlots;
      final rawProgress = scaled - scaled.floor();
      final conn = animatable[connIdx];
      final type = conn.connectionType;

      final dotsOnLine = dotCount(type);
      final bidir = isBidirectional(type);

      // Forward-travelling dots
      final forwardDots = bidir ? (dotsOnLine / 2).ceil() : dotsOnLine;
      for (var d = 0; d < forwardDots; d++) {
        final spacing = 1.0 / (forwardDots + 1);
        final baseT = (rawProgress + d * spacing) % 1.0;
        final easedT = applyEasing(type, baseT);
        final alpha = pulseAlpha(type, baseT);
        _drawTravellingDot(canvas, conn, easedT, sw, alphaScale: alpha);
      }

      // Reverse-travelling dots (remix only)
      if (bidir) {
        final reverseDots = dotsOnLine - forwardDots;
        for (var d = 0; d < reverseDots; d++) {
          final spacing = 1.0 / (reverseDots + 1);
          final baseT = (rawProgress + d * spacing) % 1.0;
          final reverseT = 1.0 - baseT;
          _drawTravellingDot(canvas, conn, reverseT, sw, reverse: true);
        }
      }
    }
  }

  void _drawTravellingDot(
    Canvas canvas,
    SynapseConnection conn,
    double progress,
    double sw, {
    double alphaScale = 1.0,
    bool reverse = false,
  }) {
    final p0 = Offset(conn.start.dx + sw, conn.start.dy);
    final p1 = Offset(conn.cp1.dx + sw, conn.cp1.dy);
    final p2 = Offset(conn.cp2.dx + sw, conn.cp2.dy);
    final p3 = Offset(conn.end.dx + sw, conn.end.dy);

    final pos = bezierAt(progress, p0, p1, p2, p3);

    // Color: interpolate in the direction of travel
    final colorT = reverse ? 1.0 - progress : progress;
    final dotColor =
        Color.lerp(conn.color, conn.endColor, colorT) ?? conn.color;

    // Outer glow
    canvas.drawCircle(
      pos,
      8,
      Paint()
        ..color = dotColor.withValues(alpha: 0.3 * alphaScale)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Mid glow
    canvas.drawCircle(
      pos,
      4,
      Paint()
        ..color = dotColor.withValues(alpha: 0.6 * alphaScale)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Core
    canvas.drawCircle(
      pos,
      2,
      Paint()..color = dotColor.withValues(alpha: 0.9 * alphaScale),
    );

    // Trail (behind the dot in its direction of travel)
    for (var i = 1; i <= 4; i++) {
      final trailOffset = i * 0.04;
      final trailT = reverse ? progress + trailOffset : progress - trailOffset;
      if (trailT < 0 || trailT > 1) break;
      final trailPos = bezierAt(trailT, p0, p1, p2, p3);
      canvas.drawCircle(
        trailPos,
        5.0 - i * 0.8,
        Paint()
          ..color =
              dotColor.withValues(alpha: 0.25 * (1 - i / 5) * alphaScale)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) =>
      layout != oldDelegate.layout ||
      constellationPostIds != oldDelegate.constellationPostIds ||
      animationValue != oldDelegate.animationValue ||
      scrollOffset != oldDelegate.scrollOffset ||
      viewportHeight != oldDelegate.viewportHeight;
}
