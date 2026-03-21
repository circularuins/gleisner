import 'dart:math';

import 'package:flutter/material.dart';

import '../models/post.dart';
import 'deterministic_rng.dart';

/// A placed node in the constellation layout.
class PlacedNode {
  final Post post;
  final double x;
  final double y;
  final double width;
  final double height;
  final double nodeSize;
  final double mediaHeight;
  final bool showInfo;

  PlacedNode({
    required this.post,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.nodeSize,
    required this.mediaHeight,
    required this.showInfo,
  });

  double get centerX => x + width / 2;
  double get centerY => y + (mediaHeight + (showInfo ? 30 : 0)) / 2;
}

/// A day section for the spine.
class DaySection {
  final DateTime date;
  final double top;
  final double height;
  final bool isToday;

  const DaySection({
    required this.date,
    required this.top,
    required this.height,
    required this.isToday,
  });
}

/// A synapse connection between two nodes.
class SynapseConnection {
  final Offset start;
  final Offset end;
  final Offset cp1;
  final Offset cp2;
  final Color color;
  final double opacity;
  final double strokeWidth;

  const SynapseConnection({
    required this.start,
    required this.end,
    required this.cp1,
    required this.cp2,
    required this.color,
    required this.opacity,
    required this.strokeWidth,
  });
}

/// The complete layout result.
class LayoutResult {
  final List<PlacedNode> nodes;
  final List<DaySection> days;
  final List<SynapseConnection> connections;
  final double totalHeight;

  const LayoutResult({
    required this.nodes,
    required this.days,
    required this.connections,
    required this.totalHeight,
  });
}

/// Computes the constellation layout for a list of posts.
class ConstellationLayout {
  static const double _tightPad = 14;

  /// Width reserved for the date spine on the left side.
  static const double spineWidth = 36;

  /// Compute node size from importance (46–170).
  /// Min 90px (title always readable), max 170px.
  static double nodeSize(double importance) {
    return 90 + importance.clamp(0.0, 1.0) * 80;
  }

