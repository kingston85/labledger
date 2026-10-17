import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/expr.dart';
import '../theme/app_theme.dart';

/// Something to draw on a [PlotView].
abstract class Series {
  final Color color;
  final String? label;
  const Series(this.color, this.label);
}

class FnSeries extends Series {
  final double Function(double) f;
  final double strokeWidth;
  const FnSeries(this.f, Color color, {String? label, this.strokeWidth = 2.4}) : super(color, label);
}

class PointSeries extends Series {
  final List<Offset> points;
  final bool line;
  final bool dots;
  final double dotRadius;
  final double strokeWidth;
  final bool dashed;
  const PointSeries(this.points, Color color,
      {String? label, this.line = true, this.dots = false, this.dotRadius = 3.5, this.strokeWidth = 2.2, this.dashed = false})
      : super(color, label);
}

/// Shaded area under f between a and b (for integration).
class AreaSeries extends Series {
  final double Function(double) f;
  final double a, b;
  const AreaSeries(this.f, this.a, this.b, Color color) : super(color, null);
}

/// Vertical marker lines.
class VLineSeries extends Series {
  final List<double> xs;
  const VLineSeries(this.xs, Color color, {String? label}) : super(color, label);
}

/// Labelled markers (roots, extrema, chosen points).
class MarkerSeries extends Series {
  final List<Offset> points;
  const MarkerSeries(this.points, Color color, {String? label}) : super(color, label);
}

class Viewport {
  final double x0, x1, y0, y1;
  const Viewport(this.x0, this.x1, this.y0, this.y1);
  double get w => x1 - x0;
  double get h => y1 - y0;
}

/// Interactive plot: pinch to zoom, drag to pan, double-tap to reset,
/// tap to trace values.
class PlotView extends StatefulWidget {
  final List<Series> series;
  final double? xMin, xMax, yMin, yMax;
  final double height;
  final String? xLabel, yLabel;
  final bool logY;
  final bool equalAspect;

  const PlotView({
    super.key,
    required this.series,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
    this.height = 280,
    this.xLabel,
    this.yLabel,
    this.logY = false,
    this.equalAspect = false,
  });

  @override
  State<PlotView> createState() => _PlotViewState();
}

class _PlotViewState extends State<PlotView> {
  Viewport? _view;
  Viewport? _start;
  Offset? _focal;
  double? _traceX;
  Size _size = Size.zero;

  @override
  void didUpdateWidget(covariant PlotView old) {
    super.didUpdateWidget(old);
    if (old.xMin != widget.xMin ||
        old.xMax != widget.xMax ||
        old.yMin != widget.yMin ||
        old.yMax != widget.yMax ||
        old.series.length != widget.series.length ||
        !identical(old.series, widget.series)) {
      _view = null;
    }
  }

  double _ty(double y) => widget.logY ? (y > 0 ? math.log(y) / math.ln10 : double.nan) : y;

