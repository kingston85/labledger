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

  /// Two-letter matrix code used in EPA sample IDs (e.g. KR-SW-001).
  String get code {
    switch (this) {
      case Matrix.drinkingWater:
        return 'DW';
      case Matrix.surfaceWater:
        return 'SW';
      case Matrix.groundwater:
        return 'GW';
      case Matrix.wastewater:
        return 'WW';
      case Matrix.soil:
        return 'SL';
      case Matrix.sediment:
        return 'SD';
      case Matrix.air:
        return 'AR';
      case Matrix.waste:
        return 'WS';
      case Matrix.other:
        return 'OT';
    }
  }
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
  List<double> replicates; // individual readings (e.g. triplicate); value holds their mean
  String enteredBy;
  String approvedBy;
  DateTime? approvedAt;
  bool get approved => approvedAt != null;

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
    List<double>? replicates,
    this.enteredBy = '',
    this.approvedBy = '',
    this.approvedAt,
  })  : date = date ?? DateTime.now(),
        replicates = replicates ?? [];

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
        'replicates': replicates,
        'enteredBy': enteredBy,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt?.toIso8601String(),
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
        replicates: [for (final v in (j['replicates'] as List? ?? const [])) (v as num).toDouble()],
        enteredBy: j['enteredBy'] as String? ?? '',
        approvedBy: j['approvedBy'] as String? ?? '',
        approvedAt: _tn(j['approvedAt']),
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
  SampleStatus _status;
  String? limitSetId;
  bool isControl; // upstream / background reference sample
  String? clientId;
  String? requestId;
  DateTime? dueDate;
  DateTime? reportedAt;
  String? tripId;
  String weather;
  String fieldNotes; // observations at the site: colour, odour, flow, activities nearby
  final List<String> photos; // file paths on this device

  SampleStatus get status => _status;
  set status(SampleStatus v) {
    if (v == SampleStatus.reported && _status != SampleStatus.reported) reportedAt ??= DateTime.now();
    if (v.index < SampleStatus.reported.index) reportedAt = null;
    _status = v;
  }

  /// Days from receipt to report (turnaround time), if reported.
  double? get turnaroundDays =>
      receivedAt == null || reportedAt == null ? null : reportedAt!.difference(receivedAt!).inMinutes / 1440.0;
  bool get overdue => dueDate != null && status.index < SampleStatus.reported.index && DateTime.now().isAfter(dueDate!);
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
    SampleStatus status = SampleStatus.collected,
    this.limitSetId,
    this.isControl = false,
    this.clientId,
    this.requestId,
    this.dueDate,
    this.reportedAt,
    this.tripId,
    this.weather = '',
    this.fieldNotes = '',
    List<String>? photos,
    List<Custody>? custody,
    List<Result>? results,
  })  : _status = status,
        photos = photos ?? [],
        collectedAt = collectedAt ?? DateTime.now(),
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
        'isControl': isControl,
        'clientId': clientId,
        'requestId': requestId,
        'dueDate': dueDate?.toIso8601String(),
        'reportedAt': reportedAt?.toIso8601String(),
        'tripId': tripId,
        'weather': weather,
        'fieldNotes': fieldNotes,
        'photos': photos,
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
        isControl: j['isControl'] as bool? ?? false,
        clientId: j['clientId'] as String?,
        requestId: j['requestId'] as String?,
        dueDate: _tn(j['dueDate']),
        reportedAt: _tn(j['reportedAt']),
        tripId: j['tripId'] as String?,
        weather: j['weather'] as String? ?? '',
        fieldNotes: j['fieldNotes'] as String? ?? '',
        photos: [for (final p in (j['photos'] as List? ?? const [])) p as String],
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
    if (min != null && max != null) return '${f(min!)}–${f(max!)} $unit'.trim();
    if (max != null) return '≤ ${f(max!)} $unit'.trim();
    if (min != null) return '≥ ${f(min!)} $unit'.trim();
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

