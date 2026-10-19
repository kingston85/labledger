// Method-validation maths and report fingerprints.

import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../data/models.dart';
import 'stats.dart';

class MdlStudy {
  final int n;
  final double mean;
  final double sd;
  final double t;
  final double mdl;
  final double loq;
  final double rsd;
  const MdlStudy(this.n, this.mean, this.sd, this.t, this.mdl, this.loq, this.rsd);
}

/// US EPA 40 CFR 136 Appendix B: MDL = t(n−1, 0.99) × s from ≥ 7 low-level
/// spiked replicates. LOQ is taken as 10 × s.
MdlStudy? mdlStudy(List<double> v) {
  if (v.length < 3) return null;
  final n = v.length;
  final mean = v.reduce((a, b) => a + b) / n;
  var ss = 0.0;
  for (final x in v) {
    ss += (x - mean) * (x - mean);
  }
  final sd = math.sqrt(ss / (n - 1));
  final t = tInv(0.99, n - 1.0);
  return MdlStudy(n, mean, sd, t, t * sd, 10 * sd, mean == 0 ? 0 : sd / mean * 100);
}

/// Expanded uncertainty (k = 2) from repeatability and bias components, %:
/// U = 2 × √(u_rep² + u_bias²).
double expandedUncertainty(double repeatabilityRsdPct, double biasPct) =>
    2 * math.sqrt(repeatabilityRsdPct * repeatabilityRsdPct + biasPct * biasPct);

/// Canonical text of the results on a set of samples; any change to a value,
/// unit or approval changes the fingerprint.
String resultsCanonical(List<Sample> samples) {
  final b = StringBuffer();
  for (final s in [...samples]..sort((a, b) => a.code.compareTo(b.code))) {
    b.write('${s.code}|${s.collectedAt.toIso8601String()}\n');
    for (final r in [...s.results]..sort((a, b) => a.parameter.compareTo(b.parameter))) {
      b.write('${r.parameter}|${r.belowLod ? '<${r.lod ?? ''}' : (r.value?.toString() ?? '')}|${r.unit}|${r.approvedBy}\n');
    }
  }
  return b.toString();
}

/// Short verification code printed on reports (first 12 hex digits of SHA-256).
String reportFingerprint(String reportNo, List<Sample> samples) {
  final h = sha256.convert(utf8.encode('$reportNo\n${resultsCanonical(samples)}')).toString();
  return h.substring(0, 12).toUpperCase();
}

/// Groups a fingerprint for printing: 1A2B-3C4D-5E6F.
String groupCode(String c) => [for (var i = 0; i < c.length; i += 4) c.substring(i, math.min(i + 4, c.length))].join('-');
