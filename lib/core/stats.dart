// Statistics for lab data: descriptives, t-tests, one-way ANOVA, Grubbs'
// outlier test, with p-values from the t and F distributions.

import 'dart:math' as math;

double _lnGamma(double x) {
  // Lanczos approximation (g = 7, n = 9).
  const g = 7.0;
  const c = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  if (x < 0.5) {
    return math.log(math.pi / math.sin(math.pi * x)) - _lnGamma(1 - x);
  }
  final xx = x - 1;
  var a = c[0];
  final t = xx + g + 0.5;
  for (var i = 1; i < 9; i++) {
    a += c[i] / (xx + i);
  }
  return 0.5 * math.log(2 * math.pi) + (xx + 0.5) * math.log(t) - t + math.log(a);
}

double _betacf(double a, double b, double x) {
  const maxIt = 300;
  const eps = 3e-16;
  const fpmin = 1e-300;
  final qab = a + b, qap = a + 1, qam = a - 1;
  var c = 1.0;
  var d = 1 - qab * x / qap;
  if (d.abs() < fpmin) d = fpmin;
  d = 1 / d;
  var h = d;
  for (var m = 1; m <= maxIt; m++) {
    final m2 = 2 * m;
    var aa = m * (b - m) * x / ((qam + m2) * (a + m2));
    d = 1 + aa * d;
    if (d.abs() < fpmin) d = fpmin;
    c = 1 + aa / c;
    if (c.abs() < fpmin) c = fpmin;
    d = 1 / d;
    h *= d * c;
    aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    d = 1 + aa * d;
    if (d.abs() < fpmin) d = fpmin;
    c = 1 + aa / c;
    if (c.abs() < fpmin) c = fpmin;
    d = 1 / d;
    final del = d * c;
    h *= del;
    if ((del - 1).abs() < eps) break;
  }
  return h;
}

/// Regularised incomplete beta function I_x(a, b).
double incompleteBeta(double x, double a, double b) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  final bt = math.exp(_lnGamma(a + b) - _lnGamma(a) - _lnGamma(b) + a * math.log(x) + b * math.log(1 - x));
  if (x < (a + 1) / (a + b + 2)) return bt * _betacf(a, b, x) / a;
  return 1 - bt * _betacf(b, a, 1 - x) / b;
}

/// Two-sided p-value for Student's t with [df] degrees of freedom.
double tTwoSidedP(double t, double df) {
  if (!t.isFinite) return 0;
  return incompleteBeta(df / (df + t * t), df / 2, 0.5);
}

/// Cumulative distribution of Student's t.
double tCdf(double t, double df) {
  final p = 0.5 * incompleteBeta(df / (df + t * t), df / 2, 0.5);
  return t >= 0 ? 1 - p : p;
}

/// Upper-tail p-value of the F distribution, P(F > f).
double fUpperP(double f, double d1, double d2) {
  if (f <= 0) return 1;
  return incompleteBeta(d2 / (d2 + d1 * f), d2 / 2, d1 / 2);
}

