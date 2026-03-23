import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
      ..color = const Color(0xFF1a1a28)
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
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) =>
      layout != oldDelegate.layout ||
      constellationPostIds != oldDelegate.constellationPostIds;
}
