import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/location_service.dart';
import 'models.dart';
import 'storage.dart';

class LabSettings {
  String labName = 'ERRS Laboratory, EPA Liberia';
  String analyst = '';
  String reviewer = '';
  String idPrefix = 'LAB';
  int nextSeq = 1;
  String defaultLimitSetId = 'lr-epa-w1';
  bool daylight = false;
  double r2Min = 0.995;
  double rpdMax = 20;
  double spikeLo = 80, spikeHi = 120;
  double crmLo = 90, crmHi = 110;
  double replicateRsdMax = 10;

  Map<String, dynamic> toJson() => {
        'labName': labName,
        'analyst': analyst,
        'reviewer': reviewer,
        'idPrefix': idPrefix,
        'nextSeq': nextSeq,
        'defaultLimitSetId': defaultLimitSetId,
        'daylight': daylight,
        'r2Min': r2Min,
        'rpdMax': rpdMax,
        'spikeLo': spikeLo,
        'spikeHi': spikeHi,
        'crmLo': crmLo,
        'crmHi': crmHi,
        'replicateRsdMax': replicateRsdMax,
      };

  void load(Map<String, dynamic> j) {
    labName = j['labName'] as String? ?? labName;
    analyst = j['analyst'] as String? ?? analyst;
    reviewer = j['reviewer'] as String? ?? reviewer;
    idPrefix = j['idPrefix'] as String? ?? idPrefix;
    nextSeq = (j['nextSeq'] as num?)?.toInt() ?? nextSeq;
    defaultLimitSetId = j['defaultLimitSetId'] as String? ?? defaultLimitSetId;
    daylight = j['daylight'] as bool? ?? daylight;
    r2Min = (j['r2Min'] as num?)?.toDouble() ?? r2Min;
    rpdMax = (j['rpdMax'] as num?)?.toDouble() ?? rpdMax;
    spikeLo = (j['spikeLo'] as num?)?.toDouble() ?? spikeLo;
    spikeHi = (j['spikeHi'] as num?)?.toDouble() ?? spikeHi;
    crmLo = (j['crmLo'] as num?)?.toDouble() ?? crmLo;
    crmHi = (j['crmHi'] as num?)?.toDouble() ?? crmHi;
    replicateRsdMax = (j['replicateRsdMax'] as num?)?.toDouble() ?? replicateRsdMax;
  }
}

class AppState extends ChangeNotifier {
  final LocationService location = LocationService();
  final LabSettings settings = LabSettings();
  final List<Sample> samples = [];
  final List<LimitSet> limitSets = [];
  final List<CalibrationRun> runs = [];
  final List<QcCheck> qc = [];
  final List<ControlChart> charts = [];
  bool hasDemo = false;

  bool _loaded = false;
  Timer? _timer;

  Future<void> init() async {
    final data = await Storage.load();
    if (data == null) {
      _ensureBuiltIns();
      _loadDemo();
    } else {
      _fromJson(data);
      _ensureBuiltIns();
    }
    _loaded = true;
  }

