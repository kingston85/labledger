// Calibration curve fitting with LOD/LOQ and acceptance checks.

import 'dart:math' as math;

class CalFit {
  final double slope;
  final double intercept;
  final double r2;
  final double r;
  final double syx;
  final double lod;
  final double loq;
  final int n;
  final bool throughOrigin;
  const CalFit({
    required this.slope,
    required this.intercept,
    required this.r2,
    required this.r,
    required this.syx,
    required this.lod,
    required this.loq,
    required this.n,
    required this.throughOrigin,
  });

  double response(double conc) => intercept + slope * conc;

  /// Concentration in the measured solution for an instrument response.
  double conc(double response) => (response - intercept) / slope;

  String get equation {
    String f(double v) => v.abs() >= 1e4 || (v != 0 && v.abs() < 1e-3) ? v.toStringAsExponential(4) : v.toStringAsFixed(5);
    if (throughOrigin) return 'y = ${f(slope)} x';
    return 'y = ${f(slope)} x ${intercept < 0 ? '−' : '+'} ${f(intercept.abs())}';
  }
}

class CalError implements Exception {
  final String message;
  CalError(this.message);
  @override
  String toString() => message;
}

/// Least-squares calibration line. LOD = 3.3·sy/x/slope and LOQ = 10·sy/x/slope
/// (ICH Q2 approach using the residual standard deviation).
CalFit fitCalibration(List<List<double>> standards, {bool throughOrigin = false}) {
  final pts = standards.where((s) => s.length >= 2 && s[0].isFinite && s[1].isFinite).toList();
  final n = pts.length;
  if (n < (throughOrigin ? 2 : 3)) throw CalError('Enter at least ${throughOrigin ? 2 : 3} standards.');
  final x = [for (final p in pts) p[0]], y = [for (final p in pts) p[1]];
  final mx = x.reduce((a, b) => a + b) / n, my = y.reduce((a, b) => a + b) / n;
  double slope, intercept;
  if (throughOrigin) {
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += x[i] * y[i];
      sxx += x[i] * x[i];
    }
    if (sxx == 0) throw CalError('All standard concentrations are zero.');
    slope = sxy / sxx;
    intercept = 0;
  } else {
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (x[i] - mx) * (y[i] - my);
      sxx += (x[i] - mx) * (x[i] - mx);
    }
    if (sxx == 0) throw CalError('Standards need at least two different concentrations.');
    slope = sxy / sxx;
    intercept = my - slope * mx;
  }
  if (slope == 0) throw CalError('Slope is zero: the response does not change with concentration.');
  var ssr = 0.0, sst = 0.0;
  for (var i = 0; i < n; i++) {
    final e = y[i] - (intercept + slope * x[i]);
    ssr += e * e;
    sst += (y[i] - my) * (y[i] - my);
  }
  final dof = n - (throughOrigin ? 1 : 2);
  final syx = dof > 0 ? math.sqrt(ssr / dof) : 0.0;
  final r2 = sst == 0 ? 1.0 : 1 - ssr / sst;
  return CalFit(
    slope: slope,
    intercept: intercept,
    r2: r2,
    r: math.sqrt(math.max(0, r2)),
    syx: syx,
    lod: 3.3 * syx / slope.abs(),
    loq: 10 * syx / slope.abs(),
    n: n,
    throughOrigin: throughOrigin,
  );
}
