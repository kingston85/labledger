// Multi-sample analysis for a field investigation: the parameter × sample
// matrix, comparison against standards and control samples, contamination
// factors and an auto-written findings narrative.

import 'dart:math' as math;

import '../data/models.dart';
import 'guidelines.dart';
import 'report.dart';

/// A group of samples analysed together (same matrix class: water or solid).
class InvestigationGroup {
  final String title;
  final bool solid;
  final List<Sample> samples; // controls first, then by code
  final List<String> parameters; // canonical names, in a sensible order
  final LimitSet? limits;
  final Map<String, Map<String, Result>> cells; // sampleId → paramKey → result

  InvestigationGroup({
    required this.title,
    required this.solid,
    required this.samples,
    required this.parameters,
    required this.limits,
    required this.cells,
  });

  List<Sample> get controls => samples.where((s) => s.isControl).toList();
  List<Sample> get impacted => samples.where((s) => !s.isControl).toList();

  Result? cell(Sample s, String parameter) => cells[s.id]?[paramKey(parameter)];

  Check check(Sample s, String parameter) {
    final r = cell(s, parameter);
    if (r == null) return const Check(Compliance.missing, null, null);
    return checkResult(r, limits);
  }

  Limit? limitFor(String parameter) => limits == null ? null : findLimit(limits!, parameter);

  String unitFor(String parameter) {
    for (final s in samples) {
      final r = cell(s, parameter);
      if (r != null && r.unit.isNotEmpty) return r.unit;
    }
    return commonParameters[parameter] ?? '';
  }

  /// Reference (control) level for a parameter: mean of detected control
  /// values, or the detection limit when the control was not detected.
  ControlRef? controlRef(String parameter) {
    final vals = <double>[];
    var nd = false;
    for (final s in controls) {
      final r = cell(s, parameter);
      if (r == null) continue;
      if (r.belowLod) {
        if (r.lod != null) {
          vals.add(r.lod!);
          nd = true;
        }
      } else if (r.value != null) {
        vals.add(r.value!);
      }
    }
    if (vals.isEmpty) return null;
    return ControlRef(vals.reduce((a, b) => a + b) / vals.length, nd);
  }

  /// Ratio of a sample's value to the control (contamination factor, CF).
  double? factor(Sample s, String parameter) {
    final ref = controlRef(parameter);
    final r = cell(s, parameter);
    if (ref == null || r == null || r.belowLod || r.value == null || ref.value <= 0) return null;
    // Ratios are meaningless for log-scale or signed readings.
    if (const {'ph', 'orp', 'temperature'}.contains(paramKey(parameter))) return null;
    return r.value! / ref.value;
  }

  /// Pollution load index (Tomlinson): geometric mean of the CFs of a sample.
  double? pli(Sample s) {
    final cfs = [for (final p in parameters) factor(s, p)].whereType<double>().where((v) => v > 0).toList();
    if (cfs.isEmpty) return null;
    return math.exp(cfs.map(math.log).reduce((a, b) => a + b) / cfs.length);
  }
}

class ControlRef {
  final double value;
  final bool nonDetect; // based on a detection limit
  const ControlRef(this.value, this.nonDetect);
}

/// Håkanson (1980) contamination-factor classes.
String cfClass(double cf) {
  if (cf < 1) return 'Low';
  if (cf < 3) return 'Moderate';
  if (cf < 6) return 'Considerable';
  return 'Very high';
}

/// Splits a project's samples into water and solid groups and builds the matrix.
List<InvestigationGroup> buildInvestigation(List<Sample> samples, LimitSet? Function(Sample) limitsFor) {
  final out = <InvestigationGroup>[];
  for (final solid in [false, true]) {
    final list = samples.where((s) => s.matrix.isSolid == solid).toList();
    if (list.isEmpty) continue;
    list.sort((a, b) {
      if (a.isControl != b.isControl) return a.isControl ? -1 : 1;
      final sa = codeSeq(a.code), sb = codeSeq(b.code);
      if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
      return a.code.compareTo(b.code);
    });
    final cells = <String, Map<String, Result>>{};
    final seen = <String, String>{}; // paramKey → display name
    for (final s in list) {
      final m = <String, Result>{};
      for (final r in s.results) {
        final k = paramKey(r.parameter);
        m[k] = r;
        seen.putIfAbsent(k, () => canonicalParameter(r.parameter));
      }
      cells[s.id] = m;
    }
    final order = commonParameters.keys.map(normKey).toList();
    final params = seen.keys.toList()
      ..sort((a, b) {
        final ia = order.indexOf(a), ib = order.indexOf(b);
        return (ia < 0 ? 999 : ia).compareTo(ib < 0 ? 999 : ib);
      });
    final matrices = list.map((s) => s.matrix.label).toSet().join(', ');
    out.add(InvestigationGroup(
      title: solid ? 'Soil & sediment ($matrices)' : 'Water ($matrices)',
      solid: solid,
      samples: list,
      parameters: [for (final k in params) seen[k]!],
      limits: limitsFor(list.firstWhere((s) => !s.isControl, orElse: () => list.first)),
      cells: cells,
    ));
  }
  return out;
}