  void _ensureBuiltIns() {
    limitSets.removeWhere((s) => s.builtIn);
    limitSets.insertAll(0, [liberiaWater(), whoDrinkingWater()]);
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_loaded) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), saveNow);
  }

  Future<void> saveNow() async {
    _timer?.cancel();
    try {
      await Storage.save(toJson());
    } catch (_) {}
  }

  void update(VoidCallback f) {
    f();
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'settings': settings.toJson(),
        'hasDemo': hasDemo,
        'samples': [for (final s in samples) s.toJson()],
        'limitSets': [for (final s in limitSets.where((s) => !s.builtIn)) s.toJson()],
        'runs': [for (final r in runs) r.toJson()],
        'qc': [for (final q in qc) q.toJson()],
        'charts': [for (final c in charts) c.toJson()],
      };

  void _fromJson(Map<String, dynamic> j) {
    settings.load((j['settings'] as Map?)?.cast<String, dynamic>() ?? const {});
    hasDemo = j['hasDemo'] as bool? ?? false;
    List<Map<String, dynamic>> list(String k) => [for (final e in (j[k] as List? ?? const [])) (e as Map).cast<String, dynamic>()];
    samples
      ..clear()
      ..addAll(list('samples').map(Sample.fromJson));
    limitSets
      ..clear()
      ..addAll(list('limitSets').map(LimitSet.fromJson));
    runs
      ..clear()
      ..addAll(list('runs').map(CalibrationRun.fromJson));
    qc
      ..clear()
      ..addAll(list('qc').map(QcCheck.fromJson));
    charts
      ..clear()
      ..addAll(list('charts').map(ControlChart.fromJson));
  }

  /// Replaces everything with the contents of a backup file.
  void restore(Map<String, dynamic> data) {
    _fromJson(data);
    _ensureBuiltIns();
    notifyListeners();
  }

  // ---------------- Helpers ----------------

  String nextCode() => '${settings.idPrefix}-${DateTime.now().year}-${settings.nextSeq.toString().padLeft(4, '0')}';

  Sample addSample(Sample s) {
    samples.insert(0, s);
    settings.nextSeq++;
    notifyListeners();
    return s;
  }

  Sample? sampleById(String id) {
    for (final s in samples) {
      if (s.id == id) return s;
    }
    return null;
  }

  LimitSet? limitSetById(String? id) {
    if (id == null) return null;
    for (final s in limitSets) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Project names with their samples, most recently collected first.
  List<(String, List<Sample>)> get projects {
    final m = <String, List<Sample>>{};
    for (final s in samples) {
      final k = s.project.trim().isEmpty ? 'Unassigned' : s.project.trim();
      (m[k] ??= []).add(s);
    }
    final out = [for (final e in m.entries) (e.key, e.value)];
    DateTime latest(List<Sample> l) => l.map((s) => s.collectedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    out.sort((a, b) => latest(b.$2).compareTo(latest(a.$2)));
    return out;
  }

  List<Sample> samplesInProject(String project) => samples
      .where((s) => project == 'Unassigned' ? s.project.trim().isEmpty : s.project.trim() == project)
      .toList();

  /// Next sequence number for EPA-style codes within a project (KR-SW-001, YC-SW-002 …).
  int nextProjectSeq(String project) {
    var m = 0;
    for (final s in samples.where((s) => s.project.trim() == project.trim())) {
      final q = codeSeq(s.code);
      if (q != null && q > m && q < 10000) m = q;
    }
    return m + 1;
  }

  /// Limits that apply to a sample. Built-in sets are water standards, so
  /// they are never applied to soil, sediment or waste.
  LimitSet? limitsFor(Sample s) {
    final set = limitSetById(s.limitSetId ?? settings.defaultLimitSetId);
    if (set != null && set.builtIn && s.matrix.isSolid) return null;
    return set;
  }

  List<(Sample, Result, Check)> get exceedances {
    final out = <(Sample, Result, Check)>[];
    for (final s in samples) {
      final set = limitsFor(s);
      for (final r in s.results) {
        final c = checkResult(r, set);
        if (c.status == Compliance.exceed || c.status == Compliance.belowMin) out.add((s, r, c));
      }
    }
    return out;
  }

  bool qcPasses(QcCheck q) => qcEvaluate(q).$1;

  /// Returns (pass, headline value, explanation).
  (bool, double, String) qcEvaluate(QcCheck q) {
    final v = q.values;
    double at(int i) => i < v.length ? v[i] : double.nan;
    switch (q.type) {
      case QcType.blank:
        final pass = at(0) < at(1);
        return (pass, at(0), pass ? 'Blank below the reporting limit' : 'Blank at or above the reporting limit: contamination');
      case QcType.duplicate:
        final m = (at(0) + at(1)) / 2;
        final r = m == 0 ? 0.0 : (at(0) - at(1)).abs() / m * 100;
        final pass = r <= settings.rpdMax;
        return (pass, r, 'RPD ${r.toStringAsFixed(1)}% (limit ≤ ${settings.rpdMax.toStringAsFixed(0)}%)');
      case QcType.spike:
        final r = at(2) == 0 ? double.nan : (at(0) - at(1)) / at(2) * 100;
        final pass = r >= settings.spikeLo && r <= settings.spikeHi;
        return (pass, r,
            'Recovery ${r.toStringAsFixed(1)}% (accept ${settings.spikeLo.toStringAsFixed(0)}–${settings.spikeHi.toStringAsFixed(0)}%)');
      case QcType.crm:
      case QcType.ccv:
        final r = at(1) == 0 ? double.nan : at(0) / at(1) * 100;
        final pass = r >= settings.crmLo && r <= settings.crmHi;
        return (pass, r,
            'Recovery ${r.toStringAsFixed(1)}% (accept ${settings.crmLo.toStringAsFixed(0)}–${settings.crmHi.toStringAsFixed(0)}%)');
    }
  }

  void clearDemo() {
    samples.removeWhere((s) => s.project.startsWith('Demo'));
    runs.removeWhere((r) => r.notes.startsWith('Demo'));
    qc.removeWhere((q) => q.batch == 'DEMO');
    charts.removeWhere((c) => c.name.startsWith('Demo'));
    hasDemo = false;
    notifyListeners();
  }

  void _loadDemo() {
    hasDemo = true;
    final now = DateTime.now();
    final rnd = math.Random(7);

    samples.addAll(_boloDemo());
    samples.addAll(_soilDemo());

    runs.add(CalibrationRun(
      id: newId(),
      parameter: 'Lead (Pb)',
      unit: 'mg/L',
      method: 'Flame AAS 217.0 nm',
      instrument: 'AAS',
      date: now.subtract(const Duration(days: 2)),
      standards: [
        [0, 0.0012],
        [0.5, 0.0215],
        [1, 0.0431],
        [2, 0.0847],
        [4, 0.1702],
        [6, 0.2539],
      ],
      notes: 'Demo calibration',
    ));

    qc.addAll([
      QcCheck(id: newId(), type: QcType.blank, parameter: 'Lead (Pb)', batch: 'DEMO', values: [0.002, 0.005]),
      QcCheck(id: newId(), type: QcType.duplicate, parameter: 'Iron (Fe)', batch: 'DEMO', values: [4.6, 4.3]),
      QcCheck(id: newId(), type: QcType.spike, parameter: 'Lead (Pb)', batch: 'DEMO', values: [1.02, 0.024, 1.0]),
      QcCheck(id: newId(), type: QcType.crm, parameter: 'Manganese (Mn)', batch: 'DEMO', values: [0.47, 0.50]),
    ]);

    final pts = <ControlPoint>[];
    for (var i = 0; i < 24; i++) {
      // Box-Muller normal noise around 2.00 mg/L, sd 0.04, with a late upward drift.
      final u1 = rnd.nextDouble().clamp(1e-9, 1.0), u2 = rnd.nextDouble();
      final z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
      final drift = i >= 19 ? 0.07 : 0.0;
      pts.add(ControlPoint(date: now.subtract(Duration(days: 24 - i)), value: 2.0 + 0.04 * z + drift));
    }
    charts.add(ControlChart(
      id: newId(),
      name: 'Demo: Pb 2.00 mg/L check standard',
      parameter: 'Lead (Pb)',
      targetMean: 2.0,
      targetSd: 0.04,
      points: pts,
    ));
  }

  // Demo investigation built from the published results of the EPA Liberia
  // Bolo Town water investigation (Aug 2026, tables 4a/4b; triplicate means).
  List<Sample> _boloDemo() {
    const project = 'Demo: Bolo Town water investigation';
    const params = [
      ('pH', ''), ('ORP', 'mV'), ('Salinity', 'ppt'), ('Electrical conductivity', 'µS/cm'), ('Turbidity', 'NTU'),
      ('Total dissolved solids', 'mg/L'), ('Nitrate (as NO3)', 'mg/L'), ('Nitrite (as NO2)', 'mg/L'), ('Ammonia', 'mg/L'),
      ('Iron (Fe)', 'mg/L'), ('Chromium (Cr)', 'mg/L'), ('Copper (Cu)', 'mg/L'), ('Aluminium (Al)', 'mg/L'),
      ('Bismuth (Bi)', 'mg/L'), ('Beryllium (Be)', 'mg/L'), ('Boron (B)', 'mg/L'), ('Cadmium (Cd)', 'mg/L'),
      ('Lead (Pb)', 'mg/L'), ('Lithium (Li)', 'mg/L'), ('Manganese (Mn)', 'mg/L'), ('Strontium (Sr)', 'mg/L'),
      ('Titanium (Ti)', 'mg/L'), ('Zinc (Zn)', 'mg/L'), ('Sulfate', 'mg/L'),
    ];
    // code, site, matrix, lat, lon, hh:mm, control, values (same order as params)
    const rows = [
      ('KR-SW-001', 'Karn River main stem below mining discharge routes', Matrix.surfaceWater, 7.543189, -8.608411, 12, 28, false,
          '6.47 14.4 0.02 156 20.7 23 14 0.02 0.1 2.77 0.28 0.49 0.81 0.84 <0.001 1.08 0.005 0.005 <0.001 1.02 0.005 0.007 1.08 26.77'),
      ('KR-SW-002', 'Karn River, secondary downstream point', Matrix.surfaceWater, 7.547365, -8.607679, 12, 36, false,
          '8.13 -2.8 0.04 194 26.1 47 37 0.004 0.25 2.20 0.16 0.40 0.71 0.71 <0.001 0.99 0.002 0.013 <0.001 0.97 0.001 0.005 0.77 24.33'),
      ('YC-SW-003', 'Yeewah Creek above the confluence', Matrix.surfaceWater, 7.547428, -8.608640, 12, 54, false,
          '7.17 -8.8 0.04 184 109 42 34 0.007 0.1 2.10 0.21 0.72 0.83 0.74 <0.001 1.07 0.001 0.009 <0.001 1.07 0.004 0.007 0.97 26.83'),
      ('KR-C-SW-004', 'Karn River upstream control, outside the runoff path', Matrix.surfaceWater, 7.547436, -8.608511, 13, 0, true,
          '7.19 -9.3 0.04 92 9.89 46 25 0.022 0.15 0.08 0.48 0.38 0.071 <0.01 <0.001 0.077 <0.001 <0.001 <0.001 0.003 0.001 0.005 0.38 15.83'),
      ('YC-SW-005', 'Yeewah Creek below the Yuelliton/Gangra confluence', Matrix.surfaceWater, 7.552410, -8.611755, 13, 24, false,
          '6.97 -3.5 0.03 169 141 35 24 0.009 0.0 2.10 0.04 0.55 0.71 0.73 <0.001 1.28 0.002 0.005 <0.001 1.17 0.005 0.009 1.08 25.73'),
      ('YC-SW-006', 'Yeewah Creek downstream, combined load', Matrix.surfaceWater, 7.553984, -8.614395, 13, 39, false,
          '6.42 3.0 0.02 36 163 18 42 0.013 0.0 2.06 0.03 0.47 0.82 0.61 <0.001 1.19 0.002 0.005 <0.001 1.09 0.007 0.006 1.07 24.38'),
      ('YLC-SW-007', 'Yuelliton Creek, direct mine drainage', Matrix.surfaceWater, 7.553172, -8.614763, 13, 49, false,
          '6.41 9.3 0.03 64 129 32 27 0.000 0.05 2.16 0.13 0.09 0.76 0.73 <0.001 1.05 0.003 0.016 <0.001 1.07 0.004 0.005 1.12 25.97'),
      ('YC-G-SW-008', 'Gangra Wenneh Creek into the Yeewah confluence', Matrix.surfaceWater, 7.553141, -8.614760, 13, 48, false,
          '6.64 10.3 0.03 169 36.7 35 24 0.009 0.05 2.03 0.28 0.48 0.61 0.63 <0.001 0.88 0.001 0.011 <0.001 1.28 0.003 0.005 0.99 26.63'),
      ('BT-GW-009', 'Bolo Town main community hand pump', Matrix.groundwater, 7.5427192, -8.6069047, 15, 3, false,
          '5.79 22.5 0.09 207 2.57 104 44 0.016 0.5 2.07 0.42 0.03 0.73 0.83 <0.001 0.91 0.003 0.005 <0.001 1.19 0.005 0.007 0.87 25.59'),
    ];
    final out = <Sample>[];
    for (final r in rows) {
      final when = DateTime(2026, 8, 13, r.$6, r.$7);
      final vals = r.$9.split(' ');
      out.add(Sample(
        id: newId(),
        code: r.$1,
        site: r.$2,
        project: project,
        matrix: r.$3,
        lat: r.$4,
        lon: r.$5,
        collectedAt: when,
        receivedAt: DateTime(2026, 8, 15, 9, 0),
        collector: 'EPA ERRS field team',
        preservation: 'Pre-treated lab bottle, 4 °C',
        status: SampleStatus.reviewed,
        isControl: r.$8,
        limitSetId: 'lr-epa-w1',
        custody: [
          Custody(time: when, from: 'EPA ERRS field team', to: 'Lab reception, Mamba Point', condition: 'Cool box, sealed'),
        ],
        results: [
          for (var i = 0; i < params.length; i++)
            () {
              final p = parseResultText(vals[i]);
              return Result(
                id: newId(),
                parameter: params[i].$1,
                value: p.value,
                belowLod: p.belowLod,
                lod: p.lod,
                unit: params[i].$2,
                method: defaultMethods[params[i].$1] ?? '',
                date: DateTime(2026, 8, 15),
                note: 'Mean of triplicate',
              );
            }(),
        ],
      ));
    }
    return out;
  }

  // Soil demo from the Bonlah investigation (Nov 2025, table 11, Gbai River).
  List<Sample> _soilDemo() {
    const project = 'Demo: Bonlah soil (Gbai River)';
    const params = [
      'pH', 'Aluminium (Al)', 'Bismuth (Bi)', 'Iron (Fe)', 'Arsenic (As)', 'Selenium (Se)', 'Barium (Ba)', 'Boron (B)',
      'Cadmium (Cd)', 'Chromium (Cr)', 'Copper (Cu)', 'Lead (Pb)', 'Manganese (Mn)', 'Zinc (Zn)',
    ];
    const rows = [
      ('GR-C-SL-001', 'Golay River control, outside the spill path', true,
          '6.37 0.12 0.20 0.61 0.11 0.009 0.088 0.208 <0.001 0.226 0.106 0.011 0.009 0.618'),
      ('GR-SL-001', 'Gbai River bank, farmland 1', false, '5.58 2.77 3.28 8.01 0.109 0.299 0.662 2.543 0.044 2.995 2.066 0.117 2.17 1.692'),
      ('GR-SL-002', 'Gbai River bank, farmland 2', false, '5.77 2.59 3.11 7.54 0.103 0.286 0.582 2.258 0.031 2.974 2.061 0.102 2.08 1.661'),
      ('GR-SL-003', 'Gbai River bank, farmland 3', false, '5.94 2.53 2.37 7.28 0.082 0.162 0.528 2.195 0.027 2.811 2.055 0.099 1.99 1.582'),
      ('GR-SL-004', 'Gbai River bank, farmland 4', false, '5.99 2.37 2.33 7.03 0.077 0.118 0.493 2.176 0.019 2.806 2.017 0.086 1.96 1.472'),
      ('GR-SL-005', 'Gbai River bank, farmland 5', false, '6.02 1.77 1.97 6.91 0.083 0.109 0.448 2.099 0.015 2.798 1.997 0.083 1.88 1.442'),
      ('GR-SL-006', 'Gbai River bank, farmland 6', false, '6.11 1.58 1.86 6.73 0.099 0.102 0.418 2.086 0.009 2.775 1.973 0.081 1.77 1.427'),
    ];
    final out = <Sample>[];
    for (var k = 0; k < rows.length; k++) {
      final r = rows[k];
      final vals = r.$4.split(' ');
      out.add(Sample(
        id: newId(),
        code: r.$1,
        site: r.$2,
        project: project,
        matrix: Matrix.soil,
        collectedAt: DateTime(2025, 11, 7, 9, 10 + 12 * k),
        receivedAt: DateTime(2025, 11, 10, 9, 0),
        collector: 'EPA ERRS field team',
        preservation: 'Polythene bag, cool box',
        status: SampleStatus.reviewed,
        isControl: r.$3,
        results: [
          for (var i = 0; i < params.length; i++)
            () {
              final p = parseResultText(vals[i]);
              return Result(
                id: newId(),
                parameter: params[i],
                value: p.value,
                belowLod: p.belowLod,
                lod: p.lod,
                unit: i == 0 ? '' : 'mg/kg',
                method: defaultMethods[params[i]] ?? '',
                date: DateTime(2025, 11, 12),
              );
            }(),
        ],
      ));
    }
    return out;
  }

  @override
  void dispose() {
    location.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}