/// Builds an EPA-style sample code: SITE-[C-]MATRIX-SEQ, e.g. KR-C-SW-004.
String buildSampleCode(String site, Matrix matrix, int seq, {bool control = false}) {
  final st = site.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
  return [if (st.isNotEmpty) st, if (control) 'C', matrix.code, seq.toString().padLeft(3, '0')].join('-');
}

/// The trailing sequence number of a code like "YC-SW-006" (6), or null.
int? codeSeq(String code) {
  final m = RegExp(r'(\d+)\s*$').firstMatch(code);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// True when a code marks a control sample ("KR-C-SW-004", "GR-C-SL-001").
bool codeLooksControl(String code) => RegExp(r'(^|-)C(-|$)').hasMatch(code.toUpperCase());

// ---------------------------------------------------------------------------
// Lab register: instruments and reagents / standards
// ---------------------------------------------------------------------------

class Instrument {
  final String id;
  String name;
  String model;
  String serial;
  String location;
  DateTime? lastCalibration;
  int calibrationDays; // interval; 0 = not scheduled
  DateTime? lastService;
  int serviceDays;
  bool inService;
  String notes;

  Instrument({
    required this.id,
    required this.name,
    this.model = '',
    this.serial = '',
    this.location = '',
    this.lastCalibration,
    this.calibrationDays = 365,
    this.lastService,
    this.serviceDays = 0,
    this.inService = true,
    this.notes = '',
  });

  DateTime? get calibrationDue => lastCalibration == null || calibrationDays <= 0 ? null : lastCalibration!.add(Duration(days: calibrationDays));
  DateTime? get serviceDue => lastService == null || serviceDays <= 0 ? null : lastService!.add(Duration(days: serviceDays));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'serial': serial,
        'location': location,
        'lastCalibration': lastCalibration?.toIso8601String(),
        'calibrationDays': calibrationDays,
        'lastService': lastService?.toIso8601String(),
        'serviceDays': serviceDays,
        'inService': inService,
        'notes': notes,
      };

  factory Instrument.fromJson(Map<String, dynamic> j) => Instrument(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        model: j['model'] as String? ?? '',
        serial: j['serial'] as String? ?? '',
        location: j['location'] as String? ?? '',
        lastCalibration: _tn(j['lastCalibration']),
        calibrationDays: (j['calibrationDays'] as num?)?.toInt() ?? 365,
        lastService: _tn(j['lastService']),
        serviceDays: (j['serviceDays'] as num?)?.toInt() ?? 0,
        inService: j['inService'] as bool? ?? true,
        notes: j['notes'] as String? ?? '',
      );
}

enum ReagentKind { reagent, standard, crm, consumable }

extension ReagentKindX on ReagentKind {
  String get label => const ['Reagent', 'Standard', 'CRM / reference', 'Consumable'][index];
}

class Reagent {
  final String id;
  String name;
  ReagentKind kind;
  String lot;
  String supplier;
  String location;
  DateTime? received;
  DateTime? opened;
  DateTime? expiry;
  double? quantity;
  String unit;
  double? minStock; // reorder level
  String notes;

  Reagent({
    required this.id,
    required this.name,
    this.kind = ReagentKind.reagent,
    this.lot = '',
    this.supplier = '',
    this.location = '',
    this.received,
    this.opened,
    this.expiry,
    this.quantity,
    this.unit = '',
    this.minStock,
    this.notes = '',
  });

  bool get lowStock => quantity != null && minStock != null && quantity! <= minStock!;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'lot': lot,
        'supplier': supplier,
        'location': location,
        'received': received?.toIso8601String(),
        'opened': opened?.toIso8601String(),
        'expiry': expiry?.toIso8601String(),
        'quantity': quantity,
        'unit': unit,
        'minStock': minStock,
        'notes': notes,
      };

  factory Reagent.fromJson(Map<String, dynamic> j) => Reagent(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        kind: _enum(ReagentKind.values, j['kind'], ReagentKind.reagent),
        lot: j['lot'] as String? ?? '',
        supplier: j['supplier'] as String? ?? '',
        location: j['location'] as String? ?? '',
        received: _tn(j['received']),
        opened: _tn(j['opened']),
        expiry: _tn(j['expiry']),
        quantity: _d(j['quantity']),
        unit: j['unit'] as String? ?? '',
        minStock: _d(j['minStock']),
        notes: j['notes'] as String? ?? '',
      );
}

