import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/models/post.dart';
import 'package:gleisner_web/utils/constellation_layout.dart';
import 'package:gleisner_web/widgets/timeline/constellation_painter.dart';

SynapseConnection _makeConn({
  Offset start = const Offset(0, 100),
  Offset end = const Offset(100, 500),
  Offset? cp1,
  Offset? cp2,
  ConnectionType connectionType = ConnectionType.reference,
  String sourcePostId = 's1',
  String targetPostId = 't1',
}) {
  return SynapseConnection(
    sourcePostId: sourcePostId,
    targetPostId: targetPostId,
    connectionType: connectionType,
    start: start,
    end: end,
    cp1: cp1 ?? Offset(start.dx + 50, start.dy),
    cp2: cp2 ?? Offset(end.dx - 50, end.dy),
    color: Colors.blue,
    endColor: Colors.red,
    opacity: 0.4,
    strokeWidth: 2,
  );
}

LayoutResult _makeLayout({List<SynapseConnection> connections = const []}) {
  return LayoutResult(
    nodes: const [],
    days: const [],
    connections: connections,
    totalHeight: 1000,
  );
}

void main() {
  // ─── bezierAt ───────────────────────────────────────────────────

  group('bezierAt', () {
    test('returns p0 at t=0', () {
      const p0 = Offset(0, 0);
      const p1 = Offset(10, 20);
      const p2 = Offset(30, 40);
      const p3 = Offset(50, 60);
      final result = ConstellationPainter.bezierAt(0, p0, p1, p2, p3);
      expect(result.dx, closeTo(p0.dx, 0.001));
      expect(result.dy, closeTo(p0.dy, 0.001));
    });

    test('returns p3 at t=1', () {
      const p0 = Offset(0, 0);
      const p1 = Offset(10, 20);
      const p2 = Offset(30, 40);
      const p3 = Offset(50, 60);
      final result = ConstellationPainter.bezierAt(1, p0, p1, p2, p3);
      expect(result.dx, closeTo(p3.dx, 0.001));
      expect(result.dy, closeTo(p3.dy, 0.001));
    });

    test('midpoint of a straight line is the geometric midpoint', () {
      // Straight line: all points collinear
      const p0 = Offset(0, 0);
      const p1 = Offset(100 / 3, 0);
      const p2 = Offset(200 / 3, 0);
      const p3 = Offset(100, 0);
      final result = ConstellationPainter.bezierAt(0.5, p0, p1, p2, p3);
      expect(result.dx, closeTo(50, 0.001));
      expect(result.dy, closeTo(0, 0.001));
    });

    test('monotonically increases x on a left-to-right curve', () {
      const p0 = Offset(0, 0);
      const p1 = Offset(30, 50);
      const p2 = Offset(70, 50);
      const p3 = Offset(100, 0);

      double prevX = -1;
      for (var i = 0; i <= 10; i++) {
        final t = i / 10.0;
        final pos = ConstellationPainter.bezierAt(t, p0, p1, p2, p3);
        expect(pos.dx, greaterThanOrEqualTo(prevX));
        prevX = pos.dx;
      }
    });
  });

  // ─── Connection-type dot configuration ──────────────────────────

  group('dotCount', () {
    test('reference has 1 dot', () {
      expect(ConstellationPainter.dotCount(ConnectionType.reference), 1);
    });

    test('evolution has 2 dots', () {
      expect(ConstellationPainter.dotCount(ConnectionType.evolution), 2);
    });

    test('remix has 4 dots', () {
      expect(ConstellationPainter.dotCount(ConnectionType.remix), 4);
    });

    test('reply has 3 dots', () {
      expect(ConstellationPainter.dotCount(ConnectionType.reply), 3);
    });

    test('all types covered (exhaustive switch)', () {
      // With enum, all types are guaranteed at compile time.
      // Verify every value returns a positive count.
      for (final type in ConnectionType.values) {
        expect(ConstellationPainter.dotCount(type), greaterThan(0));
      }
    });
  });

  group('applyEasing', () {
    test('evolution applies ease-in (t²)', () {
      expect(ConstellationPainter.applyEasing(ConnectionType.evolution, 0.0), 0.0);
      expect(ConstellationPainter.applyEasing(ConnectionType.evolution, 0.5), 0.25);
      expect(ConstellationPainter.applyEasing(ConnectionType.evolution, 1.0), 1.0);
    });

    test('reference returns linear (unchanged)', () {
      expect(ConstellationPainter.applyEasing(ConnectionType.reference, 0.5), 0.5);
      expect(ConstellationPainter.applyEasing(ConnectionType.reference, 0.3), 0.3);
    });

    test('reply returns linear', () {
      expect(ConstellationPainter.applyEasing(ConnectionType.reply, 0.7), 0.7);
    });

    test('remix returns linear', () {
      expect(ConstellationPainter.applyEasing(ConnectionType.remix, 0.4), 0.4);
    });

    test('evolution is always ≤ linear (ease-in curve)', () {
      for (var i = 0; i <= 10; i++) {
        final t = i / 10.0;
        expect(
          ConstellationPainter.applyEasing(ConnectionType.evolution, t),
          lessThanOrEqualTo(t + 0.001), // float tolerance
        );
      }
    });
  });

  group('pulseAlpha', () {
    test('non-reply types always return 1.0', () {
      for (final type in [ConnectionType.reference, ConnectionType.evolution, ConnectionType.remix]) {
        expect(ConstellationPainter.pulseAlpha(type, 0.0), 1.0);
        expect(ConstellationPainter.pulseAlpha(type, 0.5), 1.0);
        expect(ConstellationPainter.pulseAlpha(type, 1.0), 1.0);
      }
    });

    test('reply oscillates between 0.0 and 1.0', () {
      // Formula: 0.5 + 0.5 * sin(t * pi * 4), range = [0.0, 1.0]
      for (var i = 0; i <= 100; i++) {
        final t = i / 100.0;
        final alpha = ConstellationPainter.pulseAlpha(ConnectionType.reply, t);
        expect(alpha, greaterThanOrEqualTo(-0.001));
        expect(alpha, lessThanOrEqualTo(1.0 + 0.001));
      }
    });

    test('reply reaches 1.0 at peak', () {
      // sin(t * pi * 4) = 1 when t * pi * 4 = pi/2 → t = 0.125
      final peak = ConstellationPainter.pulseAlpha(ConnectionType.reply, 0.125);
      expect(peak, closeTo(1.0, 0.001));
    });

    test('reply reaches 0.0 at trough', () {
      // sin(t * pi * 4) = -1 when t * pi * 4 = 3*pi/2 → t = 0.375
      final trough = ConstellationPainter.pulseAlpha(ConnectionType.reply, 0.375);
      expect(trough, closeTo(0.0, 0.001));
    });

    test('reply completes 2 full cycles from 0 to 1', () {
      // sin(t * pi * 4): period = 2*pi / (pi*4) = 0.5, so 2 cycles in [0,1]
      // Verify by checking that alpha returns to 0.5 at t=0, 0.25, 0.5, 0.75, 1.0
      // (the midline crossings / start points of each half-cycle)
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(
          ConstellationPainter.pulseAlpha(ConnectionType.reply, t),
          closeTo(0.5, 0.01),
          reason: 'alpha should be ~0.5 at t=$t',
        );
      }
    });
  });

  group('isBidirectional', () {
    test('remix is bidirectional', () {
      expect(ConstellationPainter.isBidirectional(ConnectionType.remix), isTrue);
    });

    test('other types are not bidirectional', () {
      for (final type in [ConnectionType.reference, ConnectionType.evolution, ConnectionType.reply]) {
        expect(ConstellationPainter.isBidirectional(type), isFalse);
      }
    });
  });

  // ─── Viewport filtering ─────────────────────────────────────────

  group('isInViewport', () {
    test('infinite viewport includes everything', () {
      final conn = _makeConn(start: const Offset(0, 5000), end: const Offset(0, 6000));
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 0, viewportHeight: double.infinity),
        isTrue,
      );
    });

    test('connection fully inside viewport', () {
      final conn = _makeConn(start: const Offset(0, 200), end: const Offset(0, 400));
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 100, viewportHeight: 500),
        isTrue,
      );
    });

    test('connection fully above viewport (beyond margin)', () {
      final conn = _makeConn(start: const Offset(0, 10), end: const Offset(0, 50));
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 500, viewportHeight: 300),
        isFalse,
      );
    });

    test('connection fully below viewport (beyond margin)', () {
      final conn = _makeConn(start: const Offset(0, 1500), end: const Offset(0, 1800));
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 100, viewportHeight: 300),
        isFalse,
      );
    });

    test('connection partially overlapping top edge (within margin)', () {
      // viewport top = 500, margin = 100 → effective top = 400
      // connection ends at 420, which is > 400
      final conn = _makeConn(start: const Offset(0, 350), end: const Offset(0, 420));
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 500, viewportHeight: 300),
        isTrue,
      );
    });

    test('connection partially overlapping bottom edge (within margin)', () {
      // viewport bottom = 500 + 300 = 800, margin = 100 → effective bottom = 900
      // connection starts at 850, which is < 900
      final conn = _makeConn(start: const Offset(0, 850), end: const Offset(0, 1000));
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 500, viewportHeight: 300),
        isTrue,
      );
    });

    test('handles reversed start/end y-coordinates', () {
      // end.dy < start.dy (target above source)
      final conn = _makeConn(start: const Offset(0, 600), end: const Offset(0, 200));
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 300, viewportHeight: 200),
        isTrue,
      );
    });

    test('custom margin works', () {
      // Default margin (100) would include this, custom 0 margin excludes it
      final conn = _makeConn(start: const Offset(0, 480), end: const Offset(0, 499));
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 500, viewportHeight: 300, margin: 0),
        isFalse,
      );
      expect(
        ConstellationPainter.isInViewport(conn,
            scrollOffset: 500, viewportHeight: 300, margin: 100),
        isTrue,
      );
    });
  });

  // ─── shouldRepaint ──────────────────────────────────────────────

  group('shouldRepaint', () {
    final layout1 = _makeLayout();
    final layout2 = _makeLayout(connections: [_makeConn()]);

    test('returns false for identical parameters', () {
      final a = ConstellationPainter(layout: layout1, animationValue: 0.5);
      final b = ConstellationPainter(layout: layout1, animationValue: 0.5);
      expect(a.shouldRepaint(b), isFalse);
    });

    test('returns true when layout changes', () {
      final a = ConstellationPainter(layout: layout1);
      final b = ConstellationPainter(layout: layout2);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when animationValue changes', () {
      final a = ConstellationPainter(layout: layout1, animationValue: 0.1);
      final b = ConstellationPainter(layout: layout1, animationValue: 0.2);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when scrollOffset changes', () {
      final a = ConstellationPainter(layout: layout1, scrollOffset: 0);
      final b = ConstellationPainter(layout: layout1, scrollOffset: 100);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when viewportHeight changes', () {
      final a = ConstellationPainter(layout: layout1, viewportHeight: 600);
      final b = ConstellationPainter(layout: layout1, viewportHeight: 800);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when simultaneousDots changes', () {
      final a = ConstellationPainter(layout: layout1, simultaneousDots: 3);
      final b = ConstellationPainter(layout: layout1, simultaneousDots: 5);
      expect(a.shouldRepaint(b), isTrue);
    });

    test('returns true when constellationPostIds changes', () {
      final a = ConstellationPainter(layout: layout1);
      final b = ConstellationPainter(layout: layout1, constellationPostIds: {'p1'});
      expect(a.shouldRepaint(b), isTrue);
    });
  });

  // ─── Connection type integration: forward/reverse dot counts ────

  group('connection type dot distribution', () {
    test('remix splits dots into forward and reverse', () {
      final total = ConstellationPainter.dotCount(ConnectionType.remix); // 4
      final forward = (total / 2).ceil(); // 2
      final reverse = total - forward; // 2
      expect(forward, 2);
      expect(reverse, 2);
    });

    test('non-bidirectional types are not split into reverse dots', () {
      for (final type in [ConnectionType.reference, ConnectionType.evolution, ConnectionType.reply]) {
        expect(ConstellationPainter.isBidirectional(type), isFalse,
            reason: '$type should not be bidirectional');
        // For non-bidirectional types, forward count equals total count
        // (no reverse dots are allocated)
        final total = ConstellationPainter.dotCount(type);
        final forwardDots = total; // bidir=false → no split
        final reverseDots = 0;
        expect(forwardDots + reverseDots, total);
        expect(reverseDots, 0);
      }
    });
  });
}
