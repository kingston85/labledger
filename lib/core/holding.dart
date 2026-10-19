// Sample containers, preservation and maximum holding times.
// Water: US EPA 40 CFR Part 136 Table II and Standard Methods 1060.
// Soil / sediment: US EPA SW-846 Chapter 3/4 guidance.

import '../data/models.dart';

class HoldingRule {
  final String group;
  final List<String> keys; // lower-case words matched against the parameter name
  final String container;
  final String volume;
  final String preservation;
  final Duration hold;
  final String holdText;
  final bool solid;
  const HoldingRule(this.group, this.keys, this.container, this.volume, this.preservation, this.hold, this.holdText, {this.solid = false});
}

const holdingRules = <HoldingRule>[
  // Field parameters
  HoldingRule('Field', ['ph'], 'P / G', '50 mL', 'None — measure on site', Duration(minutes: 15), '15 minutes (analyse immediately)'),
  HoldingRule('Field', ['dissolved oxygen', 'do '], 'G (BOD bottle)', '300 mL', 'None — measure on site', Duration(minutes: 15), '15 minutes (analyse immediately)'),
  HoldingRule('Field', ['temperature'], 'P / G', '—', 'None — measure on site', Duration(minutes: 15), 'Immediately'),
  HoldingRule('Field', ['residual chlorine', 'free chlorine', 'chlorine'], 'P / G', '200 mL', 'None — measure on site', Duration(minutes: 15), '15 minutes'),
  HoldingRule('Physical', ['conductivity', 'ec'], 'P / G', '100 mL', 'Cool ≤ 6 °C', Duration(days: 28), '28 days'),
  HoldingRule('Physical', ['turbidity'], 'P / G', '100 mL', 'Cool ≤ 6 °C, dark', Duration(hours: 48), '48 hours'),
  HoldingRule('Physical', ['colour', 'color'], 'P / G', '50 mL', 'Cool ≤ 6 °C', Duration(hours: 48), '48 hours'),
  HoldingRule('Physical', ['total suspended', 'tss', 'suspended solids'], 'P / G', '500 mL', 'Cool ≤ 6 °C', Duration(days: 7), '7 days'),
  HoldingRule('Physical', ['total dissolved', 'tds', 'dissolved solids'], 'P / G', '250 mL', 'Cool ≤ 6 °C', Duration(days: 7), '7 days'),
  HoldingRule('Physical', ['alkalinity'], 'P / G', '200 mL', 'Cool ≤ 6 °C, fill to exclude air', Duration(days: 14), '14 days'),
  HoldingRule('Physical', ['hardness'], 'P / G', '100 mL', 'HNO3 or H2SO4 to pH < 2', Duration(days: 182), '6 months'),
  // Nutrients and anions
  HoldingRule('Nutrients', ['nitrate', 'no3'], 'P / G', '100 mL', 'Cool ≤ 6 °C', Duration(hours: 48), '48 hours (28 days as nitrate + nitrite with H2SO4)'),
  HoldingRule('Nutrients', ['nitrite', 'no2'], 'P / G', '100 mL', 'Cool ≤ 6 °C', Duration(hours: 48), '48 hours'),
  HoldingRule('Nutrients', ['ammonia', 'ammonium', 'nh3', 'nh4'], 'P / G', '400 mL', 'H2SO4 to pH < 2, cool ≤ 6 °C', Duration(days: 28), '28 days'),
  HoldingRule('Nutrients', ['orthophosphate', 'phosphate', 'po4'], 'P / G', '50 mL', 'Filter on site, cool ≤ 6 °C', Duration(hours: 48), '48 hours'),
  HoldingRule('Nutrients', ['total phosphorus', 'phosphorus'], 'P / G', '50 mL', 'H2SO4 to pH < 2, cool ≤ 6 °C', Duration(days: 28), '28 days'),
  HoldingRule('Nutrients', ['kjeldahl', 'tkn'], 'P / G', '500 mL', 'H2SO4 to pH < 2, cool ≤ 6 °C', Duration(days: 28), '28 days'),
  HoldingRule('Anions', ['chloride', 'cl-'], 'P / G', '50 mL', 'None', Duration(days: 28), '28 days'),
  HoldingRule('Anions', ['sulfate', 'sulphate', 'so4'], 'P / G', '50 mL', 'Cool ≤ 6 °C', Duration(days: 28), '28 days'),
  HoldingRule('Anions', ['fluoride'], 'P (not glass)', '300 mL', 'None', Duration(days: 28), '28 days'),
  HoldingRule('Anions', ['sulfide', 'sulphide'], 'P / G', '100 mL', 'Zinc acetate + NaOH to pH > 9, cool', Duration(days: 7), '7 days'),
  HoldingRule('Anions', ['cyanide'], 'P / G', '1 L', 'NaOH to pH > 10, cool ≤ 6 °C, dark', Duration(days: 14), '14 days'),
  // Organics / demand
  HoldingRule('Demand', ['bod'], 'P / G', '1 L', 'Cool ≤ 6 °C', Duration(hours: 48), '48 hours'),
  HoldingRule('Demand', ['cod'], 'P / G', '100 mL', 'H2SO4 to pH < 2, cool ≤ 6 °C', Duration(days: 28), '28 days'),
  HoldingRule('Demand', ['total organic carbon', 'toc'], 'G (amber)', '100 mL', 'H2SO4 or HCl to pH < 2, cool', Duration(days: 28), '28 days'),
  HoldingRule('Organics', ['oil and grease', 'oil & grease', 'grease', 'tph', 'hydrocarbon'], 'G (wide mouth)', '1 L', 'HCl or H2SO4 to pH < 2, cool', Duration(days: 28), '28 days'),
  HoldingRule('Organics', ['phenol'], 'G (amber)', '500 mL', 'H2SO4 to pH < 2, cool ≤ 6 °C', Duration(days: 28), '28 days'),
  // Microbiology
  HoldingRule('Microbiology', ['coli', 'coliform', 'enterococc', 'faecal', 'fecal', 'bacteria'], 'Sterile P / G', '250 mL', 'Na2S2O3 if chlorinated, cool < 10 °C', Duration(hours: 8), '8 hours (6 h transport + 2 h set-up)'),
  // Metals
  HoldingRule('Metals', ['chromium (vi)', 'cr(vi)', 'hexavalent'], 'P / G', '200 mL', 'Cool ≤ 6 °C', Duration(hours: 24), '24 hours'),
  HoldingRule('Metals', ['mercury', 'hg'], 'P / G', '500 mL', 'HNO3 to pH < 2', Duration(days: 28), '28 days'),
  HoldingRule('Metals', ['iron', 'manganese', 'lead', 'cadmium', 'copper', 'zinc', 'arsenic', 'nickel', 'chromium', 'aluminium', 'aluminum', 'cobalt', 'barium', 'selenium', 'silver', 'antimony', 'calcium', 'magnesium', 'sodium', 'potassium', 'bismuth', 'tin', 'metal', 'fe', 'mn', 'pb', 'cd', 'cu', 'zn', 'as', 'ni', 'cr', 'al'],
      'P (acid-washed)', '250 mL', 'HNO3 to pH < 2 (filter first for dissolved)', Duration(days: 182), '6 months'),
  // Soil / sediment
  HoldingRule('Soil & sediment', ['mercury', 'hg'], 'G jar', '250 g', 'Cool ≤ 6 °C', Duration(days: 28), '28 days', solid: true),
  HoldingRule('Soil & sediment', ['chromium (vi)', 'cr(vi)', 'hexavalent'], 'G / P jar', '100 g', 'Cool ≤ 6 °C', Duration(days: 30), '30 days to digestion', solid: true),
  HoldingRule('Soil & sediment', ['metal', 'iron', 'manganese', 'lead', 'cadmium', 'copper', 'zinc', 'arsenic', 'nickel', 'chromium', 'aluminium', 'aluminum', 'cobalt', 'fe', 'mn', 'pb', 'cd', 'cu', 'zn', 'as', 'ni', 'cr', 'al'],
      'G / P jar or bag', '250 g', 'Cool ≤ 6 °C (none required)', Duration(days: 180), '180 days', solid: true),
  HoldingRule('Soil & sediment', ['ph'], 'G / P jar or bag', '100 g', 'None', Duration(days: 7), '7 days (as soon as possible)', solid: true),
  HoldingRule('Soil & sediment', ['organic', 'toc', 'tph', 'hydrocarbon', 'oil'], 'G jar, PTFE lid', '250 g', 'Cool ≤ 6 °C', Duration(days: 14), '14 days', solid: true),
];

