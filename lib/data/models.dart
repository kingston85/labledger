// LabLedger data model. Everything serialises to JSON for on-device storage.

int _seq = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';

double? _d(Object? v) => v == null ? null : (v as num).toDouble();
DateTime _t(Object? v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.now();
DateTime? _tn(Object? v) => v == null ? null : DateTime.tryParse(v as String);
T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

enum Matrix { drinkingWater, surfaceWater, groundwater, wastewater, soil, sediment, air, waste, other }

extension MatrixX on Matrix {
  String get label {
    switch (this) {
      case Matrix.drinkingWater:
        return 'Drinking water';
      case Matrix.surfaceWater:
        return 'Surface water';
      case Matrix.groundwater:
        return 'Groundwater';
      case Matrix.wastewater:
        return 'Wastewater / effluent';
      case Matrix.soil:
        return 'Soil';
      case Matrix.sediment:
        return 'Sediment';
      case Matrix.air:
        return 'Air';
      case Matrix.waste:
        return 'Waste / sludge';
      case Matrix.other:
        return 'Other';
    }
  }

  bool get isSolid => this == Matrix.soil || this == Matrix.sediment || this == Matrix.waste;
}

enum SampleStatus { collected, received, inAnalysis, reviewed, reported }

extension SampleStatusX on SampleStatus {
  String get label {
    switch (this) {
      case SampleStatus.collected:
        return 'Collected';
      case SampleStatus.received:
        return 'Received';
      case SampleStatus.inAnalysis:
        return 'In analysis';
      case SampleStatus.reviewed:
        return 'Reviewed';
      case SampleStatus.reported:
        return 'Reported';
    }
  }
}

class Custody {
  DateTime time;
  String from;
  String to;
  String condition;
  Custody({required this.time, required this.from, required this.to, this.condition = ''});

  Map<String, dynamic> toJson() => {'time': time.toIso8601String(), 'from': from, 'to': to, 'condition': condition};
  factory Custody.fromJson(Map<String, dynamic> j) =>
      Custody(time: _t(j['time']), from: j['from'] as String? ?? '', to: j['to'] as String? ?? '', condition: j['condition'] as String? ?? '');
}

class Result {
  final String id;
  String parameter;
  double? value;
  bool belowLod;
  double? lod;
  String unit;
  String method;
  String analyst;
  DateTime date;
  double dilution;
  String note;
  String source; // 'manual' or 'calibration'

  Result({
    required this.id,
    required this.parameter,
    this.value,
    this.belowLod = false,
    this.lod,
    this.unit = 'mg/L',
    this.method = '',
    this.analyst = '',
    DateTime? date,
    this.dilution = 1,
    this.note = '',
    this.source = 'manual',
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'parameter': parameter,
        'value': value,
        'belowLod': belowLod,
        'lod': lod,
        'unit': unit,
        'method': method,
        'analyst': analyst,
        'date': date.toIso8601String(),
        'dilution': dilution,
        'note': note,
        'source': source,
      };

  factory Result.fromJson(Map<String, dynamic> j) => Result(
        id: j['id'] as String,
        parameter: j['parameter'] as String? ?? '',
        value: _d(j['value']),
        belowLod: j['belowLod'] as bool? ?? false,
        lod: _d(j['lod']),
        unit: j['unit'] as String? ?? 'mg/L',
        method: j['method'] as String? ?? '',
        analyst: j['analyst'] as String? ?? '',
        date: _t(j['date']),
        dilution: _d(j['dilution']) ?? 1,
        note: j['note'] as String? ?? '',
        source: j['source'] as String? ?? 'manual',
      );
}

class Sample {
  final String id;
  String code;
  String site;
  String project;
  Matrix matrix;
  double? lat;
  double? lon;
  DateTime collectedAt;
  DateTime? receivedAt;
  String collector;
  String preservation;
  String notes;
  SampleStatus status;
  String? limitSetId;
  final List<Custody> custody;
  final List<Result> results;

  Sample({
    required this.id,
    required this.code,
    this.site = '',
    this.project = '',
    this.matrix = Matrix.surfaceWater,
    this.lat,
    this.lon,
    DateTime? collectedAt,
    this.receivedAt,
    this.collector = '',
    this.preservation = '',
    this.notes = '',
    this.status = SampleStatus.collected,
    this.limitSetId,
    List<Custody>? custody,
    List<Result>? results,
  })  : collectedAt = collectedAt ?? DateTime.now(),
        custody = custody ?? [],
        results = results ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'site': site,
        'project': project,
        'matrix': matrix.name,
        'lat': lat,
        'lon': lon,
        'collectedAt': collectedAt.toIso8601String(),
        'receivedAt': receivedAt?.toIso8601String(),
        'collector': collector,
        'preservation': preservation,
        'notes': notes,
        'status': status.name,
        'limitSetId': limitSetId,
        'custody': [for (final c in custody) c.toJson()],
        'results': [for (final r in results) r.toJson()],
      };

  factory Sample.fromJson(Map<String, dynamic> j) => Sample(
        id: j['id'] as String,
        code: j['code'] as String? ?? '',
        site: j['site'] as String? ?? '',
        project: j['project'] as String? ?? '',
        matrix: _enum(Matrix.values, j['matrix'], Matrix.other),
        lat: _d(j['lat']),
        lon: _d(j['lon']),
        collectedAt: _t(j['collectedAt']),
        receivedAt: _tn(j['receivedAt']),
        collector: j['collector'] as String? ?? '',
        preservation: j['preservation'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        status: _enum(SampleStatus.values, j['status'], SampleStatus.collected),
        limitSetId: j['limitSetId'] as String?,
        custody: [for (final c in (j['custody'] as List? ?? const [])) Custody.fromJson((c as Map).cast<String, dynamic>())],
        results: [for (final r in (j['results'] as List? ?? const [])) Result.fromJson((r as Map).cast<String, dynamic>())],
      );
}

class Limit {
  final double? min;
  final double? max;
  final String unit;
  final String note;
  const Limit({this.min, this.max, required this.unit, this.note = ''});

  Map<String, dynamic> toJson() => {'min': min, 'max': max, 'unit': unit, 'note': note};
  factory Limit.fromJson(Map<String, dynamic> j) =>
      Limit(min: _d(j['min']), max: _d(j['max']), unit: j['unit'] as String? ?? 'mg/L', note: j['note'] as String? ?? '');

  String get text {
    String f(double v) => v.toString().replaceFirst(RegExp(r'\.0$'), '');
    if (min != null && max != null) return '${f(min!)}–${f(max!)} $unit';
    if (max != null) return '≤ ${f(max!)} $unit';
    if (min != null) return '≥ ${f(min!)} $unit';
    return '—';
  }
}

class LimitSet {
  final String id;
  String name;
  String note;
  bool builtIn;
  final Map<String, Limit> limits; // parameter display name → limit

  LimitSet({required this.id, required this.name, this.note = '', this.builtIn = false, Map<String, Limit>? limits})
      : limits = limits ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'note': note,
        'builtIn': builtIn,
        'limits': {for (final e in limits.entries) e.key: e.value.toJson()},
      };

  factory LimitSet.fromJson(Map<String, dynamic> j) => LimitSet(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Limits',
        note: j['note'] as String? ?? '',
        builtIn: j['builtIn'] as bool? ?? false,
        limits: {
          for (final e in ((j['limits'] as Map?) ?? const {}).entries)
            e.key as String: Limit.fromJson((e.value as Map).cast<String, dynamic>()),
        },
      );
}

class CalReading {
  String sampleId; // may be empty for an unregistered unknown
  String label;
  double response;
  double dilution;
  CalReading({this.sampleId = '', this.label = '', required this.response, this.dilution = 1});

  Map<String, dynamic> toJson() => {'sampleId': sampleId, 'label': label, 'response': response, 'dilution': dilution};
  factory CalReading.fromJson(Map<String, dynamic> j) => CalReading(
        sampleId: j['sampleId'] as String? ?? '',
        label: j['label'] as String? ?? '',
        response: _d(j['response']) ?? 0,
        dilution: _d(j['dilution']) ?? 1,
      );
}

class CalibrationRun {
  final String id;
  String parameter;
  String unit;
  String method;
  String instrument;
  String analyst;
  DateTime date;
  List<List<double>> standards; // [concentration, response]
  bool throughOrigin;
  String notes;
  final List<CalReading> readings;

  CalibrationRun({
    required this.id,
    required this.parameter,
    this.unit = 'mg/L',
    this.method = '',
    this.instrument = '',
    this.analyst = '',
    DateTime? date,
    List<List<double>>? standards,
    this.throughOrigin = false,
    this.notes = '',
    List<CalReading>? readings,
  })  : date = date ?? DateTime.now(),
        standards = standards ?? [],
        readings = readings ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'parameter': parameter,
        'unit': unit,
        'method': method,
        'instrument': instrument,
        'analyst': analyst,
        'date': date.toIso8601String(),
        'standards': standards,
        'throughOrigin': throughOrigin,
        'notes': notes,
        'readings': [for (final r in readings) r.toJson()],
      };

  factory CalibrationRun.fromJson(Map<String, dynamic> j) => CalibrationRun(
        id: j['id'] as String,
        parameter: j['parameter'] as String? ?? '',
        unit: j['unit'] as String? ?? 'mg/L',
        method: j['method'] as String? ?? '',
        instrument: j['instrument'] as String? ?? '',
        analyst: j['analyst'] as String? ?? '',
        date: _t(j['date']),
        standards: [
          for (final s in (j['standards'] as List? ?? const []))
            [((s as List)[0] as num).toDouble(), (s[1] as num).toDouble()]
        ],
        throughOrigin: j['throughOrigin'] as bool? ?? false,
        notes: j['notes'] as String? ?? '',
        readings: [for (final r in (j['readings'] as List? ?? const [])) CalReading.fromJson((r as Map).cast<String, dynamic>())],
      );
}

