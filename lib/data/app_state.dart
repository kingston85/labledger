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
  String defaultLimitSetId = 'who-dw';
  bool daylight = false;
  double r2Min = 0.995;
  double rpdMax = 20;
  double spikeLo = 80, spikeHi = 120;
  double crmLo = 90, crmHi = 110;

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
    limitSets.insert(0, whoDrinkingWater());
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

  LimitSet? limitsFor(Sample s) => limitSetById(s.limitSetId ?? settings.defaultLimitSetId);

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
    samples.removeWhere((s) => s.project == 'Demo');
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
    final s1 = Sample(
      id: newId(),
      code: 'LAB-${now.year}-0001',
      site: 'Stream S1, upstream of mine',
      project: 'Demo',
      matrix: Matrix.surfaceWater,
      lat: 7.4321,
      lon: -8.5432,
      collectedAt: now.subtract(const Duration(days: 4)),
      receivedAt: now.subtract(const Duration(days: 3)),
      collector: 'Field team A',
      preservation: 'HNO3 to pH < 2, 4 °C',
      status: SampleStatus.reviewed,
      custody: [
        Custody(time: now.subtract(const Duration(days: 4)), from: 'Field team A', to: 'Driver', condition: 'Cool box, sealed'),
        Custody(time: now.subtract(const Duration(days: 3)), from: 'Driver', to: 'Lab reception', condition: '4 °C, seal intact'),
      ],
      results: [
        Result(id: newId(), parameter: 'pH', value: 6.8, unit: '', method: 'Electrometric'),
        Result(id: newId(), parameter: 'Turbidity', value: 3.2, unit: 'NTU', method: 'Nephelometric'),
        Result(id: newId(), parameter: 'Iron (Fe)', value: 0.21, unit: 'mg/L', method: 'AAS'),
        Result(id: newId(), parameter: 'Lead (Pb)', belowLod: true, lod: 0.005, unit: 'mg/L', method: 'AAS'),
        Result(id: newId(), parameter: 'Manganese (Mn)', value: 0.05, unit: 'mg/L', method: 'AAS'),
      ],
    );
    final s2 = Sample(
      id: newId(),
      code: 'LAB-${now.year}-0002',
      site: 'Stream S2, below tailings',
      project: 'Demo',
      matrix: Matrix.surfaceWater,
      lat: 7.4298,
      lon: -8.5401,
      collectedAt: now.subtract(const Duration(days: 4)),
      receivedAt: now.subtract(const Duration(days: 3)),
      collector: 'Field team A',
      preservation: 'HNO3 to pH < 2, 4 °C',
      status: SampleStatus.inAnalysis,
      custody: [
        Custody(time: now.subtract(const Duration(days: 4)), from: 'Field team A', to: 'Lab reception', condition: '4 °C'),
      ],
      results: [
        Result(id: newId(), parameter: 'pH', value: 3.9, unit: '', method: 'Electrometric', note: 'Acidic: possible acid mine drainage'),
        Result(id: newId(), parameter: 'Iron (Fe)', value: 4.6, unit: 'mg/L', method: 'AAS'),
        Result(id: newId(), parameter: 'Manganese (Mn)', value: 1.25, unit: 'mg/L', method: 'AAS'),
        Result(id: newId(), parameter: 'Lead (Pb)', value: 24, unit: 'µg/L', method: 'AAS'),
        Result(id: newId(), parameter: 'Cadmium (Cd)', value: 0.002, unit: 'mg/L', method: 'AAS'),
      ],
    );
    final s3 = Sample(
      id: newId(),
      code: 'LAB-${now.year}-0003',
      site: 'Community well W1',
      project: 'Demo',
      matrix: Matrix.groundwater,
      collectedAt: now.subtract(const Duration(days: 1)),
      collector: 'Field team B',
      status: SampleStatus.received,
    );
    samples.addAll([s3, s2, s1]);
    settings.nextSeq = 4;

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