/// Inverse of tCdf by bisection: returns t with P(T ≤ t) = p.
double tInv(double p, double df) {
  var lo = -1000.0, hi = 1000.0;
  for (var i = 0; i < 200; i++) {
    final mid = (lo + hi) / 2;
    if (tCdf(mid, df) < p) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

class Describe {
  final int n;
  final double mean, sd, median, min, max, rsd, se, ci95lo, ci95hi;
  const Describe(this.n, this.mean, this.sd, this.median, this.min, this.max, this.rsd, this.se, this.ci95lo, this.ci95hi);

  factory Describe.of(List<double> v) {
    final n = v.length;
    if (n == 0) {
      return const Describe(0, double.nan, double.nan, double.nan, double.nan, double.nan, double.nan, double.nan, double.nan, double.nan);
    }
    final s = [...v]..sort();
    final mean = v.reduce((a, b) => a + b) / n;
    final variance = n > 1 ? v.fold(0.0, (a, x) => a + (x - mean) * (x - mean)) / (n - 1) : 0.0;
    final sd = math.sqrt(variance);
    final median = n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
    final se = sd / math.sqrt(n);
    final tc = n > 1 ? tInv(0.975, n - 1.0) : double.nan;
    return Describe(n, mean, sd, median, s.first, s.last, mean != 0 ? sd / mean.abs() * 100 : double.nan, se,
        mean - tc * se, mean + tc * se);
  }
}

class TTest {
  final double t;
  final double df;
  final double p;
  final double meanDiff;
  final String test;
  const TTest(this.t, this.df, this.p, this.meanDiff, this.test);

  bool significant([double alpha = 0.05]) => p < alpha;
}

class AnovaResult {
  final double ssBetween, ssWithin, dfBetween, dfWithin, msBetween, msWithin, f, p;
  const AnovaResult(this.ssBetween, this.ssWithin, this.dfBetween, this.dfWithin, this.msBetween, this.msWithin, this.f, this.p);
}

class GrubbsResult {
  final double g;
  final double gCritical;
  final int index;
  final double value;
  const GrubbsResult(this.g, this.gCritical, this.index, this.value);
  bool get isOutlier => g > gCritical;
}

class Stats {
  Stats._();

  /// One-sample t-test of the mean against [mu0] (e.g. a regulatory limit).
  static TTest oneSample(List<double> v, double mu0) {
    final d = Describe.of(v);
    if (d.n < 2 || d.sd == 0) return TTest(double.nan, d.n - 1.0, double.nan, d.mean - mu0, 'One-sample t');
    final t = (d.mean - mu0) / d.se;
    return TTest(t, d.n - 1.0, tTwoSidedP(t, d.n - 1.0), d.mean - mu0, 'One-sample t');
  }

  /// One-sided p-value that the true mean exceeds [mu0].
  static double pMeanAbove(List<double> v, double mu0) {
    final r = oneSample(v, mu0);
    if (!r.t.isFinite) return double.nan;
    return 1 - tCdf(r.t, r.df);
  }

  /// Welch's two-sample t-test (unequal variances).
  static TTest welch(List<double> a, List<double> b) {
    final da = Describe.of(a), db = Describe.of(b);
    final va = da.sd * da.sd / da.n, vb = db.sd * db.sd / db.n;
    if (da.n < 2 || db.n < 2 || va + vb == 0) {
      return TTest(double.nan, double.nan, double.nan, da.mean - db.mean, 'Welch t');
    }
    final t = (da.mean - db.mean) / math.sqrt(va + vb);
    final df = (va + vb) * (va + vb) / (va * va / (da.n - 1) + vb * vb / (db.n - 1));
    return TTest(t, df, tTwoSidedP(t, df), da.mean - db.mean, 'Welch t');
  }

  /// Paired t-test (e.g. two methods on the same samples).
  static TTest paired(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    final d = [for (var i = 0; i < n; i++) a[i] - b[i]];
    final r = oneSample(d, 0);
    return TTest(r.t, r.df, r.p, r.meanDiff, 'Paired t');
  }

  static AnovaResult anova(List<List<double>> groups) {
    final g = groups.where((x) => x.isNotEmpty).toList();
    final all = [for (final x in g) ...x];
    final n = all.length;
    final k = g.length;
    final grand = all.reduce((a, b) => a + b) / n;
    var ssb = 0.0, ssw = 0.0;
    for (final x in g) {
      final m = x.reduce((a, b) => a + b) / x.length;
      ssb += x.length * (m - grand) * (m - grand);
      for (final v in x) {
        ssw += (v - m) * (v - m);
      }
    }
    final dfb = k - 1.0, dfw = n - k + 0.0;
    final msb = ssb / dfb, msw = ssw / dfw;
    final f = msw == 0 ? double.infinity : msb / msw;
    return AnovaResult(ssb, ssw, dfb, dfw, msb, msw, f, f.isFinite ? fUpperP(f, dfb, dfw) : 0);
  }

  /// Two-sided Grubbs' test for a single outlier at significance [alpha].
  static GrubbsResult? grubbs(List<double> v, {double alpha = 0.05}) {
    final n = v.length;
    if (n < 3) return null;
    final d = Describe.of(v);
    if (d.sd == 0) return null;
    var idx = 0;
    var best = 0.0;
    for (var i = 0; i < n; i++) {
      final z = (v[i] - d.mean).abs();
      if (z > best) {
        best = z;
        idx = i;
      }
    }
    final g = best / d.sd;
    final t = tInv(1 - alpha / (2 * n), n - 2.0);
    final gc = (n - 1) / math.sqrt(n) * math.sqrt(t * t / (n - 2 + t * t));
    return GrubbsResult(g, gc, idx, v[idx]);
  }
}

// ---------------------------------------------------------------------------
// QC helpers
// ---------------------------------------------------------------------------

/// Relative percent difference of duplicates.
double rpd(double a, double b) {
  final m = (a + b) / 2;
  return m == 0 ? 0 : (a - b).abs() / m * 100;
}

/// Matrix spike recovery: (spiked − unspiked) / added × 100.
double spikeRecovery(double spiked, double unspiked, double added) => added == 0 ? double.nan : (spiked - unspiked) / added * 100;

/// Recovery against a certified/known value.
double recovery(double measured, double certified) => certified == 0 ? double.nan : measured / certified * 100;

enum WestgardRule { r13s, r22s, rR4s, r41s, r10x, w12s }

extension WestgardRuleX on WestgardRule {
  String get label {
    switch (this) {
      case WestgardRule.r13s:
        return '1-3s';
      case WestgardRule.r22s:
        return '2-2s';
      case WestgardRule.rR4s:
        return 'R-4s';
      case WestgardRule.r41s:
        return '4-1s';
      case WestgardRule.r10x:
        return '10-x̄';
      case WestgardRule.w12s:
        return '1-2s warning';
    }
  }

  String get meaning {
    switch (this) {
      case WestgardRule.r13s:
        return 'One result beyond ±3s: random error, reject the run.';
      case WestgardRule.r22s:
        return 'Two consecutive results beyond 2s on the same side: systematic error.';
      case WestgardRule.rR4s:
        return 'Consecutive results differ by more than 4s: random error.';
      case WestgardRule.r41s:
        return 'Four consecutive results beyond 1s on the same side: systematic shift.';
      case WestgardRule.r10x:
        return 'Ten consecutive results on the same side of the mean: bias or drift.';
      case WestgardRule.w12s:
        return 'One result beyond ±2s: warning, inspect the other rules.';
    }
  }

  bool get rejects => this != WestgardRule.w12s;
}

/// Evaluates Westgard rules for every point. Returns, for each index, the
/// rules violated at that point.
List<List<WestgardRule>> westgard(List<double> v, double mean, double sd) {
  final z = [for (final x in v) sd == 0 ? 0.0 : (x - mean) / sd];
  final out = <List<WestgardRule>>[];
  for (var i = 0; i < z.length; i++) {
    final r = <WestgardRule>[];
    if (z[i].abs() > 3) r.add(WestgardRule.r13s);
    if (z[i].abs() > 2 && z[i].abs() <= 3) r.add(WestgardRule.w12s);
    if (i >= 1) {
      if ((z[i] > 2 && z[i - 1] > 2) || (z[i] < -2 && z[i - 1] < -2)) r.add(WestgardRule.r22s);
      if ((z[i] - z[i - 1]).abs() > 4 && ((z[i] > 2 && z[i - 1] < -2) || (z[i] < -2 && z[i - 1] > 2))) {
        r.add(WestgardRule.rR4s);
      }
    }
    if (i >= 3) {
      final w = z.sublist(i - 3, i + 1);
      if (w.every((x) => x > 1) || w.every((x) => x < -1)) r.add(WestgardRule.r41s);
    }
    if (i >= 9) {
      final w = z.sublist(i - 9, i + 1);
      if (w.every((x) => x > 0) || w.every((x) => x < 0)) r.add(WestgardRule.r10x);
    }
    out.add(r);
  }
  return out;
}
