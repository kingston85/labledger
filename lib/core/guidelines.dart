// Guideline limits, parameter names and compliance checks.

import '../data/models.dart';

/// Common parameters offered when entering results.
const commonParameters = <String, String>{
  'pH': '',
  'Temperature': '°C',
  'Electrical conductivity': 'µS/cm',
  'ORP': 'mV',
  'Salinity': 'ppt',
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
  'Bismuth (Bi)': 'mg/L',
  'Tin (Sn)': 'mg/L',
  'Beryllium (Be)': 'mg/L',
  'Lithium (Li)': 'mg/L',
  'Strontium (Sr)': 'mg/L',
  'Titanium (Ti)': 'mg/L',
  'Cyanide (free)': 'mg/L',
  'E. coli': 'CFU/100 mL',
  'Total coliforms': 'CFU/100 mL',
};

const units = ['mg/L', 'mV', 'ppt', 'µg/L', 'mg/kg', 'µg/g', 'µg/m³', 'mg/m³', 'NTU', 'µS/cm', 'CFU/100 mL', '°C', 'ppm', 'ppb', '%', ''];

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

/// Default analytical method / instrument per parameter, as used by the EPA
/// Liberia ERRS laboratory in its field investigation reports.
const defaultMethods = <String, String>{
  'pH': 'pH meter',
  'Temperature': 'Multimeter (in situ)',
  'Electrical conductivity': 'Conductivity meter',
  'ORP': 'ORP meter',
  'Salinity': 'Multimeter',
  'Turbidity': 'Turbidity meter',
  'Total dissolved solids': 'Digital titration',
  'Total suspended solids': 'Digital titration',
  'Total hardness (CaCO3)': 'Colorimeter',
  'Chloride': 'Colorimeter',
  'Nitrate (as NO3)': 'Colorimeter',
  'Nitrite (as NO2)': 'Colorimeter',
  'Phosphate': 'Colorimeter',
  'Sulfate': 'Colorimeter',
  'Ammonia': 'Spectrophotometer',
  'Arsenic (As)': 'Hydride generator',
  'Selenium (Se)': 'Hydride generator',
  'Aluminium (Al)': 'Spectrophotometer',
  'Bismuth (Bi)': 'Spectrophotometer',
  'Iron (Fe)': 'Spectrophotometer',
  'Tin (Sn)': 'Spectrophotometer',
  'Barium (Ba)': 'Spectrophotometer',
  'Beryllium (Be)': 'Spectrophotometer',
  'Boron (B)': 'Spectrophotometer',
  'Cadmium (Cd)': 'Spectrophotometer',
  'Chromium (Cr)': 'Spectrophotometer',
  'Copper (Cu)': 'Spectrophotometer',
  'Lead (Pb)': 'Spectrophotometer',
  'Lithium (Li)': 'Spectrophotometer',
  'Manganese (Mn)': 'Spectrophotometer',
  'Strontium (Sr)': 'Spectrophotometer',
  'Titanium (Ti)': 'Spectrophotometer',
  'Zinc (Zn)': 'Spectrophotometer',
};

/// Ready-made parameter panels for entering many results at once.
class ParameterPanel {
  final String name;
  final String hint;
  final List<String> parameters;
  const ParameterPanel(this.name, this.hint, this.parameters);
}

const parameterPanels = <ParameterPanel>[
  ParameterPanel('Field (in situ)', 'Multimeter readings at the sampling point',
      ['pH', 'Temperature', 'Electrical conductivity', 'ORP', 'Salinity', 'Turbidity']),
  ParameterPanel('Physical', 'Solids and turbidity',
      ['pH', 'Electrical conductivity', 'Turbidity', 'Total dissolved solids', 'Total suspended solids']),
  ParameterPanel('Nutrients & ions', 'Colorimeter',
      ['Total hardness (CaCO3)', 'Chloride', 'Nitrate (as NO3)', 'Nitrite (as NO2)', 'Ammonia', 'Phosphate', 'Sulfate']),
  ParameterPanel('Mining metals', 'Iron-ore suite used in EPA mining investigations', [
    'Aluminium (Al)', 'Bismuth (Bi)', 'Iron (Fe)', 'Arsenic (As)', 'Tin (Sn)', 'Selenium (Se)', 'Barium (Ba)',
    'Beryllium (Be)', 'Boron (B)', 'Cadmium (Cd)', 'Chromium (Cr)', 'Copper (Cu)', 'Lead (Pb)', 'Lithium (Li)',
    'Manganese (Mn)', 'Strontium (Sr)', 'Titanium (Ti)', 'Zinc (Zn)',
  ]),
];

