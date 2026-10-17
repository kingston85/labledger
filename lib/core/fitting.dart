// Least-squares regression and interpolation.

import 'dart:math' as math;

import 'linalg.dart';

enum FitModel { linear, polynomial, exponential, power, logarithmic, saturation }

extension FitModelX on FitModel {
  String get label {
    switch (this) {
      case FitModel.linear:
        return 'Linear';
      case FitModel.polynomial:
        return 'Polynomial';
      case FitModel.exponential:
        return 'Exponential';
      case FitModel.power:
        return 'Power';
      case FitModel.logarithmic:
        return 'Logarithmic';
      case FitModel.saturation:
        return 'Saturation growth';
    }
  }

  String get form {
    switch (this) {
      case FitModel.linear:
        return 'y = a₀ + a₁x';
      case FitModel.polynomial:
        return 'y = a₀ + a₁x + … + aₘxᵐ';
      case FitModel.exponential:
        return 'y = α e^(βx)';
      case FitModel.power:
        return 'y = α x^β';
      case FitModel.logarithmic:
        return 'y = a + b ln x';
      case FitModel.saturation:
        return 'y = α x / (β + x)';
    }
  }
}

class FitResult {
  final FitModel model;
  final List<double> coeffs; // model-specific
  final double r2;
  final double syx; // standard error of the estimate
  final double sst;
  final double ssr;
  final int n;
  final double Function(double x) predict;
  final String equation;
  final String? note;
  const FitResult({
    required this.model,
    required this.coeffs,
    required this.r2,
    required this.syx,
    required this.sst,
    required this.ssr,
    required this.n,
    required this.predict,
    required this.equation,
    this.note,
  });

  double get r => math.sqrt(math.max(0, r2));
}

class FitError implements Exception {
  final String message;
  FitError(this.message);
  @override
  String toString() => message;
}

