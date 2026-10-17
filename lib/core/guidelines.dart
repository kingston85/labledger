// Guideline limits, parameter names and compliance checks.

import '../data/models.dart';

/// Common parameters offered when entering results.
const commonParameters = <String, String>{
  'pH': '',
  'Temperature': '°C',
  'Electrical conductivity': 'µS/cm',
  'Total dissolved solids': 'mg/L',
  'Turbidity': 'NTU',
  'Dissolved oxygen': 'mg/L',
  'BOD5': 'mg/L',
  'COD': 'mg/L',
  'Total suspended solids': 'mg/L',
  'Chloride': 'mg/L',
  'Sulfate': 'mg/L',
  'Nitrate (as NO3)': 'mg/L',
  'Nitrite (as NO2)': 'mg/L',
  'Ammonia': 'mg/L',
  'Phosphate': 'mg/L',
  'Fluoride': 'mg/L',
  'Total hardness (CaCO3)': 'mg/L',
  'Arsenic (As)': 'mg/L',
  'Barium (Ba)': 'mg/L',
  'Boron (B)': 'mg/L',
  'Cadmium (Cd)': 'mg/L',
  'Chromium (Cr)': 'mg/L',
  'Copper (Cu)': 'mg/L',
  'Iron (Fe)': 'mg/L',
  'Lead (Pb)': 'mg/L',
  'Manganese (Mn)': 'mg/L',
  'Mercury (Hg)': 'mg/L',
  'Nickel (Ni)': 'mg/L',
  'Selenium (Se)': 'mg/L',
  'Uranium (U)': 'mg/L',
  'Antimony (Sb)': 'mg/L',
  'Zinc (Zn)': 'mg/L',
  'Aluminium (Al)': 'mg/L',
  'Cyanide (free)': 'mg/L',
  'E. coli': 'CFU/100 mL',
  'Total coliforms': 'CFU/100 mL',
};

const units = ['mg/L', 'µg/L', 'mg/kg', 'µg/g', 'µg/m³', 'mg/m³', 'NTU', 'µS/cm', 'CFU/100 mL', '°C', 'ppm', 'ppb', '%', ''];

/// WHO Guidelines for Drinking-water Quality (4th ed. incorporating the
/// 1st and 2nd addenda, 2022). Health-based guideline values unless noted
/// as acceptability (taste, odour, appearance) values.
LimitSet whoDrinkingWater() => LimitSet(
      id: 'who-dw',
      name: 'WHO drinking water (GDWQ 2022)',
      note: 'Health-based guideline values; items marked "acceptability" are aesthetic. '
          'Check against the current WHO edition and national standards before formal use.',
      builtIn: true,
      limits: const {
        'Arsenic (As)': Limit(max: 0.01, unit: 'mg/L'),
        'Barium (Ba)': Limit(max: 1.3, unit: 'mg/L'),
        'Boron (B)': Limit(max: 2.4, unit: 'mg/L'),
        'Cadmium (Cd)': Limit(max: 0.003, unit: 'mg/L'),
        'Chromium (Cr)': Limit(max: 0.05, unit: 'mg/L', note: 'total chromium'),
        'Copper (Cu)': Limit(max: 2, unit: 'mg/L'),
        'Fluoride': Limit(max: 1.5, unit: 'mg/L'),
        'Lead (Pb)': Limit(max: 0.01, unit: 'mg/L'),
        'Manganese (Mn)': Limit(max: 0.08, unit: 'mg/L'),
        'Mercury (Hg)': Limit(max: 0.006, unit: 'mg/L', note: 'inorganic mercury'),
        'Nickel (Ni)': Limit(max: 0.07, unit: 'mg/L'),
        'Nitrate (as NO3)': Limit(max: 50, unit: 'mg/L'),
        'Nitrite (as NO2)': Limit(max: 3, unit: 'mg/L'),
        'Selenium (Se)': Limit(max: 0.04, unit: 'mg/L'),
        'Uranium (U)': Limit(max: 0.03, unit: 'mg/L'),
        'Antimony (Sb)': Limit(max: 0.02, unit: 'mg/L'),
        'E. coli': Limit(max: 0, unit: 'CFU/100 mL', note: 'must not be detectable in 100 mL'),
        'pH': Limit(min: 6.5, max: 8.5, unit: '', note: 'acceptability / operational'),
        'Turbidity': Limit(max: 5, unit: 'NTU', note: 'acceptability'),
        'Iron (Fe)': Limit(max: 0.3, unit: 'mg/L', note: 'acceptability'),
        'Zinc (Zn)': Limit(max: 3, unit: 'mg/L', note: 'acceptability'),
        'Chloride': Limit(max: 250, unit: 'mg/L', note: 'acceptability (taste)'),
        'Total dissolved solids': Limit(max: 1000, unit: 'mg/L', note: 'acceptability (taste)'),
      },
    );