  Viewport _auto() {
    final double? xMinIn = widget.xMin, xMaxIn = widget.xMax;
    final xs = <double>[];
    final ys = <double>[];
    for (final s in widget.series) {
      if (s is PointSeries) {
        for (final p in s.points) {
          if (p.dx.isFinite) xs.add(p.dx);
          final ty = _ty(p.dy);
          if (ty.isFinite) ys.add(ty);
        }
      } else if (s is MarkerSeries) {
        for (final p in s.points) {
          if (p.dx.isFinite) xs.add(p.dx);
          final ty = _ty(p.dy);
          if (ty.isFinite) ys.add(ty);
        }
      } else if (s is VLineSeries) {
        xs.addAll(s.xs.where((v) => v.isFinite));
      }
    }
    double x0, x1;
    if (xs.isNotEmpty) {
      final lo = xs.reduce(math.min), hi = xs.reduce(math.max);
      final pad = (hi - lo) == 0 ? 1.0 : (hi - lo) * 0.08;
      x0 = xMinIn ?? lo - pad;
      x1 = xMaxIn ?? hi + pad;
    } else {
      x0 = xMinIn ?? -10;
      x1 = xMaxIn ?? 10;
    }
    if (x1 <= x0) x1 = x0 + 1;
    // Sample functions for y range, using robust percentiles to ignore poles.
    final fy = <double>[];
    for (final s in widget.series) {
      if (s is FnSeries || s is AreaSeries) {
        final f = s is FnSeries ? s.f : (s as AreaSeries).f;
        for (var i = 0; i <= 200; i++) {
          final x = x0 + (x1 - x0) * i / 200;
          final y = _ty(_safe(f, x));
          if (y.isFinite) fy.add(y);
        }
      }
    }
    if (fy.isNotEmpty) {
      fy.sort();
      final lo = fy[(fy.length * 0.02).floor()];
      final hi = fy[((fy.length - 1) * 0.98).ceil()];
      ys
        ..add(lo)
        ..add(hi);
    }
    for (final s in widget.series) {
      if (s is AreaSeries) ys.add(0);
    }
    double y0, y1;
    if (ys.isEmpty) {
      y0 = -10;
      y1 = 10;
    } else {
      y0 = ys.reduce(math.min);
      y1 = ys.reduce(math.max);
      if (y1 - y0 < 1e-12) {
        y0 -= 1;
        y1 += 1;
      }
      final pad = (y1 - y0) * 0.1;
      y0 -= pad;
      y1 += pad;
    }
    if (widget.yMin != null) y0 = _ty(widget.yMin!);
    if (widget.yMax != null) y1 = _ty(widget.yMax!);
    if (widget.equalAspect && _size.width > 0) {
      final wpx = _size.width - 52, hpx = widget.height - 34;
      final sx = (x1 - x0) / wpx, sy = (y1 - y0) / hpx;
      if (sx > sy) {
        final c = (y0 + y1) / 2, half = sx * hpx / 2;
        y0 = c - half;
        y1 = c + half;
      } else {
        final c = (x0 + x1) / 2, half = sy * wpx / 2;
        x0 = c - half;
        x1 = c + half;
      }
    }
    return Viewport(x0, x1, y0, y1);
  }

  static double _safe(double Function(double) f, double x) {
    try {
      return f(x);
    } catch (_) {
      return double.nan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return LayoutBuilder(builder: (context, box) {
      _size = Size(box.maxWidth, widget.height);
      final view = _view ?? _auto();
      final plotRect = Rect.fromLTWH(46, 8, box.maxWidth - 52, widget.height - 34);
      return SizedBox(
        height: widget.height,
        child: GestureDetector(
          onScaleStart: (d) {
            _start = view;
            _focal = d.localFocalPoint;
          },
          onScaleUpdate: (d) {
            final s0 = _start;
            final f0 = _focal;
            if (s0 == null || f0 == null) return;
            final scale = d.scale.clamp(0.05, 20.0).toDouble();
            // Focal point in data space at gesture start.
            final fx = s0.x0 + (f0.dx - plotRect.left) / plotRect.width * s0.w;
            final fy = s0.y1 - (f0.dy - plotRect.top) / plotRect.height * s0.h;
            final nw = s0.w / scale, nh = s0.h / scale;
            final dx = (d.localFocalPoint.dx - f0.dx) / plotRect.width * nw;
            final dy = (d.localFocalPoint.dy - f0.dy) / plotRect.height * nh;
            final rx = (fx - s0.x0) / s0.w, ry = (fy - s0.y0) / s0.h;
            final x0 = fx - rx * nw - dx;
            final y0 = fy - ry * nh + dy;
            setState(() => _view = Viewport(x0, x0 + nw, y0, y0 + nh));
          },
          onDoubleTap: () => setState(() {
            _view = null;
            _traceX = null;
          }),
          onTapUp: (d) {
            final x = view.x0 + (d.localPosition.dx - plotRect.left) / plotRect.width * view.w;
            setState(() => _traceX = _traceX != null && (x - _traceX!).abs() < view.w * 0.02 ? null : x);
          },
          child: CustomPaint(
            size: Size(box.maxWidth, widget.height),
            painter: _PlotPainter(
              series: widget.series,
              view: view,
              rect: plotRect,
              colors: c,
              logY: widget.logY,
              traceX: _traceX,
              xLabel: widget.xLabel,
              yLabel: widget.yLabel,
            ),
          ),
        ),
      );
    });
  }
}

class _PlotPainter extends CustomPainter {
  final List<Series> series;
  final Viewport view;
  final Rect rect;
  final LBColors colors;
  final bool logY;
  final double? traceX;
  final String? xLabel, yLabel;

  _PlotPainter({
    required this.series,
    required this.view,
    required this.rect,
    required this.colors,
    required this.logY,
    required this.traceX,
    this.xLabel,
    this.yLabel,
  });

