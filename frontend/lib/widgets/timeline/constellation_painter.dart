import 'package:flutter/material.dart';

import '../../utils/constellation_layout.dart';

/// Paints the background layer: date spine line + synapse connections.
class ConstellationPainter extends CustomPainter {
  final LayoutResult layout;

  ConstellationPainter({required this.layout});

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
    for (final conn in layout.connections) {
      final paint = Paint()
        ..color = conn.color.withValues(alpha: conn.opacity)
        ..strokeWidth = conn.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      const sw = ConstellationLayout.spineWidth;
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
      layout != oldDelegate.layout;
}
