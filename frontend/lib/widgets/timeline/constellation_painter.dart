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

      final basePath = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);

      switch (conn.connectionType) {
        case 'evolution':
          _drawEvolution(canvas, conn, basePath, start, end);
        case 'remix':
          _drawRemix(canvas, conn, basePath, start, end);
        case 'reply':
          _drawReply(canvas, conn, basePath, start, end);
        default: // reference
          _drawReference(canvas, conn, basePath, start, end);
      }
    }
  }

  // ── reference — soft glow, symmetric gradient (baseline) ──

  void _drawReference(
    Canvas canvas,
    SynapseConnection conn,
    Path path,
    Offset start,
    Offset end,
  ) {
    canvas.drawPath(
      path,
      _gradientPaint(conn, start, end, blur: 3),
    );
  }

  // ── evolution — zigzag line (growth / trending up) ──

  void _drawEvolution(
    Canvas canvas,
    SynapseConnection conn,
    Path basePath,
    Offset start,
    Offset end,
  ) {
    final points = _samplePath(basePath, segments: 40);
    if (points.length < 3) {
      canvas.drawPath(basePath, _gradientPaint(conn, start, end));
      return;
    }

    const amplitude = 4.0;
    const zigPeriod = 4; // zigzag every N sample points

    final zigzagPath = Path()..moveTo(points[0].dx, points[0].dy);

    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      // Compute perpendicular offset
      final prev = points[max(0, i - 1)];
      final next = points[min(points.length - 1, i + 1)];
      final tx = next.dx - prev.dx;
      final ty = next.dy - prev.dy;
      final tLen = sqrt(tx * tx + ty * ty);
      if (tLen == 0) continue;
      final nx = -ty / tLen;
      final ny = tx / tLen;

      // Alternating zigzag
      final sign = (i ~/ zigPeriod).isEven ? 1.0 : -1.0;
      // Fade amplitude at ends for smooth entry/exit
      final t = i / (points.length - 1);
      final fade = sin(t * pi); // 0 at ends, 1 in middle
      final offset = amplitude * sign * fade;

      zigzagPath.lineTo(p.dx + nx * offset, p.dy + ny * offset);
    }

    canvas.drawPath(
      zigzagPath,
      _gradientPaint(conn, start, end, widthMul: 1.1, blur: 2,
          opacityMul: 1.5),
    );
  }

  // ── remix — two spiraling/crossing strands (shuffle) ──

  void _drawRemix(
    Canvas canvas,
    SynapseConnection conn,
    Path basePath,
    Offset start,
    Offset end,
  ) {
    final points = _samplePath(basePath, segments: 60);
    if (points.length < 3) {
      canvas.drawPath(basePath, _gradientPaint(conn, start, end));
      return;
    }

    const amplitude = 5.0;
    const crossingFrequency = 0.06; // controls how often strands cross

    final strandA = Path()..moveTo(points[0].dx, points[0].dy);
    final strandB = Path()..moveTo(points[0].dx, points[0].dy);

    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      final prev = points[max(0, i - 1)];
      final next = points[min(points.length - 1, i + 1)];
      final tx = next.dx - prev.dx;
      final ty = next.dy - prev.dy;
      final tLen = sqrt(tx * tx + ty * ty);
      if (tLen == 0) continue;
      final nx = -ty / tLen;
      final ny = tx / tLen;

      final t = i / (points.length - 1);
      final fade = sin(t * pi);
      final wave = sin(i * crossingFrequency * 2 * pi) * amplitude * fade;

      strandA.lineTo(p.dx + nx * wave, p.dy + ny * wave);
      strandB.lineTo(p.dx - nx * wave, p.dy - ny * wave);
    }

    final paint = _gradientPaint(
      conn, start, end, widthMul: 0.7, blur: 1.5, opacityMul: 1.3,
    );
    canvas.drawPath(strandA, paint);
    canvas.drawPath(strandB, paint);
  }

  // ── reply — line with arrowhead (response) ──

  void _drawReply(
    Canvas canvas,
    SynapseConnection conn,
    Path basePath,
    Offset start,
    Offset end,
  ) {
    // Draw the main line (thinner, softer)
    canvas.drawPath(
      basePath,
      _gradientPaint(conn, start, end, widthMul: 0.7, blur: 2,
          opacityMul: 0.7),
    );

    // Draw arrowhead near the target end
    final points = _samplePath(basePath, segments: 20);
    if (points.length < 3) return;

    final tip = points.last;
    final before = points[points.length - 3];
    final dx = tip.dx - before.dx;
    final dy = tip.dy - before.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;

    final ux = dx / len; // unit vector along the line
    final uy = dy / len;
    final px = -uy; // perpendicular
    final py = ux;

    const arrowLen = 8.0;
    const arrowWidth = 4.0;

    final arrowPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - ux * arrowLen + px * arrowWidth,
        tip.dy - uy * arrowLen + py * arrowWidth,
      )
      ..lineTo(
        tip.dx - ux * arrowLen - px * arrowWidth,
        tip.dy - uy * arrowLen - py * arrowWidth,
      )
      ..close();

    final opacity = (conn.opacity * 1.5).clamp(0.0, 1.0);
    canvas.drawPath(
      arrowPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = conn.endColor.withValues(alpha: opacity),
    );
  }

  // ── Helpers ──

  /// Build a gradient stroke Paint.
  Paint _gradientPaint(
    SynapseConnection conn,
    Offset start,
    Offset end, {
    double widthMul = 1.0,
    double opacityMul = 1.0,
    double blur = 3,
  }) {
    final o = (conn.opacity * opacityMul).clamp(0.0, 1.0);
    return Paint()
      ..strokeWidth = conn.strokeWidth * widthMul
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
      ..shader = ui.Gradient.linear(
        start,
        end,
        [
          conn.color.withValues(alpha: o),
          conn.endColor.withValues(alpha: o),
        ],
      );
  }

  /// Sample evenly-spaced points along a path.
  static List<Offset> _samplePath(Path path, {int segments = 30}) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return [];
    final metric = metrics.first;
    final length = metric.length;
    if (length == 0) return [];

    final points = <Offset>[];
    for (var i = 0; i <= segments; i++) {
      final d = (i / segments) * length;
      final tangent = metric.getTangentForOffset(d);
      if (tangent != null) points.add(tangent.position);
    }
    return points;
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) =>
      layout != oldDelegate.layout ||
      constellationPostIds != oldDelegate.constellationPostIds;
}