  double _ty(double y) => logY ? (y > 0 ? math.log(y) / math.ln10 : double.nan) : y;
  double px(double x) => rect.left + (x - view.x0) / view.w * rect.width;
  double py(double y) => rect.bottom - (_ty(y) - view.y0) / view.h * rect.height;
  double pyRaw(double ty) => rect.bottom - (ty - view.y0) / view.h * rect.height;

  static List<double> ticks(double lo, double hi, int target) {
    final span = hi - lo;
    if (span <= 0 || !span.isFinite) return [];
    final raw = span / target;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final double step = (norm < 1.5 ? 1.0 : norm < 3 ? 2.0 : norm < 7 ? 5.0 : 10.0) * mag;
    final out = <double>[];
    var v = (lo / step).ceilToDouble() * step;
    while (v <= hi + step * 1e-9) {
      out.add(v.abs() < step * 1e-9 ? 0 : v);
      v += step;
    }
    return out;
  }

  String _tick(double v) {
    final s = fmt(v, sig: 4);
    return s;
  }

  void _text(Canvas canvas, String s, Offset at, {Color? color, double size = 10, TextAlign align = TextAlign.left, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color ?? colors.inkDim,
          fontSize: size,
          fontFamily: LBText.mono,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (align == TextAlign.right) dx -= tp.width;
    if (align == TextAlign.center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colors.line.withOpacity(0.55)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = colors.inkDim.withOpacity(0.8)
      ..strokeWidth = 1.2;

    // Background
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = colors.surface2.withOpacity(0.35));

    canvas.save();
    canvas.clipRect(rect);

    // Grid
    for (final t in ticks(view.x0, view.x1, 6)) {
      canvas.drawLine(Offset(px(t), rect.top), Offset(px(t), rect.bottom), grid);
    }
    final yt = logY ? _logTicks() : ticks(view.y0, view.y1, 5);
    for (final t in yt) {
      final y = logY ? pyRaw(t) : py(t);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    // Axes through zero
    if (view.x0 < 0 && view.x1 > 0) canvas.drawLine(Offset(px(0), rect.top), Offset(px(0), rect.bottom), axis);
    if (!logY && view.y0 < 0 && view.y1 > 0) canvas.drawLine(Offset(rect.left, py(0)), Offset(rect.right, py(0)), axis);

    for (final s in series) {
      if (s is AreaSeries) _area(canvas, s);
    }
    for (final s in series) {
      if (s is VLineSeries) {
        final p = Paint()
          ..color = s.color.withOpacity(0.6)
          ..strokeWidth = 1.2;
        for (final x in s.xs) {
          _dashedLine(canvas, Offset(px(x), rect.top), Offset(px(x), rect.bottom), p);
        }
      }
    }
    for (final s in series) {
      if (s is FnSeries) _fn(canvas, s);
      if (s is PointSeries) _points(canvas, s);
    }
    for (final s in series) {
      if (s is MarkerSeries) {
        for (final p in s.points) {
          final o = Offset(px(p.dx), py(p.dy));
          if (!o.dx.isFinite || !o.dy.isFinite) continue;
          canvas.drawCircle(o, 6.5, Paint()..color = colors.bg);
          canvas.drawCircle(
              o,
              6.5,
              Paint()
                ..color = s.color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.4);
          canvas.drawCircle(o, 2.4, Paint()..color = s.color);
        }
      }
    }

    // Trace
    if (traceX != null) {
      final x = traceX!;
      final tp = Paint()
        ..color = colors.ink.withOpacity(0.5)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(px(x), rect.top), Offset(px(x), rect.bottom), tp);
      var row = 0;
      _text(canvas, 'x = ${fmt(x, sig: 6)}', Offset(rect.left + 8, rect.top + 12), color: colors.ink, size: 10.5, bold: true);
      for (final s in series) {
        if (s is FnSeries) {
          final y = _PlotViewState._safe(s.f, x);
          if (!y.isFinite) continue;
          row++;
          canvas.drawCircle(Offset(px(x), py(y)), 4, Paint()..color = s.color);
          _text(canvas, '${s.label ?? 'y'} = ${fmt(y, sig: 6)}', Offset(rect.left + 8, rect.top + 12 + 14.0 * row),
              color: s.color, size: 10.5, bold: true);
        }
      }
    }
    canvas.restore();

    // Tick labels
    for (final t in ticks(view.x0, view.x1, 6)) {
      _text(canvas, _tick(t), Offset(px(t), rect.bottom + 12), align: TextAlign.center);
    }
    for (final t in yt) {
      final y = logY ? pyRaw(t) : py(t);
      if (y < rect.top - 2 || y > rect.bottom + 2) continue;
      _text(canvas, logY ? '10${_supStr(t.round())}' : _tick(t), Offset(rect.left - 6, y), align: TextAlign.right);
    }
    if (xLabel != null) _text(canvas, xLabel!, Offset(rect.right, rect.bottom + 24), align: TextAlign.right, size: 9.5);
    if (yLabel != null) _text(canvas, yLabel!, Offset(rect.left + 6, rect.top + 8), size: 9.5);
  }

  List<double> _logTicks() {
    final out = <double>[];
    for (var e = view.y0.floor(); e <= view.y1.ceil(); e++) {
      out.add(e.toDouble());
    }
    return out;
  }

  String _supStr(int n) {
    const d = '⁰¹²³⁴⁵⁶⁷⁸⁹';
    final s = n.abs().toString().split('').map((c) => d[int.parse(c)]).join();
    return n < 0 ? '⁻$s' : s;
  }

  void _fn(Canvas canvas, FnSeries s) {
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path();
    var pen = false;
    final n = rect.width.round() * 2;
    double? lastY;
    for (var i = 0; i <= n; i++) {
      final x = view.x0 + view.w * i / n;
      final y = _PlotViewState._safe(s.f, x);
      final sy = py(y);
      if (!sy.isFinite || (sy - rect.center.dy).abs() > rect.height * 20) {
        pen = false;
        lastY = null;
        continue;
      }
      // Break the line across poles (huge jumps).
      if (pen && lastY != null && (sy - lastY).abs() > rect.height * 3) pen = false;
      if (pen) {
        path.lineTo(px(x), sy);
      } else {
        path.moveTo(px(x), sy);
        pen = true;
      }
      lastY = sy;
    }
    canvas.drawPath(path, paint);
  }

  void _points(Canvas canvas, PointSeries s) {
    final pts = [for (final p in s.points) Offset(px(p.dx), py(p.dy))].where((o) => o.dx.isFinite && o.dy.isFinite).toList();
    if (s.line && pts.length >= 2) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      if (s.dashed) {
        for (var i = 0; i < pts.length - 1; i++) {
          _dashedLine(canvas, pts[i], pts[i + 1], paint);
        }
      } else {
        final path = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (final o in pts.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    if (s.dots) {
      for (final o in pts) {
        canvas.drawCircle(o, s.dotRadius + 1.5, Paint()..color = colors.bg);
        canvas.drawCircle(o, s.dotRadius, Paint()..color = s.color);
      }
    }
  }

  void _area(Canvas canvas, AreaSeries s) {
    final a = math.min(s.a, s.b), b = math.max(s.a, s.b);
    final path = Path()..moveTo(px(a), py(0));
    const n = 300;
    for (var i = 0; i <= n; i++) {
      final x = a + (b - a) * i / n;
      final y = _PlotViewState._safe(s.f, x);
      path.lineTo(px(x), y.isFinite ? py(y) : py(0));
    }
    path
      ..lineTo(px(b), py(0))
      ..close();
    canvas.drawPath(path, Paint()..color = s.color.withOpacity(0.22));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint p) {
    final d = (b - a).distance;
    if (d == 0) return;
    final dir = (b - a) / d;
    var t = 0.0;
    while (t < d) {
      final e = math.min(t + 6, d);
      canvas.drawLine(a + dir * t, a + dir * e, p);
      t += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) => true;
}

/// Small colour legend under a plot.
class PlotLegend extends StatelessWidget {
  final List<Series> series;
  const PlotLegend(this.series, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final items = series.where((s) => s.label != null).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final s in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 4, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                Text(s.label!, style: LBText.body(c.inkDim, size: 12)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Standard series colours that read on both themes.
const seriesColors = <Color>[
  Color(0xFF2DD4BF),
  Color(0xFFFFB020),
  Color(0xFF8B9CFF),
  Color(0xFFFF6B8B),
  Color(0xFF6FD36F),
  Color(0xFFE38BFF),
];