String _list(List<String> items, {int max = 8}) {
  if (items.length <= max) {
    if (items.length <= 1) return items.join();
    return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
  }
  return '${items.take(max).join(', ')} and ${items.length - max} more';
}

String _v(double v, String unit) => '${fmtValue(v)}${unit.isEmpty ? '' : ' $unit'}';

/// Plain-language findings in the style of an EPA investigation report,
/// written directly from the data so the narrative always matches the tables.
List<String> writeFindings(InvestigationGroup g) {
  final f = <String>[];
  final ctrl = g.controls;
  final imp = g.impacted;
  final setName = g.limits?.name ?? 'the selected standard';
  f.add('${g.samples.length} sample${g.samples.length == 1 ? '' : 's'} '
      '(${ctrl.isEmpty ? 'no control' : '${ctrl.length} control: ${ctrl.map((s) => s.code).join(', ')}'}) '
      'analysed for ${g.parameters.length} parameters${g.solid ? '' : ' and compared with $setName'}.');

  final compliant = <String>[];
  var anyLimit = false;
  for (final p in g.parameters) {
    final lim = g.limitFor(p);
    if (lim == null || g.solid) continue;
    anyLimit = true;
    final unit = lim.unit;
    final over = <Sample>[], under = <Sample>[];
    for (final s in g.samples) {
      final c = g.check(s, p);
      if (c.status == Compliance.exceed) over.add(s);
      if (c.status == Compliance.belowMin) under.add(s);
    }
    if (over.isEmpty && under.isEmpty) {
      if (g.samples.any((s) => g.cell(s, p) != null)) compliant.add(p);
      continue;
    }
    String desc(List<Sample> ss) => _list([
          for (final s in ss) '${s.code} (${_v(g.check(s, p).valueInLimitUnit ?? g.cell(s, p)!.value!, unit)})',
        ]);
    final impOver = over.where((s) => !s.isControl).toList();
    final ctrlOver = over.where((s) => s.isControl).toList();
    final measuredImp = imp.where((s) => g.cell(s, p) != null && !(g.cell(s, p)!.belowLod)).toList();
    if (impOver.isNotEmpty) {
      final every = measuredImp.length > 1 && impOver.length == measuredImp.length;
      final ctrlOk = ctrl.isNotEmpty && ctrlOver.isEmpty && ctrl.any((s) => g.cell(s, p) != null);
      final worst = impOver.reduce((a, b) =>
          (g.check(a, p).valueInLimitUnit ?? 0) >= (g.check(b, p).valueInLimitUnit ?? 0) ? a : b);
      final wv = g.check(worst, p).valueInLimitUnit ?? 0;
      final fac = lim.max != null && lim.max! > 0 ? wv / lim.max! : null;
      final head = every
          ? '$p exceeded the ${lim.text} limit at every sampling point${ctrlOk ? ' except the control (${ctrl.map((s) => s.code).join(', ')})' : ''}'
          : '$p exceeded the ${lim.text} limit at ${impOver.length} of ${measuredImp.length} points: ${desc(impOver)}';
      f.add('$head. Highest: ${worst.code} at ${_v(wv, unit)}'
          '${fac != null && fac >= 1.05 ? ' (${fac.toStringAsFixed(1)}× the limit)' : ''}.');
    }
    if (ctrlOver.isNotEmpty) {
      f.add('$p also exceeded the limit at the control ${desc(ctrlOver)}, suggesting a natural background or another source.');
    }
    if (under.isNotEmpty) {
      f.add('$p was below the ${lim.text} range at ${desc(under)}${p == 'pH' ? ' (acidic, corrosive water)' : ''}.');
    }
  }
  if (compliant.isNotEmpty && anyLimit) {
    f.add('Complied at all points: ${_list(compliant, max: 14)}.');
  }

  if (ctrl.isNotEmpty && imp.isNotEmpty) {
    final rows = <(String, double, ControlRef, double, double)>[]; // p, mean CF, ref, min, max
    for (final p in g.parameters) {
      final ref = g.controlRef(p);
      if (ref == null) continue;
      final cfs = [for (final s in imp) g.factor(s, p)].whereType<double>().toList();
      if (cfs.isEmpty) continue;
      final vals = [for (final s in imp) g.cell(s, p)?.value].whereType<double>().toList();
      final mean = cfs.reduce((a, b) => a + b) / cfs.length;
      rows.add((p, mean, ref, vals.reduce(math.min), vals.reduce(math.max)));
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    final strong = rows.where((r) => r.$2 >= 3).toList();
    if (strong.isNotEmpty) {
      f.add('Compared with the control, impacted points are strongly enriched in '
          '${_list([for (final r in strong.take(8)) '${r.$1} (${r.$2.toStringAsFixed(1)}× on average)'])}.');
      for (final r in strong.take(5)) {
        final u = g.unitFor(r.$1);
        f.add('${r.$1} ranged from ${_v(r.$4, u)} to ${_v(r.$5, u)} against a control value of '
            '${r.$3.nonDetect ? '< ' : ''}${_v(r.$3.value, u)}.');
      }
    } else if (rows.isNotEmpty) {
      f.add('No parameter averages more than three times the control level.');
    }
    if (g.solid) {
      final plis = [for (final s in imp) (s, g.pli(s))].where((e) => e.$2 != null).toList();
      if (plis.isNotEmpty) {
        final polluted = plis.where((e) => e.$2! > 1).toList();
        final top = plis.reduce((a, b) => a.$2! >= b.$2! ? a : b);
        f.add('Pollution load index (PLI) is above 1 (polluted) at ${polluted.length} of ${plis.length} points; '
            'highest at ${top.$1.code} (PLI ${top.$2!.toStringAsFixed(2)}).');
      }
      final vh = <String>[];
      for (final p in g.parameters) {
        final n = imp.where((s) => (g.factor(s, p) ?? 0) >= 6).length;
        if (n > 0) vh.add('$p ($n pts)');
      }
      if (vh.isNotEmpty) f.add('Very high contamination (CF ≥ 6) for ${_list(vh)}.');
    }
  } else if (ctrl.isEmpty && imp.isNotEmpty) {
    f.add('No control sample is marked, so enrichment against background cannot be assessed. '
        'Mark an upstream or off-site sample as the control.');
  }

  // Trend along the sampling sequence (e.g. downstream decline).
  for (final p in g.parameters) {
    final pts = [
      for (final s in imp)
        if (codeSeq(s.code) != null && g.cell(s, p)?.value != null) (codeSeq(s.code)!.toDouble(), g.cell(s, p)!.value!)
    ];
    if (pts.length < 5) continue;
    final rho = _spearman(pts);
    if (rho.abs() >= 0.9) {
      f.add('$p shows a consistent ${rho > 0 ? 'increase' : 'decrease'} along the sampling sequence (Spearman ρ = ${rho.toStringAsFixed(2)}).');
    }
  }
  return f;
}

double _spearman(List<(double, double)> pts) {
  List<double> rank(List<double> v) {
    final idx = List.generate(v.length, (i) => i)..sort((a, b) => v[a].compareTo(v[b]));
    final r = List<double>.filled(v.length, 0);
    var i = 0;
    while (i < idx.length) {
      var j = i;
      while (j + 1 < idx.length && v[idx[j + 1]] == v[idx[i]]) {
        j++;
      }
      for (var k = i; k <= j; k++) {
        r[idx[k]] = (i + j) / 2 + 1;
      }
      i = j + 1;
    }
    return r;
  }

  final rx = rank([for (final p in pts) p.$1]), ry = rank([for (final p in pts) p.$2]);
  final n = pts.length;
  final mx = rx.reduce((a, b) => a + b) / n, my = ry.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0, syy = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (rx[i] - mx) * (ry[i] - my);
    sxx += (rx[i] - mx) * (rx[i] - mx);
    syy += (ry[i] - my) * (ry[i] - my);
  }
  return sxx == 0 || syy == 0 ? 0 : sxy / math.sqrt(sxx * syy);
}