/// Liberian water quality standards (Class I) as tabulated in EPA Liberia
/// (ERRS) field investigation reports, 2025–2026. "NG" (no guideline)
/// parameters such as strontium and titanium are left out.
LimitSet liberiaWater() => LimitSet(
      id: 'lr-epa-w1',
      name: 'Liberian water standards (Class I)',
      note: 'Values as cited in EPA Liberia field investigation reports (Bonlah 2025, Bolo Town 2026). '
          'Confirm against the current official gazette before regulatory use.',
      builtIn: true,
      limits: const {
        'pH': Limit(min: 6.5, max: 8.5, unit: ''),
        'Electrical conductivity': Limit(max: 150, unit: 'µS/cm'),
        'Turbidity': Limit(max: 50, unit: 'NTU'),
        'Total dissolved solids': Limit(max: 1000, unit: 'mg/L'),
        'Total suspended solids': Limit(max: 50, unit: 'mg/L'),
        'Total hardness (CaCO3)': Limit(max: 200, unit: 'mg/L'),
        'Chloride': Limit(max: 250, unit: 'mg/L'),
        'Nitrate (as NO3)': Limit(max: 50, unit: 'mg/L'),
        'Nitrite (as NO2)': Limit(max: 3.0, unit: 'mg/L'),
        'Ammonia': Limit(max: 1.0, unit: 'mg/L'),
        'Phosphate': Limit(max: 5.0, unit: 'mg/L'),
        'Sulfate': Limit(max: 250, unit: 'mg/L'),
        'Aluminium (Al)': Limit(max: 0.75, unit: 'mg/L'),
        'Bismuth (Bi)': Limit(max: 0.7, unit: 'mg/L'),
        'Iron (Fe)': Limit(max: 2.0, unit: 'mg/L'),
        'Arsenic (As)': Limit(max: 0.1, unit: 'mg/L'),
        'Tin (Sn)': Limit(max: 0.02, unit: 'mg/L'),
        'Selenium (Se)': Limit(max: 0.01, unit: 'mg/L'),
        'Barium (Ba)': Limit(max: 0.7, unit: 'mg/L'),
        'Beryllium (Be)': Limit(max: 0.01, unit: 'mg/L'),
        'Boron (B)': Limit(max: 1.0, unit: 'mg/L'),
        'Cadmium (Cd)': Limit(max: 0.01, unit: 'mg/L'),
        'Chromium (Cr)': Limit(max: 2.0, unit: 'mg/L'),
        'Copper (Cu)': Limit(max: 1.0, unit: 'mg/L'),
        'Lead (Pb)': Limit(max: 0.01, unit: 'mg/L'),
        'Lithium (Li)': Limit(max: 0.06, unit: 'mg/L'),
        'Manganese (Mn)': Limit(max: 1.0, unit: 'mg/L'),
        'Zinc (Zn)': Limit(max: 1.0, unit: 'mg/L'),
      },
    );

/// Alternative spellings mapped onto the canonical parameter names above.
const _aliases = <String, String>{
  'conductivity': 'electricalconductivity',
  'ec': 'electricalconductivity',
  'specificconductance': 'electricalconductivity',
  'tds': 'totaldissolvedsolids',
  'tss': 'totalsuspendedsolids',
  'hardness': 'totalhardnesscaco3',
  'totalhardness': 'totalhardnesscaco3',
  'hardnesscaco3': 'totalhardnesscaco3',
  'nitrate': 'nitrateasno3',
  'no3': 'nitrateasno3',
  'nitrite': 'nitriteasno2',
  'no2': 'nitriteasno2',
  'ammonium': 'ammonia',
  'nh3': 'ammonia',
  'nh4': 'ammonia',
  'aluminum': 'aluminiumal',
  'aluminumal': 'aluminiumal',
  'sulphate': 'sulfate',
  'so4': 'sulfate',
  'po4': 'phosphate',
  'redoxpotential': 'orp',
  'oxidationreductionpotential': 'orp',
  'temp': 'temperature',
};

/// A comparable key for a parameter name that understands common aliases,
/// element symbols and the "Name (Symbol)" form.
String paramKey(String p) {
  var k = normKey(p.replaceAll(RegExp(r'\((mg/l|ppm|ppb|µs/cm|us/cm|ntu|mv|ppt|psu|mg/kg|°c|°f)\)', caseSensitive: false), ''));
  k = _aliases[k] ?? k;
  for (final name in commonParameters.keys) {
    final nk = normKey(name);
    if (nk == k) return nk;
    final m = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(name);
    if (m != null && (normKey(m.group(1)!) == k || normKey(m.group(2)!) == k)) return nk;
  }
  return k;
}

/// Canonical display name for a parameter if it is a known one.
String canonicalParameter(String p) {
  final k = paramKey(p);
  for (final name in commonParameters.keys) {
    if (normKey(name) == k) return name;
  }
  return p.trim();
}

double fahrenheitToCelsius(double f) => (f - 32) * 5 / 9;

/// Parses a typed result: "2.07", "<0.001", "ND", or replicates "2.05 2.08 2.07".
class ParsedValue {
  final double? value;
  final bool belowLod;
  final double? lod;
  final List<double> replicates;
  const ParsedValue({this.value, this.belowLod = false, this.lod, this.replicates = const []});
  bool get isEmpty => value == null && !belowLod;
}

ParsedValue parseResultText(String text) {
  final t = text.trim();
  if (t.isEmpty) return const ParsedValue();
  final lt = RegExp(r'^(<|less than|bdl|nd|n\.d\.)\s*([0-9.eE+-]*)$', caseSensitive: false).firstMatch(t);
  if (lt != null) return ParsedValue(belowLod: true, lod: double.tryParse(lt.group(2) ?? ''));
  final nums = RegExp(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?').allMatches(t).map((m) => double.parse(m.group(0)!)).toList();
  if (nums.isEmpty) return const ParsedValue();
  if (nums.length == 1) return ParsedValue(value: nums.first);
  final mean = nums.reduce((a, b) => a + b) / nums.length;
  return ParsedValue(value: mean, replicates: nums);
}

String normKey(String p) => p.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Finds the limit for a parameter, matching flexibly ("Pb", "lead", "Lead (Pb)").
Limit? findLimit(LimitSet set, String parameter) {
  final k = paramKey(parameter);
  for (final e in set.limits.entries) {
    if (paramKey(e.key) == k) return e.value;
  }
  return null;
}

/// Converts [value] from unit [from] to unit [to] when they are compatible.
double? convertUnit(double value, String from, String to) {
  String n(String u) {
    final s = u.trim().toLowerCase().replaceAll('μ', 'µ').replaceAll('ug', 'µg');
    if (s == 'ppm') return 'mg/l';
    if (s == 'ppb') return 'µg/l';
    if (s == 'psu') return 'ppt';
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
