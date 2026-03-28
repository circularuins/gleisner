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

      // Connection type visual styles:
      //   reference — solid (default)
      //   evolution — dashed (long dash)
      //   remix     — thicker + higher opacity
      //   reply     — dotted (short dash)
      switch (conn.connectionType) {
        case 'evolution':
          canvas.drawPath(_dashPath(path, dashLength: 8, gapLength: 6), paint);
        case 'reply':
          canvas.drawPath(_dashPath(path, dashLength: 3, gapLength: 4), paint);
        case 'remix':
          paint.strokeWidth = conn.strokeWidth * 1.6;
          canvas.drawPath(path, paint);
        default: // reference
          canvas.drawPath(path, paint);
      }
    }
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