String _c(double v) {
  final a = v.abs();
  if (a != 0 && (a >= 1e5 || a < 1e-3)) return v.toStringAsExponential(4);
  return v.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String _signed(double v) => v < 0 ? ' − ${_c(-v)}' : ' + ${_c(v)}';

class Fitting {
  Fitting._();

  /// Least-squares polynomial of [degree] via the normal equations solved
  /// with pivoted Gauss elimination on centred, scaled x for stability.
  static List<double> polyCoeffs(List<double> x, List<double> y, int degree) {
    final n = x.length;
    if (n <= degree) throw FitError('Need at least ${degree + 1} points for degree $degree.');
    final mean = x.reduce((a, b) => a + b) / n;
    final scale = x.map((v) => (v - mean).abs()).reduce(math.max);
    final s = scale == 0 ? 1.0 : scale;
    final u = [for (final v in x) (v - mean) / s];
    final m = degree + 1;
    final a = List.generate(m, (_) => List<double>.filled(m, 0));
    final b = List<double>.filled(m, 0);
    for (var k = 0; k < n; k++) {
      final pw = List<double>.filled(2 * m, 1);
      for (var p = 1; p < 2 * m; p++) {
        pw[p] = pw[p - 1] * u[k];
      }
      for (var i = 0; i < m; i++) {
        for (var j = 0; j < m; j++) {
          a[i][j] += pw[i + j];
        }
        b[i] += pw[i] * y[k];
      }
    }
    final c = LinAlg.gauss(a, b).x; // coefficients in u
    // Convert from u = (x − mean)/s back to powers of x.
    final out = List<double>.filled(m, 0);
    for (var i = 0; i < m; i++) {
      // c_i * ((x - mean)/s)^i expanded by the binomial theorem
      for (var j = 0; j <= i; j++) {
        out[j] += (c[i] * _binom(i, j) * math.pow(-mean, i - j) / math.pow(s, i)).toDouble();
      }
    }
    return out;
  }

  static double _binom(int n, int k) {
    var r = 1.0;
    for (var i = 1; i <= k; i++) {
      r = r * (n - k + i) / i;
    }
    return r;
  }

  static double polyEval(List<double> c, double x) {
    var r = 0.0;
    for (var i = c.length - 1; i >= 0; i--) {
      r = r * x + c[i];
    }
    return r;
  }

  static FitResult fit(FitModel model, List<double> x, List<double> y, {int degree = 2}) {
    if (x.length != y.length) throw FitError('x and y must have the same number of values.');
    if (x.length < 2) throw FitError('Need at least 2 points.');
    late List<double> coeffs;
    late double Function(double) f;
    late String eq;
    String? note;
    switch (model) {
      case FitModel.linear:
        coeffs = polyCoeffs(x, y, 1);
        f = (v) => coeffs[0] + coeffs[1] * v;
        eq = 'y = ${_c(coeffs[0])}${_signed(coeffs[1])}x';
        break;
      case FitModel.polynomial:
        coeffs = polyCoeffs(x, y, degree);
        f = (v) => polyEval(coeffs, v);
        final b = StringBuffer('y = ${_c(coeffs[0])}');
        for (var i = 1; i < coeffs.length; i++) {
          b.write('${_signed(coeffs[i])}x${i == 1 ? '' : _supInt(i)}');
        }
        eq = b.toString();
        break;
      case FitModel.exponential:
        if (y.any((v) => v <= 0)) throw FitError('Exponential fit needs all y > 0.');
        final lc = polyCoeffs(x, [for (final v in y) math.log(v)], 1);
        coeffs = [math.exp(lc[0]), lc[1]];
        f = (v) => coeffs[0] * math.exp(coeffs[1] * v);
        eq = 'y = ${_c(coeffs[0])} e^(${_c(coeffs[1])}x)';
        note = 'Fitted on ln y (linearised), as in the textbook method.';
        break;
      case FitModel.power:
        if (y.any((v) => v <= 0) || x.any((v) => v <= 0)) throw FitError('Power fit needs all x > 0 and y > 0.');
        final lc = polyCoeffs([for (final v in x) math.log(v) / math.ln10], [for (final v in y) math.log(v) / math.ln10], 1);
        coeffs = [math.pow(10, lc[0]).toDouble(), lc[1]];
        f = (v) => coeffs[0] * math.pow(v, coeffs[1]).toDouble();
        eq = 'y = ${_c(coeffs[0])} x^${_c(coeffs[1])}';
        note = 'Fitted on log y vs log x (linearised).';
        break;
      case FitModel.logarithmic:
        if (x.any((v) => v <= 0)) throw FitError('Logarithmic fit needs all x > 0.');
        final lc = polyCoeffs([for (final v in x) math.log(v)], y, 1);
        coeffs = lc;
        f = (v) => coeffs[0] + coeffs[1] * math.log(v);
        eq = 'y = ${_c(coeffs[0])}${_signed(coeffs[1])} ln x';
        break;
      case FitModel.saturation:
        if (y.any((v) => v == 0) || x.any((v) => v == 0)) throw FitError('Saturation fit needs x ≠ 0 and y ≠ 0.');
        // 1/y = 1/α + (β/α)(1/x)
        final lc = polyCoeffs([for (final v in x) 1 / v], [for (final v in y) 1 / v], 1);
        final alpha = 1 / lc[0];
        coeffs = [alpha, lc[1] * alpha];
        f = (v) => coeffs[0] * v / (coeffs[1] + v);
        eq = 'y = ${_c(coeffs[0])} x / (${_c(coeffs[1])} + x)';
        note = 'Fitted on 1/y vs 1/x (linearised).';
        break;
    }
    final n = x.length;
    final mean = y.reduce((a, b) => a + b) / n;
    var sst = 0.0, ssr = 0.0;
    for (var i = 0; i < n; i++) {
      sst += (y[i] - mean) * (y[i] - mean);
      final e = y[i] - f(x[i]);
      ssr += e * e;
    }
    final params = model == FitModel.polynomial ? degree + 1 : 2;
    final dof = n - params;
    return FitResult(
      model: model,
      coeffs: coeffs,
      r2: sst == 0 ? 1 : 1 - ssr / sst,
      syx: dof > 0 ? math.sqrt(ssr / dof) : double.nan,
      sst: sst,
      ssr: ssr,
      n: n,
      predict: f,
      equation: eq,
      note: note,
    );
  }

  // ---------------- Interpolation ----------------

  static double lagrange(List<double> x, List<double> y, double v) {
    var sum = 0.0;
    for (var i = 0; i < x.length; i++) {
      var term = y[i];
      for (var j = 0; j < x.length; j++) {
        if (j != i) term *= (v - x[j]) / (x[i] - x[j]);
      }
      sum += term;
    }
    return sum;
  }

  /// Newton divided-difference table: table[j][i] = f[x_i, …, x_{i+j}].
  static List<List<double>> dividedDifferences(List<double> x, List<double> y) {
    final n = x.length;
    final t = <List<double>>[List<double>.from(y)];
    for (var j = 1; j < n; j++) {
      final prev = t[j - 1];
      t.add([for (var i = 0; i < n - j; i++) (prev[i + 1] - prev[i]) / (x[i + j] - x[i])]);
    }
    return t;
  }

  static double newtonEval(List<double> x, List<List<double>> table, double v) {
    final n = x.length;
    var result = table[n - 1][0];
    for (var j = n - 2; j >= 0; j--) {
      result = result * (v - x[j]) + table[j][0];
    }
    return result;
  }

  /// Natural cubic spline. Returns second derivatives at the knots.
  static List<double> splineSecondDerivs(List<double> x, List<double> y) {
    final n = x.length;
    if (n < 3) return List<double>.filled(n, 0);
    final h = [for (var i = 0; i < n - 1; i++) x[i + 1] - x[i]];
    if (h.any((v) => v <= 0)) throw FitError('Spline needs x values in strictly increasing order.');
    // Tridiagonal system for interior second derivatives (Thomas algorithm).
    final m = n - 2;
    final a = List<double>.filled(m, 0), b = List<double>.filled(m, 0), c = List<double>.filled(m, 0), d = List<double>.filled(m, 0);
    for (var i = 0; i < m; i++) {
      final k = i + 1;
      a[i] = h[k - 1];
      b[i] = 2 * (h[k - 1] + h[k]);
      c[i] = h[k];
      d[i] = 6 * ((y[k + 1] - y[k]) / h[k] - (y[k] - y[k - 1]) / h[k - 1]);
    }
    for (var i = 1; i < m; i++) {
      final w = a[i] / b[i - 1];
      b[i] -= w * c[i - 1];
      d[i] -= w * d[i - 1];
    }
    final s = List<double>.filled(m, 0);
    s[m - 1] = d[m - 1] / b[m - 1];
    for (var i = m - 2; i >= 0; i--) {
      s[i] = (d[i] - c[i] * s[i + 1]) / b[i];
    }
    return [0.0, ...s, 0.0];
  }

  static double splineEval(List<double> x, List<double> y, List<double> m2, double v) {
    final n = x.length;
    var i = 0;
    if (v <= x.first) {
      i = 0;
    } else if (v >= x.last) {
      i = n - 2;
    } else {
      while (i < n - 2 && v > x[i + 1]) {
        i++;
      }
    }
    final h = x[i + 1] - x[i];
    final a = (x[i + 1] - v) / h;
    final b = (v - x[i]) / h;
    return a * y[i] + b * y[i + 1] + ((a * a * a - a) * m2[i] + (b * b * b - b) * m2[i + 1]) * h * h / 6;
  }

  static String _supInt(int n) {
    const d = '⁰¹²³⁴⁵⁶⁷⁸⁹';
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }
}