/// Days from today to [d] (negative = past).
int daysUntil(DateTime d) {
  final n = DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inDays;
}

// ---------------------------------------------------------------------------
// Users and audit trail
// ---------------------------------------------------------------------------

enum Role { admin, reviewer, analyst, viewer }

extension RoleX on Role {
  String get label => const ['Administrator', 'Reviewer / approver', 'Analyst', 'Viewer (read-only)'][index];
  String get blurb => const [
        'Everything, including users, settings and deleting records',
        'Enter results and approve them for reporting',
        'Register samples and enter results; cannot approve',
        'Can look and export, cannot change anything',
      ][index];
}

class AppUser {
  final String id;
  String name;
  Role role;
  String salt;
  String pinHash;
  bool active;
  DateTime created;
  DateTime? lastLogin;

  AppUser({required this.id, required this.name, this.role = Role.analyst, this.salt = '', this.pinHash = '', this.active = true, DateTime? created, this.lastLogin})
      : created = created ?? DateTime.now();

  String get initials {
    final p = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.name,
        'salt': salt,
        'pinHash': pinHash,
        'active': active,
        'created': created.toIso8601String(),
        'lastLogin': lastLogin?.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        role: _enum(Role.values, j['role'], Role.analyst),
        salt: j['salt'] as String? ?? '',
        pinHash: j['pinHash'] as String? ?? '',
        active: j['active'] as bool? ?? true,
        created: _tn(j['created']),
        lastLogin: _tn(j['lastLogin']),
      );
}

class AuditEntry {
  final DateTime time;
  final String user;
  final String action; // create, update, delete, approve, login, export, import …
  final String entity; // Sample, Result, Invoice …
  final String ref; // code / number
  final String detail;
  const AuditEntry(this.time, this.user, this.action, this.entity, this.ref, this.detail);

  Map<String, dynamic> toJson() => {'t': time.toIso8601String(), 'u': user, 'a': action, 'e': entity, 'r': ref, 'd': detail};
  factory AuditEntry.fromJson(Map<String, dynamic> j) =>
      AuditEntry(_t(j['t']), j['u'] as String? ?? '', j['a'] as String? ?? '', j['e'] as String? ?? '', j['r'] as String? ?? '', j['d'] as String? ?? '');
}

// ---------------------------------------------------------------------------
// Clients, price list, requests and invoices
// ---------------------------------------------------------------------------

enum ClientType { company, government, ngo, individual, internal }

extension ClientTypeX on ClientType {
  String get label => const ['Company', 'Government', 'NGO / project', 'Individual', 'Internal'][index];
}

class Client {
  final String id;
  String name;
  ClientType type;
  String contact;
  String phone;
  String email;
  String address;
  String taxId;
  String notes;
  DateTime created;

  Client({required this.id, required this.name, this.type = ClientType.company, this.contact = '', this.phone = '', this.email = '', this.address = '', this.taxId = '', this.notes = '', DateTime? created})
      : created = created ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'contact': contact,
        'phone': phone,
        'email': email,
        'address': address,
        'taxId': taxId,
        'notes': notes,
        'created': created.toIso8601String(),
      };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        type: _enum(ClientType.values, j['type'], ClientType.company),
        contact: j['contact'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String? ?? '',
        address: j['address'] as String? ?? '',
        taxId: j['taxId'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        created: _tn(j['created']),
      );
}

