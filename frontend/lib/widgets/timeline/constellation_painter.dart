import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';
import '../../utils/constellation_layout.dart';

/// Paints the background layer: date spine line + synapse connections.
class ConstellationPainter extends CustomPainter {
  final LayoutResult layout;
  final Set<String>? constellationPostIds;

  ConstellationPainter({required this.layout, this.constellationPostIds});

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

  void _drawSynapses(Canvas canvas) {
    const sw = ConstellationLayout.spineWidth;
    final filter = constellationPostIds;

    for (final conn in layout.connections) {
      // In constellation mode, only draw synapses within the constellation
      if (filter != null &&
          (!filter.contains(conn.sourcePostId) ||
              !filter.contains(conn.targetPostId))) {
        continue;
      }

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

      // Connection type visual styles:
      //   reference — soft glow, solid
      //   evolution — crisp dashed (no blur), brighter
      //   remix     — thick bright glow
      //   reply     — crisp dotted (no blur), brighter
      switch (conn.connectionType) {
        case 'evolution':
          canvas.drawPath(
            _dashPath(path, dashLength: 10, gapLength: 8),
            _paint(conn, sw, opacityMul: 2.5, widthMul: 1.2, blur: false),
          );
        case 'reply':
          canvas.drawPath(
            _dashPath(path, dashLength: 4, gapLength: 6),
            _paint(conn, sw, opacityMul: 2.5, blur: false),
          );
        case 'remix':
          canvas.drawPath(
            path,
            _paint(conn, sw, opacityMul: 2.0, widthMul: 2.5, blurRadius: 5),
          );
        default: // reference
          canvas.drawPath(path, _paint(conn, sw));
      }
    }
  }

  /// Build a Paint configured for a synapse connection.
  static Paint _paint(
    SynapseConnection conn,
    double sw, {
    double opacityMul = 1.0,
    double widthMul = 1.0,
    bool blur = true,
    double blurRadius = 3,
  }) {
    final opacity = (conn.opacity * opacityMul).clamp(0.0, 1.0);
    final startColor = conn.color.withValues(alpha: opacity);
    final endColor = conn.endColor.withValues(alpha: opacity);

    return Paint()
      ..strokeWidth = conn.strokeWidth * widthMul
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter =
          blur ? MaskFilter.blur(BlurStyle.normal, blurRadius) : null
      ..shader = ui.Gradient.linear(
        Offset(conn.start.dx + sw, conn.start.dy),
        Offset(conn.end.dx + sw, conn.end.dy),
        [startColor, endColor],
      );
  }

  /// Create a dashed version of a path by sampling along it.
  static Path _dashPath(
    Path source, {
    required double dashLength,
    required double gapLength,
  }) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        result.addPath(segment, Offset.zero);
        distance += dashLength + gapLength;
      }
    }
    return result;
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) =>
      layout != oldDelegate.layout ||
      constellationPostIds != oldDelegate.constellationPostIds;
}
