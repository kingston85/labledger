// Pollution indices used in water and soil/sediment quality assessment.
//
// Water (against the selected standard, Si):
//   WQI  weighted arithmetic water quality index (Brown et al. 1972)
//   HPI  heavy-metal pollution index (Mohan et al. 1996), Qi = 100·Mi/Si
//   HEI  heavy-metal evaluation index (Edet & Offiong 2002) = Σ Mi/Si
//   Cd   contamination index (Backman et al. 1998) = Σ (Mi/Si − 1)
//   PN   Nemerow pollution index = √((Pmax² + Pmean²)/2), Pi = Ci/Si
// Soil / sediment (against background Bn, the control by default):
//   Igeo geo-accumulation index (Müller 1969) = log2(Cn / 1.5·Bn)
//   Er   potential ecological risk (Håkanson 1980) = Tr × CF, RI = Σ Er
//   Cdeg degree of contamination = Σ CF

import 'dart:math' as math;

import '../data/models.dart';
import 'guidelines.dart';
import 'investigation.dart';

/// Parameters treated as heavy metals / trace elements (paramKey form).
final Set<String> metalKeys = {
  for (final p in [
    'Aluminium (Al)', 'Arsenic (As)', 'Barium (Ba)', 'Beryllium (Be)', 'Bismuth (Bi)', 'Boron (B)', 'Cadmium (Cd)',
    'Chromium (Cr)', 'Copper (Cu)', 'Iron (Fe)', 'Lead (Pb)', 'Lithium (Li)', 'Manganese (Mn)', 'Mercury (Hg)',
    'Nickel (Ni)', 'Selenium (Se)', 'Antimony (Sb)', 'Strontium (Sr)', 'Tin (Sn)', 'Titanium (Ti)', 'Uranium (U)', 'Zinc (Zn)',
  ])
    paramKey(p),
};

/// Håkanson toxic-response factors.
final Map<String, double> toxicResponse = {
  paramKey('Mercury (Hg)'): 40,
  paramKey('Cadmium (Cd)'): 30,
  paramKey('Arsenic (As)'): 10,
  paramKey('Lead (Pb)'): 5,
  paramKey('Copper (Cu)'): 5,
  paramKey('Nickel (Ni)'): 5,
  paramKey('Chromium (Cr)'): 2,
  paramKey('Zinc (Zn)'): 1,
  paramKey('Manganese (Mn)'): 1,
};

/// Ideal values for WQI (pure water); 0 for everything else.
final Map<String, double> _ideal = {paramKey('pH'): 7.0, paramKey('Dissolved oxygen'): 14.6};

class Indexed {
  final double value;
  final String cls;
  final int severity; // 0 good … 4 worst, for colouring
  final int n; // parameters used
  const Indexed(this.value, this.cls, this.severity, this.n);
}

class SampleIndices {
  final Sample sample;
  final Indexed? wqi, hpi, hei, cd, nemerow; // water
  final Indexed? cdeg, ri, pli; // soil
  final Map<String, double> igeo; // parameter → Igeo
  final Map<String, double> er; // parameter → Er
  const SampleIndices(this.sample, {this.wqi, this.hpi, this.hei, this.cd, this.nemerow, this.cdeg, this.ri, this.pli, this.igeo = const {}, this.er = const {}});
}

double? _valueIn(InvestigationGroup g, Sample s, String p, String unit) {
  final r = g.cell(s, p);
  if (r == null) return null;
  // Non-detects count as half the detection limit (common convention), else skipped.
  final v = r.belowLod ? (r.lod == null ? null : r.lod! / 2) : r.value;
  if (v == null) return null;
  return convertUnit(v, r.unit, unit) ?? (r.unit.isEmpty || unit.isEmpty ? v : null);
}

Indexed wqiClass(double v, int n) {
  if (v <= 25) return Indexed(v, 'Excellent', 0, n);
  if (v <= 50) return Indexed(v, 'Good', 1, n);
  if (v <= 75) return Indexed(v, 'Poor', 2, n);
  if (v <= 100) return Indexed(v, 'Very poor', 3, n);
  return Indexed(v, 'Unsuitable for drinking', 4, n);
}

Indexed hpiClass(double v, int n) => v < 100 ? Indexed(v, v < 50 ? 'Low' : 'Medium', v < 50 ? 0 : 1, n) : Indexed(v, 'Above critical (100)', 4, n);
Indexed heiClass(double v, int n) => v < 10 ? Indexed(v, 'Low', 0, n) : (v <= 20 ? Indexed(v, 'Medium', 2, n) : Indexed(v, 'High', 4, n));
Indexed cdClass(double v, int n) => v < 1 ? Indexed(v, 'Low', 0, n) : (v <= 3 ? Indexed(v, 'Medium', 2, n) : Indexed(v, 'High', 4, n));