  /// Compute the full constellation layout.
  static LayoutResult compute({
    required List<Post> posts,
    required double containerWidth,
  }) {
    if (posts.isEmpty) {
      return const LayoutResult(
        nodes: [],
        days: [],
        connections: [],
        totalHeight: 0,
      );
    }

    final cW = max(containerWidth - spineWidth, 200.0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Convert UTC createdAt to local date for grouping
    DateTime localDate(DateTime utc) {
      final local = utc.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    // Sort by date (most recent first in display, but group by day)
    final sorted = List<Post>.from(posts)
      ..sort((a, b) {
        final dayA = today.difference(localDate(a.createdAt)).inDays;
        final dayB = today.difference(localDate(b.createdAt)).inDays;
        if (dayA != dayB) return dayA.compareTo(dayB);
        return b.createdAt.compareTo(a.createdAt);
      });

    // Group by days-ago
    final dayMap = <int, List<Post>>{};
    for (final post in sorted) {
      final daysAgo = today.difference(localDate(post.createdAt)).inDays;
      dayMap.putIfAbsent(daysAgo, () => []).add(post);
    }

    final dayKeys = dayMap.keys.toList()..sort();

    // Pass 1: Generous day heights
    final dayY = <int, _DaySlot>{};
    double y = 20;
    for (int i = 0; i < dayKeys.length; i++) {
      final dk = dayKeys[i];
      final items = dayMap[dk];
      if (items == null || items.isEmpty) {
        // Empty day — minimal slot
        dayY[dk] = _DaySlot(top: y, height: 8);
        y += 8;
        continue;
      }
      double maxItemH = 0;
      for (final it in items) {
        final sz = nodeSize(it.importance);
        final h = sz > 110
            ? sz * 0.7 + 30 + 18
            : sz * 0.85 + 30 + (sz >= 50 ? 18 : 0);
        maxItemH = max(maxItemH, h);
      }
      final h = max(100.0, maxItemH * items.length * 0.7);
      dayY[dk] = _DaySlot(top: y, height: h);
      y += h;
    }

    // Compute per-post vertical order within each day (newest first)
    final dayOrder = <String, double>{};
    for (final dk in dayKeys) {
      final items = dayMap[dk];
      if (items == null || items.isEmpty) continue;
      // Sort by createdAt descending (newest first)
      final byCtime = List<Post>.from(items)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (int i = 0; i < byCtime.length; i++) {
        dayOrder[byCtime[i].id] = byCtime.length > 1
            ? i / (byCtime.length - 1)
            : 0.0;
      }
    }

    // Place items — largest first for best-fit collision avoidance
    final rng = DeterministicRng('constellation-v3');
    final placedItems = <_PlacedItem>[];

    final bySize = List<Post>.from(
      sorted,
    )..sort((a, b) => nodeSize(b.importance).compareTo(nodeSize(a.importance)));

    for (final item in bySize) {
      final daysAgo = today.difference(localDate(item.createdAt)).inDays;
      final dI = dayY[daysAgo];
      if (dI == null) continue;

      final sz = nodeSize(item.importance);
      final isAudio = item.mediaType == MediaType.audio;
      final w = isAudio
          ? min(sz * 1.8, cW - 20)
          : sz > 110
          ? min(sz * 1.25, cW - 20)
          : sz;
      final mediaH = isAudio
          ? sz * 0.45
          : sz > 110
          ? sz * 0.7
          : sz * 0.85;
      final infoH = isAudio ? 0.0 : 30.0;
      final totalNodeH = mediaH + infoH;

      // Position based on creation order within day (newest = 0.0 = top)
      final orderFrac = dayOrder[item.id] ?? 0.0;
      final yBase = dI.top + orderFrac * (dI.height - totalNodeH);
      const margin = 8.0;

      double bx = margin + rng.next() * (cW - w - margin * 2);
      double by = yBase;
      double bo = double.infinity;

      for (int a = 0; a < 28; a++) {
        final xC = margin + rng.next() * (cW - w - margin * 2);
        final yN = (rng.next() - 0.5) * 60;
        final yC = max(
          dI.top + 4,
          min(dI.top + dI.height - totalNodeH - 4, yBase + yN),
        );
        final ov = _overlapAmount(placedItems, xC, yC, w, totalNodeH);
        if (ov < bo) {
          bo = ov;
          bx = xC;
          by = yC;
          if (ov == 0) break;
        }
      }

      placedItems.add(
        _PlacedItem(
          x: bx,
          y: by,
          w: w,
          h: totalNodeH,
          post: item,
          day: daysAgo,
        ),
      );
    }

    // Pass 2: Compact
    double compactY = 20;
    final dayCompact = <int, _DayCompact>{};

    for (int i = 0; i < dayKeys.length; i++) {
      final dk = dayKeys[i];
      if (i > 0 && dk - dayKeys[i - 1] > 1) compactY += 20;
      final dayItems = placedItems.where((p) => p.day == dk).toList();

      if (dayItems.isEmpty) {
        dayCompact[dk] = _DayCompact(newTop: compactY, newHeight: 40, shift: 0);
        compactY += 40;
        continue;
      }

      final minY = dayItems.map((p) => p.y).reduce(min);
      final maxY = dayItems.map((p) => p.y + p.h).reduce(max);
      final actualH = maxY - minY;
      final newHeight = actualH + _tightPad * 2;
      final shift = compactY + _tightPad - minY;
      dayCompact[dk] = _DayCompact(
        newTop: compactY,
        newHeight: newHeight,
        shift: shift,
      );
      compactY += newHeight;
    }

    // Apply day-level compaction
    for (final p in placedItems) {
      final dc = dayCompact[p.day];
      if (dc != null) p.y += dc.shift;
    }

    // Pass 3: Pull each node upward as far as possible without overlapping
    const gapPad = 8.0;
    placedItems.sort((a, b) => a.y.compareTo(b.y));
    for (final p in placedItems) {
      // Find the lowest y this node can move to
      double minAllowedY = 20.0;
      for (final other in placedItems) {
        if (identical(other, p)) continue;
        // Check horizontal overlap
        final hOverlap =
            p.x < other.x + other.w + gapPad && p.x + p.w + gapPad > other.x;
        if (hOverlap &&
            other.y + other.h + gapPad > minAllowedY &&
            other.y < p.y) {
          minAllowedY = max(minAllowedY, other.y + other.h + gapPad);
        }
      }
      if (minAllowedY < p.y) {
        p.y = minAllowedY;
      }
    }

    // Pass 4: Enforce strict time-series order.
    // Newer posts must never have their top edge below older posts' top edge.
    // Sort by createdAt descending (newest first) — y values must be
    // non-decreasing in this order.
    final byTime = List<_PlacedItem>.from(placedItems)
      ..sort((a, b) => b.post.createdAt.compareTo(a.post.createdAt));
    // Small offset so closely-timed posts don't align exactly
    final nudgeRng = DeterministicRng('nudge');
    double maxTopY = -double.infinity;
    for (final p in byTime) {
      if (p.y < maxTopY) {
        p.y = maxTopY;
      }
      final nudge = 6.0 + nudgeRng.next() * 24.0; // 6–30px
      maxTopY = max(maxTopY, p.y + nudge);
    }

    // Pass 5: Enforce minimum vertical gap between day groups so date
    // labels don't overlap (~36px needed for date label height).
    const minDayGap = 40.0;
    for (int i = 1; i < dayKeys.length; i++) {
      final prevDk = dayKeys[i - 1];
      final dk = dayKeys[i];
      final prevItems = placedItems.where((p) => p.day == prevDk).toList();
      final curItems = placedItems.where((p) => p.day == dk).toList();
      if (prevItems.isEmpty || curItems.isEmpty) continue;

      final prevBottom = prevItems.map((p) => p.y + p.h).reduce(max);
      final curTop = curItems.map((p) => p.y).reduce(min);
      final gap = curTop - prevBottom;

      if (gap < minDayGap) {
        final shift = minDayGap - gap;
        // Push this day and all subsequent days down
        final daysToShift = dayKeys.sublist(i).toSet();
        for (final p in placedItems) {
          if (daysToShift.contains(p.day)) {
            p.y += shift;
          }
        }
      }
    }

    // Recalculate total height and day section positions
    final nodeBottomY = placedItems.isEmpty
        ? compactY
        : placedItems.map((p) => p.y + p.h).reduce(max);

    for (final dk in dayKeys) {
      final dayItems = placedItems.where((p) => p.day == dk).toList();
      if (dayItems.isEmpty) continue;
      final dayMinY = dayItems.map((p) => p.y).reduce(min);
      final dayMaxY = dayItems.map((p) => p.y + p.h).reduce(max);
      dayCompact[dk] = _DayCompact(
        newTop: dayMinY - _tightPad,
        newHeight: dayMaxY - dayMinY + _tightPad * 2,
        shift: 0,
      );
    }

    // Build PlacedNode list
    final nodes = <PlacedNode>[];
    for (final p in placedItems) {
      final sz = nodeSize(p.post.importance);
      final isAudio = p.post.mediaType == MediaType.audio;
      final mediaH = isAudio
          ? sz * 0.45
          : sz > 110
          ? sz * 0.7
          : sz * 0.85;
      final showInfo = !isAudio;
      nodes.add(
        PlacedNode(
          post: p.post,
          x: p.x,
          y: p.y,
          width: p.w,
          height: p.h,
          nodeSize: sz,
          mediaHeight: mediaH,
          showInfo: showInfo,
        ),
      );
    }

    // Build DaySection list (only days with posts)
    final days = <DaySection>[];
    for (final dk in dayKeys) {
      final dc = dayCompact[dk];
      if (dc == null) continue;
      final date = today.subtract(Duration(days: dk));
      days.add(
        DaySection(
          date: date,
          top: dc.newTop,
          height: dc.newHeight,
          isToday: dk == 0,
        ),
      );
    }

    // Total height accounts for both nodes and day labels
    final dayBottomY = days.isEmpty ? 0.0 : days.last.top + days.last.height;
    final totalHeight = max(nodeBottomY, dayBottomY) + 40;

    // Build synapse connections
    // TODO(synapse): 仮実装 — 同一トラック時系列隣接ペアを自動接続。
    // 本来はユーザー指定 or AI 判定による接続データをバックエンドから取得する。
    // 接続ロジック・データモデル実装後にこの仮実装を置き換えること。
    final connections = _buildSynapses(nodes);

    return LayoutResult(
      nodes: nodes,
      days: days,
      connections: connections,
      totalHeight: totalHeight,
    );
  }

  static double _overlapAmount(
    List<_PlacedItem> placed,
    double x,
    double y,
    double w,
    double h,
  ) {
    const pad = 10.0;
    double worst = 0;
    for (final p in placed) {
      final ox = max(0.0, min(x + w, p.x + p.w) - max(x, p.x) + pad);
      final oy = max(0.0, min(y + h, p.y + p.h) - max(y, p.y) + pad);
      if (ox > 0 && oy > 0) worst = max(worst, ox * oy);
    }
    return worst;
  }

  /// 仮実装: 同一トラック内の時系列隣接ノードをベジェ曲線で接続。
  /// 本番では接続データ（ユーザー指定 or AI 判定）をバックエンドから取得して描画する。
  static List<SynapseConnection> _buildSynapses(List<PlacedNode> nodes) {
    final connections = <SynapseConnection>[];

    // Group by trackId
    final byTrack = <String, List<PlacedNode>>{};
    for (final node in nodes) {
      final tid = node.post.trackId;
      if (tid == null) continue;
      byTrack.putIfAbsent(tid, () => []).add(node);
    }

    for (final entry in byTrack.entries) {
      final trackNodes = entry.value
        ..sort((a, b) => a.post.createdAt.compareTo(b.post.createdAt));

      final color = trackNodes.first.post.trackDisplayColor;

      for (int i = 0; i < trackNodes.length - 1; i++) {
        final a = trackNodes[i];
        final b = trackNodes[i + 1];
        final dist = sqrt(
          pow(a.centerX - b.centerX, 2) + pow(a.centerY - b.centerY, 2),
        );
        if (dist > 500) continue;

        final opacity = min(0.08 + a.post.importance * 0.32, 0.4);
        final width = 0.8 + min(a.post.importance * 2.5, 2.5);

        final dy = b.centerY - a.centerY;
        final cx1 = a.centerX + (b.centerX - a.centerX) * 0.25 + dy * 0.15;
        final cy1 = a.centerY + (b.centerY - a.centerY) * 0.25;
        final cx2 = a.centerX + (b.centerX - a.centerX) * 0.75 - dy * 0.15;
        final cy2 = a.centerY + (b.centerY - a.centerY) * 0.75;

        connections.add(
          SynapseConnection(
            start: Offset(a.centerX, a.centerY),
            end: Offset(b.centerX, b.centerY),
            cp1: Offset(cx1, cy1),
            cp2: Offset(cx2, cy2),
            color: color,
            opacity: opacity,
            strokeWidth: width,
          ),
        );
      }
    }

    return connections;
  }
}

class _DaySlot {
  final double top;
  final double height;
  const _DaySlot({required this.top, required this.height});
}

class _DayCompact {
  final double newTop;
  final double newHeight;
  final double shift;
  const _DayCompact({
    required this.newTop,
    required this.newHeight,
    required this.shift,
  });
}

class _PlacedItem {
  final double x;
  double y;
  final double w;
  final double h;
  final Post post;
  final int day;
  _PlacedItem({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.post,
    required this.day,
  });
}
