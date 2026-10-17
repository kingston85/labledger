// Linear algebra with step-by-step records for teaching.

import 'dart:math' as math;

typedef Mat = List<List<double>>;
typedef Vec = List<double>;

Mat copyMat(Mat a) => [for (final r in a) List<double>.from(r)];
Mat identity(int n) => [for (var i = 0; i < n; i++) [for (var j = 0; j < n; j++) i == j ? 1.0 : 0.0]];

Vec matVec(Mat a, Vec x) => [
      for (final r in a) [for (var j = 0; j < x.length; j++) r[j] * x[j]].fold(0.0, (s, v) => s + v),
    ];

Mat matMul(Mat a, Mat b) {
  final n = a.length, m = b[0].length, k = b.length;
  return [
    for (var i = 0; i < n; i++)
      [for (var j = 0; j < m; j++) [for (var t = 0; t < k; t++) a[i][t] * b[t][j]].fold(0.0, (s, v) => s + v)],
  ];
}

double normInf(Vec v) => v.fold(0.0, (m, x) => math.max(m, x.abs()));
double matNormInf(Mat a) => a.fold(0.0, (m, r) => math.max(m, r.fold(0.0, (s, x) => s + x.abs())));

class LinStep {
  final String text;
  final Mat matrix; // augmented snapshot
  final int? pivotRow;
  final int? pivotCol;
  const LinStep(this.text, this.matrix, {this.pivotRow, this.pivotCol});
}

class LinError implements Exception {
  final String message;
  LinError(this.message);
  @override
  String toString() => message;
}

class GaussResult {
  final Vec x;
  final double det;
  final List<LinStep> steps;
  const GaussResult(this.x, this.det, this.steps);
}

class LUResult {
  final Mat l;
  final Mat u;
  final List<int> perm; // row i of PA is row perm[i] of A
  final Vec? x;
  final Vec? d; // forward substitution result
  final double det;
  const LUResult(this.l, this.u, this.perm, this.x, this.d, this.det);
}

class IterSolveResult {
  final Vec x;
  final int iterations;
  final bool converged;
  final List<List<double>> history; // per iteration: x values then max ea%
  final bool diagonallyDominant;
  final String message;
  const IterSolveResult(this.x, this.iterations, this.converged, this.history, this.diagonallyDominant, this.message);
}

class LinAlg {
  LinAlg._();

  static const double _tiny = 1e-12;

  /// Gauss elimination with partial pivoting and back substitution.
  static GaussResult gauss(Mat a, Vec b, {bool pivot = true}) {
    final n = a.length;
    final m = [for (var i = 0; i < n; i++) [...a[i], b[i]]];
    final steps = <LinStep>[LinStep('Augmented matrix [A | b]', copyMat(m))];
    var swaps = 0;
    for (var k = 0; k < n - 1; k++) {
      if (pivot) {
        var p = k;
        for (var i = k + 1; i < n; i++) {
          if (m[i][k].abs() > m[p][k].abs()) p = i;
        }
        if (p != k) {
          final t = m[k];
          m[k] = m[p];
          m[p] = t;
          swaps++;
          steps.add(LinStep('Pivot: swap R${k + 1} ↔ R${p + 1} (largest |a| in column ${k + 1})', copyMat(m),
              pivotRow: k, pivotCol: k));
        }
      }
      if (m[k][k].abs() < _tiny) throw LinError('Zero pivot in column ${k + 1}: the matrix is singular.');
      for (var i = k + 1; i < n; i++) {
        final f = m[i][k] / m[k][k];
        if (f == 0) continue;
        for (var j = k; j <= n; j++) {
          m[i][j] -= f * m[k][j];
        }
        m[i][k] = 0;
        steps.add(LinStep('R${i + 1} ← R${i + 1} − (${_s(f)}) × R${k + 1}', copyMat(m), pivotRow: k, pivotCol: k));
      }
    }
    if (m[n - 1][n - 1].abs() < _tiny) throw LinError('The matrix is singular (zero last pivot).');
    var det = swaps.isEven ? 1.0 : -1.0;
    for (var i = 0; i < n; i++) {
      det *= m[i][i];
    }
    final x = List<double>.filled(n, 0);
    for (var i = n - 1; i >= 0; i--) {
      var s = m[i][n];
      for (var j = i + 1; j < n; j++) {
        s -= m[i][j] * x[j];
      }
      x[i] = s / m[i][i];
    }
    steps.add(LinStep('Back substitution: x${n} = ${_s(x[n - 1])}, … , x1 = ${_s(x[0])}', copyMat(m)));
    return GaussResult(x, det, steps);
  }