Indexed nemerowClass(double v, int n) {
  if (v <= 0.7) return Indexed(v, 'Clean', 0, n);
  if (v <= 1) return Indexed(v, 'Warning limit', 1, n);
  if (v <= 2) return Indexed(v, 'Slight pollution', 2, n);
  if (v <= 3) return Indexed(v, 'Moderate pollution', 3, n);
  return Indexed(v, 'Heavy pollution', 4, n);
}

String igeoClass(double v) {
  if (v <= 0) return 'Class 0 · unpolluted';
  if (v <= 1) return 'Class 1 · unpolluted to moderate';
  if (v <= 2) return 'Class 2 · moderate';
  if (v <= 3) return 'Class 3 · moderate to heavy';
  if (v <= 4) return 'Class 4 · heavy';
  if (v <= 5) return 'Class 5 · heavy to extreme';
  return 'Class 6 · extreme';
}

int igeoSeverity(double v) => v <= 0 ? 0 : (v <= 1 ? 1 : (v <= 2 ? 2 : (v <= 3 ? 3 : 4)));

Indexed erClass(double v) {
  if (v < 40) return Indexed(v, 'Low', 0, 1);
  if (v < 80) return Indexed(v, 'Moderate', 1, 1);
  if (v < 160) return Indexed(v, 'Considerable', 2, 1);
  if (v < 320) return Indexed(v, 'High', 3, 1);
  return Indexed(v, 'Very high', 4, 1);
}

Indexed riClass(double v, int n) {
  if (v < 150) return Indexed(v, 'Low', 0, n);
  if (v < 300) return Indexed(v, 'Moderate', 2, n);
  if (v < 600) return Indexed(v, 'Considerable', 3, n);
  return Indexed(v, 'Very high', 4, n);
}

Indexed cdegClass(double v, int n) {
  // Håkanson's bands for 8 pollutants, scaled to the number actually used.
  final k = n / 8;
  if (v < 8 * k) return Indexed(v, 'Low', 0, n);
  if (v < 16 * k) return Indexed(v, 'Moderate', 2, n);
  if (v < 32 * k) return Indexed(v, 'Considerable', 3, n);
  return Indexed(v, 'Very high', 4, n);
}

Indexed pliClass(double v, int n) => v <= 1 ? Indexed(v, v < 1 ? 'No pollution' : 'Baseline', 0, n) : Indexed(v, v < 2 ? 'Polluted' : 'Heavily polluted', v < 2 ? 2 : 4, n);