/// A test or package on the lab's price list.
class PriceItem {
  final String id;
  String code;
  String name;
  String category;
  double price;
  int turnaroundDays;
  List<String> parameters; // parameters covered (for packages)
  bool active;
  String notes;

  PriceItem({required this.id, required this.code, required this.name, this.category = '', this.price = 0, this.turnaroundDays = 7, List<String>? parameters, this.active = true, this.notes = ''})
      : parameters = parameters ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'category': category,
        'price': price,
        'turnaroundDays': turnaroundDays,
        'parameters': parameters,
        'active': active,
        'notes': notes,
      };

  factory PriceItem.fromJson(Map<String, dynamic> j) => PriceItem(
        id: j['id'] as String,
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        price: _d(j['price']) ?? 0,
        turnaroundDays: (j['turnaroundDays'] as num?)?.toInt() ?? 7,
        parameters: [for (final p in (j['parameters'] as List? ?? const [])) p as String],
        active: j['active'] as bool? ?? true,
        notes: j['notes'] as String? ?? '',
      );
}

class DocLine {
  String description;
  double qty;
  double unitPrice;
  String? priceItemId;
  DocLine({required this.description, this.qty = 1, this.unitPrice = 0, this.priceItemId});
  double get total => qty * unitPrice;

  Map<String, dynamic> toJson() => {'description': description, 'qty': qty, 'unitPrice': unitPrice, 'priceItemId': priceItemId};
  factory DocLine.fromJson(Map<String, dynamic> j) =>
      DocLine(description: j['description'] as String? ?? '', qty: _d(j['qty']) ?? 1, unitPrice: _d(j['unitPrice']) ?? 0, priceItemId: j['priceItemId'] as String?);
}

/// Shared money arithmetic for quotations and invoices.
mixin Priced {
  List<DocLine> get lines;
  double get discountPct;
  double get taxPct;
  double get subtotal => lines.fold(0.0, (a, l) => a + l.total);
  double get discount => _round(subtotal * discountPct / 100);
  double get tax => _round((subtotal - discount) * taxPct / 100);
  double get total => _round(subtotal - discount + tax);
}

double _round(double v) => (v * 100).roundToDouble() / 100;

enum RequestStatus { quote, accepted, inProgress, completed, cancelled }

extension RequestStatusX on RequestStatus {
  String get label => const ['Quotation', 'Accepted', 'In progress', 'Completed', 'Cancelled'][index];
}

/// An analysis request / work order (starts life as a quotation).
class LabRequest with Priced {
  final String id;
  String number;
  String? clientId;
  DateTime date;
  DateTime? dueDate;
  String project;
  RequestStatus status;
  @override
  final List<DocLine> lines;
  @override
  double discountPct;
  @override
  double taxPct;
  String notes;

  LabRequest({
    required this.id,
    required this.number,
    this.clientId,
    DateTime? date,
    this.dueDate,
    this.project = '',
    this.status = RequestStatus.quote,
    List<DocLine>? lines,
    this.discountPct = 0,
    this.taxPct = 0,
    this.notes = '',
  })  : date = date ?? DateTime.now(),
        lines = lines ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'clientId': clientId,
        'date': date.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'project': project,
        'status': status.name,
        'lines': [for (final l in lines) l.toJson()],
        'discountPct': discountPct,
        'taxPct': taxPct,
        'notes': notes,
      };

  factory LabRequest.fromJson(Map<String, dynamic> j) => LabRequest(
        id: j['id'] as String,
        number: j['number'] as String? ?? '',
        clientId: j['clientId'] as String?,
        date: _t(j['date']),
        dueDate: _tn(j['dueDate']),
        project: j['project'] as String? ?? '',
        status: _enum(RequestStatus.values, j['status'], RequestStatus.quote),
        lines: [for (final l in (j['lines'] as List? ?? const [])) DocLine.fromJson((l as Map).cast<String, dynamic>())],
        discountPct: _d(j['discountPct']) ?? 0,
        taxPct: _d(j['taxPct']) ?? 0,
        notes: j['notes'] as String? ?? '',
      );
}

