import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Vertical bar chart with optional second (stacked) series and value labels.
class BarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final List<double>? stacked; // drawn on top of [values]
  final Color color;
  final Color? stackColor;
  final double height;
  final String Function(double)? format;
  const BarChart({super.key, required this.labels, required this.values, this.stacked, required this.color, this.stackColor, this.height = 180, this.format});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarPainter(labels, values, stacked, color, stackColor ?? c.poor, c.inkDim, c.line, format ?? (v) => v.round().toString()),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<double>? stacked;
  final Color color, stackColor, label, grid;
  final String Function(double) fmt;
  _BarPainter(this.labels, this.values, this.stacked, this.color, this.stackColor, this.label, this.grid, this.fmt);

  @override
  void paint(Canvas canvas, Size s) {
    if (values.isEmpty) return;
    const bottom = 20.0, top = 16.0;
    final n = values.length;
    final maxV = [for (var i = 0; i < n; i++) values[i] + (stacked?[i] ?? 0)].fold<double>(0, math.max);
    final h = s.height - bottom - top;
    final slot = s.width / n;
    final bw = math.min(34.0, slot * 0.62);
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 0.6;
    for (var k = 0; k <= 3; k++) {
      final y = top + h * k / 3;
      canvas.drawLine(Offset(0, y), Offset(s.width, y), gp);
    }
    for (var i = 0; i < n; i++) {
      final x = slot * i + (slot - bw) / 2;
      final v = values[i];
      final st = stacked?[i] ?? 0;
      final hv = maxV == 0 ? 0.0 : h * v / maxV;
      final hs = maxV == 0 ? 0.0 : h * st / maxV;
      final r1 = RRect.fromRectAndCorners(Rect.fromLTWH(x, top + h - hv, bw, hv), topLeft: Radius.circular(st > 0 ? 0 : 5), topRight: Radius.circular(st > 0 ? 0 : 5));
      canvas.drawRRect(r1, Paint()..color = color);
      if (st > 0) {
        canvas.drawRRect(
            RRect.fromRectAndCorners(Rect.fromLTWH(x, top + h - hv - hs, bw, hs), topLeft: const Radius.circular(5), topRight: const Radius.circular(5)),
            Paint()..color = stackColor);
      }
      final total = v + st;
      if (total > 0) {
        final tp = TextPainter(text: TextSpan(text: fmt(total), style: TextStyle(fontSize: 9.5, color: label, fontFamily: LBText.mono)), textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, Offset(x + bw / 2 - tp.width / 2, top + h - hv - hs - tp.height - 1));
      }
      if (n <= 16 || i % 2 == 0) {
        final lp = TextPainter(
            text: TextSpan(text: labels[i], style: TextStyle(fontSize: 9.5, color: label)), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')
          ..layout(maxWidth: slot + 6);
        lp.paint(canvas, Offset(slot * i + slot / 2 - lp.width / 2, s.height - bottom + 5));
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter o) => true;
}

class LineSeries {
  final List<double?> values; // null = gap
  final Color color;
  final String label;
  final bool dashed;
  const LineSeries(this.values, this.color, this.label, {this.dashed = false});
}

/// Simple multi-series line chart over categorical x labels.
class LineChart extends StatelessWidget {
  final List<String> labels;
  final List<LineSeries> series;
  final double height;
  final double? minY, maxY;
  final String Function(double)? format;
  final List<(double, Color, String)> refLines; // horizontal reference lines
  const LineChart({super.key, required this.labels, required this.series, this.height = 200, this.minY, this.maxY, this.format, this.refLines = const []});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(labels, series, minY, maxY, format ?? (v) => v.toStringAsFixed(v.abs() >= 10 ? 0 : 2), c.inkDim, c.line, refLines),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (final s in [...series.map((e) => (e.color, e.label)), ...refLines.map((r) => (r.$2, r.$3))])
          if (s.$2.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 3, color: s.$1),
              const SizedBox(width: 5),
              Text(s.$2, style: LBText.body(c.inkDim, size: 11)),
            ]),
      ]),
    ]);
  }
}

class _LinePainter extends CustomPainter {
  final List<String> labels;
  final List<LineSeries> series;
  final double? minY, maxY;
  final String Function(double) fmt;
  final Color label, grid;
  final List<(double, Color, String)> refs;
  _LinePainter(this.labels, this.series, this.minY, this.maxY, this.fmt, this.label, this.grid, this.refs);