enum QcType { blank, duplicate, spike, crm, ccv }

extension QcTypeX on QcType {
  String get label {
    switch (this) {
      case QcType.blank:
        return 'Method blank';
      case QcType.duplicate:
        return 'Duplicate';
      case QcType.spike:
        return 'Matrix spike';
      case QcType.crm:
        return 'CRM / reference';
      case QcType.ccv:
        return 'Calibration check (CCV)';
    }
  }

  List<String> get fields {
    switch (this) {
      case QcType.blank:
        return ['Blank result', 'Reporting limit / LOD'];
      case QcType.duplicate:
        return ['Result 1', 'Result 2'];
      case QcType.spike:
        return ['Spiked sample', 'Unspiked sample', 'Amount added'];
      case QcType.crm:
      case QcType.ccv:
        return ['Measured', 'Certified / true value'];
    }
  }
}

class QcCheck {
  final String id;
  QcType type;
  String parameter;
  String unit;
  String batch;
  DateTime date;
  List<double> values;
  String note;

  QcCheck({
    required this.id,
    required this.type,
    required this.parameter,
    this.unit = 'mg/L',
    this.batch = '',
    DateTime? date,
    List<double>? values,
    this.note = '',
  })  : date = date ?? DateTime.now(),
        values = values ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'parameter': parameter,
        'unit': unit,
        'batch': batch,
        'date': date.toIso8601String(),
        'values': values,
        'note': note,
      };

  factory QcCheck.fromJson(Map<String, dynamic> j) => QcCheck(
        id: j['id'] as String,
        type: _enum(QcType.values, j['type'], QcType.blank),
        parameter: j['parameter'] as String? ?? '',
        unit: j['unit'] as String? ?? 'mg/L',
        batch: j['batch'] as String? ?? '',
        date: _t(j['date']),
        values: [for (final v in (j['values'] as List? ?? const [])) (v as num).toDouble()],
        note: j['note'] as String? ?? '',
      );
}