class Payment {
  final String id;
  DateTime date;
  double amount;
  String method; // Cash, Bank transfer, Mobile money, Cheque
  String reference;
  String receiptNo;
  Payment({required this.id, required this.amount, DateTime? date, this.method = 'Cash', this.reference = '', this.receiptNo = ''}) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {'id': id, 'date': date.toIso8601String(), 'amount': amount, 'method': method, 'reference': reference, 'receiptNo': receiptNo};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        date: _t(j['date']),
        amount: _d(j['amount']) ?? 0,
        method: j['method'] as String? ?? 'Cash',
        reference: j['reference'] as String? ?? '',
        receiptNo: j['receiptNo'] as String? ?? '',
      );
}

enum InvoiceStatus { draft, unpaid, partial, paid, overdue, cancelled }

extension InvoiceStatusX on InvoiceStatus {
  String get label => const ['Draft', 'Unpaid', 'Part paid', 'Paid', 'Overdue', 'Cancelled'][index];
}

class Invoice with Priced {
  final String id;
  String number;
  String? clientId;
  String? requestId;
  DateTime date;
  DateTime dueDate;
  @override
  final List<DocLine> lines;
  @override
  double discountPct;
  @override
  double taxPct;
  final List<Payment> payments;
  String notes;
  bool issued;
  bool cancelled;

  Invoice({
    required this.id,
    required this.number,
    this.clientId,
    this.requestId,
    DateTime? date,
    DateTime? dueDate,
    List<DocLine>? lines,
    this.discountPct = 0,
    this.taxPct = 0,
    List<Payment>? payments,
    this.notes = '',
    this.issued = true,
    this.cancelled = false,
  })  : date = date ?? DateTime.now(),
        dueDate = dueDate ?? (date ?? DateTime.now()).add(const Duration(days: 30)),
        lines = lines ?? [],
        payments = payments ?? [];

  double get paid => _round(payments.fold(0.0, (a, p) => a + p.amount));
  double get balance => _round(total - paid);

  InvoiceStatus get status {
    if (cancelled) return InvoiceStatus.cancelled;
    if (!issued) return InvoiceStatus.draft;
    if (balance <= 0.004 && total > 0) return InvoiceStatus.paid;
    if (DateTime.now().isAfter(dueDate)) return InvoiceStatus.overdue;
    if (paid > 0) return InvoiceStatus.partial;
    return InvoiceStatus.unpaid;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'clientId': clientId,
        'requestId': requestId,
        'date': date.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'lines': [for (final l in lines) l.toJson()],
        'discountPct': discountPct,
        'taxPct': taxPct,
        'payments': [for (final p in payments) p.toJson()],
        'notes': notes,
        'issued': issued,
        'cancelled': cancelled,
      };

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: j['id'] as String,
        number: j['number'] as String? ?? '',
        clientId: j['clientId'] as String?,
        requestId: j['requestId'] as String?,
        date: _t(j['date']),
        dueDate: _tn(j['dueDate']),
        lines: [for (final l in (j['lines'] as List? ?? const [])) DocLine.fromJson((l as Map).cast<String, dynamic>())],
        discountPct: _d(j['discountPct']) ?? 0,
        taxPct: _d(j['taxPct']) ?? 0,
        payments: [for (final p in (j['payments'] as List? ?? const [])) Payment.fromJson((p as Map).cast<String, dynamic>())],
        notes: j['notes'] as String? ?? '',
        issued: j['issued'] as bool? ?? true,
        cancelled: j['cancelled'] as bool? ?? false,
      );
}

String money(double v, String currency) {
  final neg = v < 0;
  final s = v.abs().toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  final sym = switch (currency) { 'USD' => r'$', 'LRD' => r'L$', 'EUR' => '€', 'GBP' => '£', _ => '$currency ' };
  return '${neg ? '-' : ''}$sym$whole.${parts[1]}';
}