  @override
  void paint(Canvas canvas, Size s) {
    const left = 38.0, bottom = 20.0, top = 8.0, right = 8.0;
    final all = [for (final se in series) ...se.values.whereType<double>(), ...refs.map((r) => r.$1)];
    if (all.isEmpty || labels.isEmpty) return;
    var lo = minY ?? all.reduce(math.min), hi = maxY ?? all.reduce(math.max);
    if (hi == lo) {
      hi += 1;
      lo -= minY == null ? 1 : 0;
    }
    final pad = (hi - lo) * 0.08;
    if (maxY == null) hi += pad;
    if (minY == null) lo -= pad;
    final w = s.width - left - right, h = s.height - top - bottom;
    double x(int i) => left + (labels.length <= 1 ? w / 2 : w * i / (labels.length - 1));
    double y(double v) => top + h - (v - lo) / (hi - lo) * h;
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 0.6;
    for (var k = 0; k <= 4; k++) {
      final v = lo + (hi - lo) * k / 4;
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), gp);
      final tp = TextPainter(text: TextSpan(text: fmt(v), style: TextStyle(fontSize: 9, color: label, fontFamily: LBText.mono)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(left - tp.width - 4, y(v) - tp.height / 2));
    }
    final step = math.max(1, (labels.length / 8).ceil());
    for (var i = 0; i < labels.length; i += step) {
      final tp = TextPainter(text: TextSpan(text: labels[i], style: TextStyle(fontSize: 9, color: label)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x(i) - tp.width / 2, s.height - bottom + 5));
    }
    for (final r in refs) {
      final p = Paint()
        ..color = r.$2
        ..strokeWidth = 1.4;
      for (var xx = left; xx < left + w; xx += 8) {
        canvas.drawLine(Offset(xx, y(r.$1)), Offset(math.min(xx + 4, left + w), y(r.$1)), p);
      }
    }
    for (final se in series) {
      final p = Paint()
        ..color = se.color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      Path? path;
      for (var i = 0; i < se.values.length && i < labels.length; i++) {
        final v = se.values[i];
        if (v == null) {
          if (path != null) canvas.drawPath(path, p);
          path = null;
          continue;
        }
        final o = Offset(x(i), y(v));
        if (path == null) {
          path = Path()..moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawCircle(o, 3, Paint()..color = se.color);
      }
      if (path != null) canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) => true;
}

/// Donut chart with a centre label.
class DonutChart extends StatelessWidget {
  final List<(String, double, Color)> segments;
  final String centre;
  final String centreSub;
  final double size;
  const DonutChart({super.key, required this.segments, this.centre = '', this.centreSub = '', this.size = 150});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final total = segments.fold<double>(0, (a, s) => a + s.$2);
    return Row(children: [
      SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size(size, size), painter: _DonutPainter(segments, c.surface2)),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(centre, style: LBText.reading(size * 0.16, c.ink, weight: FontWeight.w700)),
            if (centreSub.isNotEmpty) Text(centreSub, style: LBText.body(c.inkDim, size: 10.5)),
          ]),
        ]),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          for (final s in segments.where((s) => s.$2 > 0))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(s.$1, style: LBText.body(c.ink, size: 12.5), overflow: TextOverflow.ellipsis)),
                Text('${s.$2.round()}', style: LBText.reading(12, c.ink, weight: FontWeight.w700)),
                SizedBox(width: 44, child: Text(total == 0 ? '' : '${(s.$2 / total * 100).round()}%', textAlign: TextAlign.right, style: LBText.reading(11, c.inkDim))),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final List<(String, double, Color)> segs;
  final Color empty;
  _DonutPainter(this.segs, this.empty);

  @override
  void paint(Canvas canvas, Size s) {
    final total = segs.fold<double>(0, (a, e) => a + e.$2);
    final r = Rect.fromLTWH(10, 10, s.width - 20, s.height - 20);
    final stroke = s.width * 0.13;
    if (total <= 0) {
      canvas.drawArc(r, 0, math.pi * 2, false, Paint()
        ..color = empty
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke);
      return;
    }
    var a = -math.pi / 2;
    for (final e in segs) {
      if (e.$2 <= 0) continue;
      final sweep = e.$2 / total * math.pi * 2;
      canvas.drawArc(r, a + 0.015, math.max(0.0, sweep - 0.03), false, Paint()
        ..color = e.$3
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke);
      a += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => true;
}

/// Horizontal bars with labels (ranked lists).
class HBarList extends StatelessWidget {
  final List<(String, double, String)> items; // label, value, trailing text
  final Color color;
  const HBarList({super.key, required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final maxV = items.fold<double>(0, (a, e) => math.max(a, e.$2));
    return Column(children: [
      for (final e in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 130, child: Text(e.$1, style: LBText.body(c.ink, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 10,
                    width: maxV == 0 ? 2 : math.max(2, box.maxWidth * e.$2 / maxV),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
                  ),
                ),
              ),
            ),
            SizedBox(width: 64, child: Text(e.$3, textAlign: TextAlign.right, style: LBText.reading(11.5, c.ink))),
          ]),
        ),
    ]);
  }
}

/// Tiny inline trend line for KPI tiles.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const Sparkline(this.values, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(height: 28, child: CustomPaint(size: Size.infinite, painter: _SparkPainter(values, color)));
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  _SparkPainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    if (v.length < 2) return;
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final span = hi == lo ? 1 : hi - lo;
    final path = Path();
    final fill = Path()..moveTo(0, s.height);
    for (var i = 0; i < v.length; i++) {
      final o = Offset(s.width * i / (v.length - 1), s.height - (v[i] - lo) / span * (s.height - 4) - 2);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      fill.lineTo(o.dx, o.dy);
    }
    fill
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withOpacity(0.15));
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_SparkPainter o) => true;
}