/// Computes all applicable indices for each sample in [g].
/// [background] overrides the control as the soil background (paramKey → value).
List<SampleIndices> computeIndices(InvestigationGroup g, {Map<String, double>? background}) {
  final out = <SampleIndices>[];
  for (final s in g.samples) {
    if (!g.solid) {
      // Water: compare with the standard.
      final lims = <(String, double, double)>[]; // param, value, Si
      for (final p in g.parameters) {
        final lim = g.limitFor(p);
        if (lim == null) continue;
        final si = lim.max;
        if (si == null || si <= 0) continue;
        final v = _valueIn(g, s, p, lim.unit);
        if (v == null) continue;
        lims.add((p, v, si));
      }
      Indexed? wqi;
      if (lims.length >= 3) {
        final k = 1 / lims.fold<double>(0, (a, e) => a + 1 / e.$3);
        var num = 0.0, den = 0.0;
        for (final (p, v, si) in lims) {
          final vo = _ideal[paramKey(p)] ?? 0;
          final denom = si - vo;
          if (denom == 0) continue;
          // pH deviation counts in either direction from 7.
          final q = 100 * ((paramKey(p) == paramKey('pH') ? (v - vo).abs() : (v - vo)) / denom.abs());
          final w = k / si;
          num += q * w;
          den += w;
        }
        if (den > 0) wqi = wqiClass(num / den, lims.length);
      }
      final metals = lims.where((e) => metalKeys.contains(paramKey(e.$1))).toList();
      Indexed? hpi, hei, cd;
      if (metals.isNotEmpty) {
        var num = 0.0, den = 0.0;
        for (final (_, v, si) in metals) {
          num += (1 / si) * (100 * v / si);
          den += 1 / si;
        }
        hpi = hpiClass(num / den, metals.length);
        final ratios = metals.map((e) => e.$2 / e.$3).toList();
        hei = heiClass(ratios.fold(0.0, (a, b) => a + b), metals.length);
        cd = cdClass(ratios.fold(0.0, (a, b) => a + b - 1), metals.length);
      }
      Indexed? pn;
      final pis = [for (final e in lims) if (paramKey(e.$1) != paramKey('pH')) e.$2 / e.$3];
      if (pis.isNotEmpty) {
        final pmax = pis.reduce(math.max), pmean = pis.reduce((a, b) => a + b) / pis.length;
        pn = nemerowClass(math.sqrt((pmax * pmax + pmean * pmean) / 2), pis.length);
      }
      out.add(SampleIndices(s, wqi: wqi, hpi: hpi, hei: hei, cd: cd, nemerow: pn));
    } else {
      // Soil / sediment: compare with background.
      final igeo = <String, double>{}, er = <String, double>{};
      var cdeg = 0.0;
      var n = 0;
      final cfs = <double>[];
      for (final p in g.parameters) {
        final k = paramKey(p);
        if (!metalKeys.contains(k)) continue;
        final r = g.cell(s, p);
        if (r == null || r.belowLod || r.value == null) continue;
        final bn = background?[k] ?? g.controlRef(p)?.value;
        if (bn == null || bn <= 0) continue;
        final cf = r.value! / bn;
        igeo[p] = math.log(r.value! / (1.5 * bn)) / math.ln2;
        if (toxicResponse.containsKey(k)) er[p] = toxicResponse[k]! * cf;
        cdeg += cf;
        cfs.add(cf);
        n++;
      }
      final pli = cfs.isEmpty ? null : math.exp(cfs.map(math.log).reduce((a, b) => a + b) / cfs.length);
      out.add(SampleIndices(
        s,
        igeo: igeo,
        er: er,
        cdeg: n == 0 ? null : cdegClass(cdeg, n),
        ri: er.isEmpty ? null : riClass(er.values.reduce((a, b) => a + b), er.length),
        pli: pli == null ? null : pliClass(pli, n),
      ));
    }
  }
  return out;
}

/// One-line summaries for the findings narrative.
List<String> indexFindings(InvestigationGroup g, List<SampleIndices> idx) {
  final f = <String>[];
  final imp = idx.where((e) => !e.sample.isControl).toList();
  if (imp.isEmpty) return f;
  if (!g.solid) {
    final w = imp.where((e) => e.wqi != null).toList();
    if (w.isNotEmpty) {
      final bad = w.where((e) => e.wqi!.value > 100).toList();
      final worst = w.reduce((a, b) => a.wqi!.value >= b.wqi!.value ? a : b);
      f.add('Water quality index (WQI) ranges ${w.map((e) => e.wqi!.value).reduce(math.min).toStringAsFixed(0)}–${worst.wqi!.value.toStringAsFixed(0)}; '
          '${bad.length} of ${w.length} points are classed "unsuitable for drinking" (WQI > 100), worst at ${worst.sample.code}.');
    }
    final h = imp.where((e) => e.hpi != null).toList();
    if (h.isNotEmpty) {
      final over = h.where((e) => e.hpi!.value >= 100).length;
      f.add('Heavy-metal pollution index (HPI) exceeds the critical value of 100 at $over of ${h.length} points.');
    }
  } else {
    final r = imp.where((e) => e.ri != null).toList();
    if (r.isNotEmpty) {
      final worst = r.reduce((a, b) => a.ri!.value >= b.ri!.value ? a : b);
      f.add('Potential ecological risk (RI) peaks at ${worst.ri!.value.toStringAsFixed(0)} (${worst.ri!.cls.toLowerCase()}) at ${worst.sample.code}.');
    }
    final ig = <String, double>{};
    for (final e in imp) {
      for (final x in e.igeo.entries) {
        ig[x.key] = math.max(ig[x.key] ?? -99, x.value);
      }
    }
    final high = ig.entries.where((e) => e.value > 2).toList()..sort((a, b) => b.value.compareTo(a.value));
    if (high.isNotEmpty) {
      f.add('Geo-accumulation index (Igeo) reaches moderately-to-heavily polluted levels or worse for '
          '${high.take(6).map((e) => '${e.key} (max ${e.value.toStringAsFixed(1)})').join(', ')}.');
    }
  }
  return f;
}

/// Data-written findings plus index summaries.
List<String> allFindings(InvestigationGroup g) => [...writeFindings(g), ...indexFindings(g, computeIndices(g))];
