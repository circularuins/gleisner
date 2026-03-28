import 'dart:math';
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
      if (filter != null &&
          (!filter.contains(conn.sourcePostId) ||
              !filter.contains(conn.targetPostId))) {
        continue;
      }

      final start = Offset(conn.start.dx + sw, conn.start.dy);
      final end = Offset(conn.end.dx + sw, conn.end.dy);
      final cp1 = Offset(conn.cp1.dx + sw, conn.cp1.dy);
      final cp2 = Offset(conn.cp2.dx + sw, conn.cp2.dy);

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

      switch (conn.connectionType) {
        case 'evolution':
          _drawEvolution(canvas, conn, path, start, end);
        case 'remix':
          _drawRemix(canvas, conn, path, start, end, cp1, cp2);
        case 'reply':
          _drawReply(canvas, conn, path, start, end);
        default: // reference
          _drawReference(canvas, conn, path, start, end);
      }
    }
  }

  /// reference — the baseline: soft glow, symmetric gradient.
  void _drawReference(
    Canvas canvas,
    SynapseConnection conn,
    Path path,
    Offset start,
    Offset end,
  ) {
    final paint = Paint()
      ..strokeWidth = conn.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = ui.Gradient.linear(
        start,
        end,
        [
          conn.color.withValues(alpha: conn.opacity),
          conn.endColor.withValues(alpha: conn.opacity),
        ],
      );
    canvas.drawPath(path, paint);
  }

  /// evolution — directional flow: source dim → target bright.
  /// Conveys growth and progression.
  void _drawEvolution(
    Canvas canvas,
    SynapseConnection conn,
    Path path,
    Offset start,
    Offset end,
  ) {
    final baseOpacity = conn.opacity * 1.5;
    // Dim at source, bright at target — forward momentum
    final paint = Paint()
      ..strokeWidth = conn.strokeWidth * 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..shader = ui.Gradient.linear(
        start,
        end,
        [
          conn.color.withValues(alpha: baseOpacity * 0.2),
          conn.endColor.withValues(alpha: (baseOpacity * 1.0).clamp(0, 1)),
        ],
      );
    canvas.drawPath(path, paint);
  }

  /// remix — double helix: two parallel lines with slight offset.
  /// Conveys interference, two waves merging.
  void _drawRemix(
    Canvas canvas,
    SynapseConnection conn,
    Path path,
    Offset start,
    Offset end,
    Offset cp1,
    Offset cp2,
  ) {
    final opacity = (conn.opacity * 1.3).clamp(0.0, 1.0);
    final startColor = conn.color.withValues(alpha: opacity);
    final endColor = conn.endColor.withValues(alpha: opacity);

    // Perpendicular offset for the two strands
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = (dx * dx + dy * dy);
    final dist = len > 0 ? sqrt(len) : 1.0;
    final nx = -dy / dist * 5.0; // 5px perpendicular offset
    final ny = dx / dist * 5.0;

    for (final sign in [1.0, -1.0]) {
      final ox = nx * sign;
      final oy = ny * sign;
      final strand = Path()
        ..moveTo(start.dx + ox, start.dy + oy)
        ..cubicTo(
          cp1.dx + ox,
          cp1.dy + oy,
          cp2.dx + ox,
          cp2.dy + oy,
          end.dx + ox,
          end.dy + oy,
        );
      final paint = Paint()
        ..strokeWidth = conn.strokeWidth * 0.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
        ..shader = ui.Gradient.linear(
          Offset(start.dx + ox, start.dy + oy),
          Offset(end.dx + ox, end.dy + oy),
          [startColor, endColor],
        );
      canvas.drawPath(strand, paint);
    }
  }

  /// reply — faint echo: thinner and more transparent than reference.
  /// Conveys a light, conversational connection.
  void _drawReply(
    Canvas canvas,
    SynapseConnection conn,
    Path path,
    Offset start,
    Offset end,
  ) {
    final paint = Paint()
      ..strokeWidth = conn.strokeWidth * 0.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..shader = ui.Gradient.linear(
        start,
        end,
        [
          conn.color.withValues(alpha: conn.opacity * 0.5),
          conn.endColor.withValues(alpha: conn.opacity * 0.5),
        ],
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) =>
      layout != oldDelegate.layout ||
      constellationPostIds != oldDelegate.constellationPostIds;
}