  /// LU decomposition (Doolittle) with partial pivoting: PA = LU.
  static LUResult lu(Mat a, [Vec? b]) {
    final n = a.length;
    final u = copyMat(a);
    final l = identity(n);
    final perm = [for (var i = 0; i < n; i++) i];
    var swaps = 0;
    for (var k = 0; k < n; k++) {
      var p = k;
      for (var i = k + 1; i < n; i++) {
        if (u[i][k].abs() > u[p][k].abs()) p = i;
      }
      if (u[p][k].abs() < _tiny) throw LinError('The matrix is singular.');
      if (p != k) {
        final t = u[k];
        u[k] = u[p];
        u[p] = t;
        final tp = perm[k];
        perm[k] = perm[p];
        perm[p] = tp;
        for (var j = 0; j < k; j++) {
          final tl = l[k][j];
          l[k][j] = l[p][j];
          l[p][j] = tl;
        }
        swaps++;
      }
      for (var i = k + 1; i < n; i++) {
        final f = u[i][k] / u[k][k];
        l[i][k] = f;
        for (var j = k; j < n; j++) {
          u[i][j] -= f * u[k][j];
        }
        u[i][k] = 0;
      }
    }
    var det = swaps.isEven ? 1.0 : -1.0;
    for (var i = 0; i < n; i++) {
      det *= u[i][i];
    }
    Vec? x, d;
    if (b != null) {
      final pb = [for (final i in perm) b[i]];
      d = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        var s = pb[i];
        for (var j = 0; j < i; j++) {
          s -= l[i][j] * d[j];
        }
        d[i] = s;
      }
      x = List<double>.filled(n, 0);
      for (var i = n - 1; i >= 0; i--) {
        var s = d[i];
        for (var j = i + 1; j < n; j++) {
          s -= u[i][j] * x[j];
        }
        x[i] = s / u[i][i];
      }
    }
    return LUResult(l, u, perm, x, d, det);
  }

  /// Inverse by Gauss-Jordan with partial pivoting.
  static Mat inverse(Mat a) {
    final n = a.length;
    final m = [for (var i = 0; i < n; i++) [...a[i], ...identity(n)[i]]];
    for (var k = 0; k < n; k++) {
      var p = k;
      for (var i = k + 1; i < n; i++) {
        if (m[i][k].abs() > m[p][k].abs()) p = i;
      }
      if (m[p][k].abs() < _tiny) throw LinError('The matrix is singular and has no inverse.');
      final t = m[k];
      m[k] = m[p];
      m[p] = t;
      final piv = m[k][k];
      for (var j = 0; j < 2 * n; j++) {
        m[k][j] /= piv;
      }
      for (var i = 0; i < n; i++) {
        if (i == k) continue;
        final f = m[i][k];
        if (f == 0) continue;
        for (var j = 0; j < 2 * n; j++) {
          m[i][j] -= f * m[k][j];
        }
      }
    }
    return [for (final r in m) r.sublist(n)];
  }

  static double det(Mat a) {
    try {
      return lu(a).det;
    } on LinError {
      return 0;
    }
  }

  /// Condition number in the infinity norm.
  static double cond(Mat a) {
    try {
      return matNormInf(a) * matNormInf(inverse(a));
    } on LinError {
      return double.infinity;
    }
  }

  static bool diagonallyDominant(Mat a) {
    for (var i = 0; i < a.length; i++) {
      var off = 0.0;
      for (var j = 0; j < a.length; j++) {
        if (j != i) off += a[i][j].abs();
      }
      if (a[i][i].abs() < off) return false;
    }
    return true;
  }

  /// Jacobi (seidel = false) or Gauss-Seidel (seidel = true) iteration.
  static IterSolveResult iterative(Mat a, Vec b,
      {bool seidel = true, double tolPercent = 1e-6, int maxIter = 200, double lambda = 1.0}) {
    final n = a.length;
    for (var i = 0; i < n; i++) {
      if (a[i][i].abs() < _tiny) {
        throw LinError('Zero on the diagonal (row ${i + 1}). Reorder the equations first.');
      }
    }
    final dd = diagonallyDominant(a);
    var x = List<double>.filled(n, 0);
    final history = <List<double>>[];
    for (var it = 1; it <= maxIter; it++) {
      final old = List<double>.from(x);
      final next = seidel ? x : List<double>.from(x);
      var maxEa = 0.0;
      for (var i = 0; i < n; i++) {
        var s = b[i];
        for (var j = 0; j < n; j++) {
          if (j != i) s -= a[i][j] * (seidel ? next[j] : old[j]);
        }
        final xi = s / a[i][i];
        next[i] = lambda * xi + (1 - lambda) * old[i];
        if (next[i] != 0) maxEa = math.max(maxEa, ((next[i] - old[i]) / next[i]).abs() * 100);
      }
      x = next;
      history.add([...x, maxEa]);
      if (!x.every((v) => v.isFinite)) {
        return IterSolveResult(x, it, false, history, dd, 'Iterations diverged. The system is not diagonally dominant.');
      }
      if (maxEa < tolPercent) {
        return IterSolveResult(x, it, true, history, dd, 'Converged in $it iterations.');
      }
    }
    return IterSolveResult(x, maxIter, false, history, dd,
        'Did not converge in $maxIter iterations.${dd ? '' : ' The matrix is not diagonally dominant.'}');
  }

  /// Dominant eigenvalue and eigenvector by the power method.
  static ({double value, Vec vector, int iterations, bool converged}) powerMethod(Mat a,
      {double tolPercent = 1e-8, int maxIter = 500}) {
    final n = a.length;
    var v = List<double>.filled(n, 1);
    var lambda = 0.0;
    for (var it = 1; it <= maxIter; it++) {
      final w = matVec(a, v);
      var big = 0.0;
      for (final x in w) {
        if (x.abs() > big.abs()) big = x;
      }
      if (big == 0) return (value: 0, vector: v, iterations: it, converged: true);
      v = [for (final x in w) x / big];
      final ea = big != 0 ? ((big - lambda) / big).abs() * 100 : 100.0;
      lambda = big;
      if (ea < tolPercent) return (value: lambda, vector: v, iterations: it, converged: true);
    }
    return (value: lambda, vector: v, iterations: maxIter, converged: false);
  }

  static Vec residual(Mat a, Vec x, Vec b) {
    final ax = matVec(a, x);
    return [for (var i = 0; i < b.length; i++) b[i] - ax[i]];
  }

  static String _s(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e9) return v.toStringAsFixed(0);
    final a = v.abs();
    if (a >= 1e5 || a < 1e-3) return v.toStringAsExponential(3);
    return v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '');
  }
}