String normKey(String p) => p.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Finds the limit for a parameter, matching flexibly ("Pb", "lead", "Lead (Pb)").
Limit? findLimit(LimitSet set, String parameter) {
  final k = normKey(parameter);
  for (final e in set.limits.entries) {
    final name = e.key;
    if (normKey(name) == k) return e.value;
    // Match the element symbol or the name part of "Lead (Pb)".
    final m = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(name);
    if (m != null && (normKey(m.group(1)!) == k || normKey(m.group(2)!) == k)) return e.value;
  }
  return null;
}

/// Converts [value] from unit [from] to unit [to] when they are compatible.
double? convertUnit(double value, String from, String to) {
  String n(String u) {
    final s = u.trim().toLowerCase().replaceAll('μ', 'µ').replaceAll('ug', 'µg');
    if (s == 'ppm') return 'mg/l';
    if (s == 'ppb') return 'µg/l';
    return s;
  }

  final a = n(from), b = n(to);
  if (a == b) return value;
  const scale = {'mg/l': 1.0, 'µg/l': 1e-3, 'g/l': 1e3, 'ng/l': 1e-6};
  const solid = {'mg/kg': 1.0, 'µg/g': 1.0, 'µg/kg': 1e-3, 'g/kg': 1e3, '%': 1e4};
  const air = {'µg/m³': 1.0, 'mg/m³': 1e3, 'µg/m3': 1.0, 'mg/m3': 1e3};
  for (final t in [scale, solid, air]) {
    if (t.containsKey(a) && t.containsKey(b)) return value * t[a]! / t[b]!;
  }
  return null;
}

enum Compliance { pass, exceed, belowMin, belowLod, noLimit, unitMismatch, missing }

class Check {
  final Compliance status;
  final Limit? limit;
  final double? valueInLimitUnit;
  const Check(this.status, this.limit, this.valueInLimitUnit);

  /// Ratio of the value to the maximum limit (exceedance factor).
  double? get factor =>
      limit?.max != null && valueInLimitUnit != null && limit!.max! > 0 ? valueInLimitUnit! / limit!.max! : null;
}

Check checkResult(Result r, LimitSet? set) {
  if (r.belowLod) {
    final lim = set == null ? null : findLimit(set, r.parameter);
    return Check(Compliance.belowLod, lim, null);
  }
  if (r.value == null) return const Check(Compliance.missing, null, null);
  if (set == null) return const Check(Compliance.noLimit, null, null);
  final lim = findLimit(set, r.parameter);
  if (lim == null) return const Check(Compliance.noLimit, null, null);
  final v = convertUnit(r.value!, r.unit, lim.unit);
  if (v == null) return Check(Compliance.unitMismatch, lim, null);
  if (lim.max != null && v > lim.max! + 1e-12) return Check(Compliance.exceed, lim, v);
  if (lim.min != null && v < lim.min! - 1e-12) return Check(Compliance.belowMin, lim, v);
  return Check(Compliance.pass, lim, v);
}