bool _keyHit(String name, String key) {
  final k = key.trim();
  if (k.length <= 3) {
    // short symbols must match a whole token: "Fe", "Iron (Fe)", "pH"
    return RegExp('(^|[^a-z])${RegExp.escape(k)}([^a-z]|\$)').hasMatch(name);
  }
  return name.contains(k);
}

/// Finds the holding rule for a parameter in a matrix, if any.
HoldingRule? holdingRule(String parameter, Matrix matrix) {
  final name = parameter.toLowerCase();
  final solid = matrix.isSolid;
  for (final r in holdingRules.where((r) => r.solid == solid)) {
    if (r.keys.any((k) => _keyHit(name, k))) return r;
  }
  return null;
}

class HoldingCheck {
  final Result result;
  final HoldingRule rule;
  final Duration elapsed;
  HoldingCheck(this.result, this.rule, this.elapsed);
  bool get exceeded => elapsed > rule.hold;
}

/// Results analysed after their maximum holding time (date of analysis vs
/// collection). Field parameters measured on site are not flagged.
List<HoldingCheck> holdingChecks(Sample s) {
  final out = <HoldingCheck>[];
  for (final r in s.results) {
    final rule = holdingRule(r.parameter, s.matrix);
    if (rule == null || rule.group == 'Field') continue;
    final elapsed = r.date.difference(s.collectedAt);
    if (elapsed.isNegative) continue;
    out.add(HoldingCheck(r, rule, elapsed));
  }
  return out;
}

List<HoldingCheck> holdingExceeded(Sample s) => holdingChecks(s).where((h) => h.exceeded).toList();

/// Latest date the sample can be analysed for every parameter on it.
DateTime? analyseBy(Sample s, Iterable<String> parameters) {
  DateTime? best;
  for (final p in parameters) {
    final rule = holdingRule(p, s.matrix);
    if (rule == null || rule.group == 'Field') continue;
    final d = s.collectedAt.add(rule.hold);
    if (best == null || d.isBefore(best)) best = d;
  }
  return best;
}

String durationText(Duration d) {
  if (d.inDays >= 2) return '${d.inDays} days';
  if (d.inHours >= 1) return '${d.inHours} h';
  return '${d.inMinutes} min';
}