class ControlPoint {
  DateTime date;
  double value;
  String note;
  ControlPoint({required this.date, required this.value, this.note = ''});
  Map<String, dynamic> toJson() => {'date': date.toIso8601String(), 'value': value, 'note': note};
  factory ControlPoint.fromJson(Map<String, dynamic> j) =>
      ControlPoint(date: _t(j['date']), value: _d(j['value']) ?? 0, note: j['note'] as String? ?? '');
}

class ControlChart {
  final String id;
  String name;
  String parameter;
  String unit;
  double? targetMean; // fixed limits if set
  double? targetSd;
  final List<ControlPoint> points;

  ControlChart({
    required this.id,
    required this.name,
    required this.parameter,
    this.unit = 'mg/L',
    this.targetMean,
    this.targetSd,
    List<ControlPoint>? points,
  }) : points = points ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parameter': parameter,
        'unit': unit,
        'targetMean': targetMean,
        'targetSd': targetSd,
        'points': [for (final p in points) p.toJson()],
      };

  factory ControlChart.fromJson(Map<String, dynamic> j) => ControlChart(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Control chart',
        parameter: j['parameter'] as String? ?? '',
        unit: j['unit'] as String? ?? 'mg/L',
        targetMean: _d(j['targetMean']),
        targetSd: _d(j['targetSd']),
        points: [for (final p in (j['points'] as List? ?? const [])) ControlPoint.fromJson((p as Map).cast<String, dynamic>())],
      );
}

String shortDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String timeOfDay(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String dateTime(DateTime d) => '${shortDate(d)} ${timeOfDay(d)}';
