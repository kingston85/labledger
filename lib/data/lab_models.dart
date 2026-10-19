// LabLedger 1.1 data: field trips, stock movements, purchase requests,
// equipment maintenance log, method library, proficiency tests,
// non-conformances (CAPA) and the register of issued reports.

double? _d(Object? v) => v == null ? null : (v as num).toDouble();
DateTime _t(Object? v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.now();
DateTime? _tn(Object? v) => v == null ? null : DateTime.tryParse(v as String);
T _enum<T extends Enum>(List<T> values, Object? name, T fallback) => values.firstWhere((e) => e.name == name, orElse: () => fallback);
List<String> _strs(Object? v) => [for (final x in (v as List? ?? const [])) x as String];
List<Map<String, dynamic>> _maps(Object? v) => [for (final x in (v as List? ?? const [])) (x as Map).cast<String, dynamic>()];

// ---------------------------------------------------------------------------
// Field work
// ---------------------------------------------------------------------------

enum TripStatus { planned, inField, completed, cancelled }

extension TripStatusX on TripStatus {
  String get label => const ['Planned', 'In the field', 'Completed', 'Cancelled'][index];
}

class PlannedSite {
  String name;
  String code;
  double? lat, lon;
  String matrix; // Matrix.name
  String parameters; // free text: "metals, nutrients, field params"
  bool sampled;
  PlannedSite({required this.name, this.code = '', this.lat, this.lon, this.matrix = 'surfaceWater', this.parameters = '', this.sampled = false});

  Map<String, dynamic> toJson() => {'name': name, 'code': code, 'lat': lat, 'lon': lon, 'matrix': matrix, 'parameters': parameters, 'sampled': sampled};
  factory PlannedSite.fromJson(Map<String, dynamic> j) => PlannedSite(
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        lat: _d(j['lat']),
        lon: _d(j['lon']),
        matrix: j['matrix'] as String? ?? 'surfaceWater',
        parameters: j['parameters'] as String? ?? '',
        sampled: j['sampled'] as bool? ?? false,
      );
}

class CheckItem {
  String text;
  bool done;
  CheckItem(this.text, [this.done = false]);
  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory CheckItem.fromJson(Map<String, dynamic> j) => CheckItem(j['text'] as String? ?? '', j['done'] as bool? ?? false);
}

/// The standard pre-departure checklist for a sampling trip.
List<CheckItem> defaultTripChecklist() => [
      for (final t in const [
        'Sampling plan and site list printed',
        'Sample bottles labelled (metals, nutrients, micro)',
        'Preservatives packed (HNO3, H2SO4, NaOH, thiosulfate)',
        'Cooler boxes and ice packs (≤ 6 °C)',
        'Multiparameter meter calibrated (pH, EC, DO, ORP)',
        'Turbidity meter checked',
        'GPS / phone charged, LabLedger synced',
        'Chain-of-custody forms',
        'Field blank and duplicate bottles',
        'PPE: gloves, boots, life jacket, first-aid kit',
        'Vehicle, fuel and driver confirmed',
        'Community / site access permission',
      ])
        CheckItem(t),
    ];

class FieldTrip {
  final String id;
  String title;
  String project;
  String? clientId;
  String? requestId;
  DateTime date;
  DateTime? returnDate;
  List<String> team;
  String vehicle;
  String objective;
  TripStatus status;
  final List<PlannedSite> sites;
  final List<CheckItem> checklist;
  String notes;

  FieldTrip({
    required this.id,
    required this.title,
    this.project = '',
    this.clientId,
    this.requestId,
    DateTime? date,
    this.returnDate,
    List<String>? team,
    this.vehicle = '',
    this.objective = '',
    this.status = TripStatus.planned,
    List<PlannedSite>? sites,
    List<CheckItem>? checklist,
    this.notes = '',
  })  : date = date ?? DateTime.now(),
        team = team ?? [],
        sites = sites ?? [],
        checklist = checklist ?? defaultTripChecklist();

  double get checklistProgress => checklist.isEmpty ? 1 : checklist.where((c) => c.done).length / checklist.length;
  int get sitesSampled => sites.where((s) => s.sampled).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'project': project,
        'clientId': clientId,
        'requestId': requestId,
        'date': date.toIso8601String(),
        'returnDate': returnDate?.toIso8601String(),
        'team': team,
        'vehicle': vehicle,
        'objective': objective,
        'status': status.name,
        'sites': [for (final s in sites) s.toJson()],
        'checklist': [for (final c in checklist) c.toJson()],
        'notes': notes,
      };

  factory FieldTrip.fromJson(Map<String, dynamic> j) => FieldTrip(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        project: j['project'] as String? ?? '',
        clientId: j['clientId'] as String?,
        requestId: j['requestId'] as String?,
        date: _t(j['date']),
        returnDate: _tn(j['returnDate']),
        team: _strs(j['team']),
        vehicle: j['vehicle'] as String? ?? '',
        objective: j['objective'] as String? ?? '',
        status: _enum(TripStatus.values, j['status'], TripStatus.planned),
        sites: _maps(j['sites']).map(PlannedSite.fromJson).toList(),
        checklist: _maps(j['checklist']).map(CheckItem.fromJson).toList(),
        notes: j['notes'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// Inventory and equipment
// ---------------------------------------------------------------------------

enum StockReason { received, used, disposed, adjusted }

extension StockReasonX on StockReason {
  String get label => const ['Received', 'Used', 'Disposed / expired', 'Stock count adjustment'][index];
}

class StockMove {
  final String id;
  final String reagentId;
  DateTime date;
  double qty; // positive in, negative out
  StockReason reason;
  String user;
  String note;
  StockMove({required this.id, required this.reagentId, DateTime? date, required this.qty, this.reason = StockReason.used, this.user = '', this.note = ''})
      : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {'id': id, 'reagentId': reagentId, 'date': date.toIso8601String(), 'qty': qty, 'reason': reason.name, 'user': user, 'note': note};
  factory StockMove.fromJson(Map<String, dynamic> j) => StockMove(
        id: j['id'] as String,
        reagentId: j['reagentId'] as String? ?? '',
        date: _t(j['date']),
        qty: _d(j['qty']) ?? 0,
        reason: _enum(StockReason.values, j['reason'], StockReason.used),
        user: j['user'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

enum PurchaseStatus { draft, submitted, approved, ordered, received, cancelled }

extension PurchaseStatusX on PurchaseStatus {
  String get label => const ['Draft', 'Submitted', 'Approved', 'Ordered', 'Received', 'Cancelled'][index];
}

class PurchaseLine {
  String description;
  double qty;
  String unit;
  double unitPrice;
  String? reagentId;
  PurchaseLine({required this.description, this.qty = 1, this.unit = '', this.unitPrice = 0, this.reagentId});
  double get total => qty * unitPrice;
  Map<String, dynamic> toJson() => {'description': description, 'qty': qty, 'unit': unit, 'unitPrice': unitPrice, 'reagentId': reagentId};
  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(
        description: j['description'] as String? ?? '',
        qty: _d(j['qty']) ?? 1,
        unit: j['unit'] as String? ?? '',
        unitPrice: _d(j['unitPrice']) ?? 0,
        reagentId: j['reagentId'] as String?,
      );
}

class PurchaseRequest {
  final String id;
  String number;
  DateTime date;
  String requestedBy;
  String supplier;
  String justification;
  PurchaseStatus status;
  final List<PurchaseLine> lines;
  String approvedBy;
  String notes;
  PurchaseRequest({
    required this.id,
    required this.number,
    DateTime? date,
    this.requestedBy = '',
    this.supplier = '',
    this.justification = '',
    this.status = PurchaseStatus.draft,
    List<PurchaseLine>? lines,
    this.approvedBy = '',
    this.notes = '',
  })  : date = date ?? DateTime.now(),
        lines = lines ?? [];

  double get total => (lines.fold(0.0, (a, l) => a + l.total) * 100).roundToDouble() / 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'date': date.toIso8601String(),
        'requestedBy': requestedBy,
        'supplier': supplier,
        'justification': justification,
        'status': status.name,
        'lines': [for (final l in lines) l.toJson()],
        'approvedBy': approvedBy,
        'notes': notes,
      };
  factory PurchaseRequest.fromJson(Map<String, dynamic> j) => PurchaseRequest(
        id: j['id'] as String,
        number: j['number'] as String? ?? '',
        date: _t(j['date']),
        requestedBy: j['requestedBy'] as String? ?? '',
        supplier: j['supplier'] as String? ?? '',
        justification: j['justification'] as String? ?? '',
        status: _enum(PurchaseStatus.values, j['status'], PurchaseStatus.draft),
        lines: _maps(j['lines']).map(PurchaseLine.fromJson).toList(),
        approvedBy: j['approvedBy'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
      );
}

enum MaintenanceKind { calibration, verification, service, repair, cleaning }

extension MaintenanceKindX on MaintenanceKind {
  String get label => const ['Calibration', 'Performance check', 'Service', 'Repair', 'Cleaning'][index];
}

class MaintenanceLog {
  final String id;
  final String instrumentId;
  DateTime date;
  MaintenanceKind kind;
  String by;
  String outcome; // pass / fail / text
  bool passed;
  String certificate;
  double? cost;
  String notes;
  MaintenanceLog({
    required this.id,
    required this.instrumentId,
    DateTime? date,
    this.kind = MaintenanceKind.calibration,
    this.by = '',
    this.outcome = '',
    this.passed = true,
    this.certificate = '',
    this.cost,
    this.notes = '',
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'instrumentId': instrumentId,
        'date': date.toIso8601String(),
        'kind': kind.name,
        'by': by,
        'outcome': outcome,
        'passed': passed,
        'certificate': certificate,
        'cost': cost,
        'notes': notes,
      };
  factory MaintenanceLog.fromJson(Map<String, dynamic> j) => MaintenanceLog(
        id: j['id'] as String,
        instrumentId: j['instrumentId'] as String? ?? '',
        date: _t(j['date']),
        kind: _enum(MaintenanceKind.values, j['kind'], MaintenanceKind.calibration),
        by: j['by'] as String? ?? '',
        outcome: j['outcome'] as String? ?? '',
        passed: j['passed'] as bool? ?? true,
        certificate: j['certificate'] as String? ?? '',
        cost: _d(j['cost']),
        notes: j['notes'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// Quality system
// ---------------------------------------------------------------------------

enum MethodStatus { draft, validated, active, retired }

extension MethodStatusX on MethodStatus {
  String get label => const ['Draft', 'Validated', 'Active', 'Retired'][index];
}

class MethodRevision {
  String version;
  DateTime date;
  String change;
  String by;
  MethodRevision({required this.version, DateTime? date, this.change = '', this.by = ''}) : date = date ?? DateTime.now();
  Map<String, dynamic> toJson() => {'version': version, 'date': date.toIso8601String(), 'change': change, 'by': by};
  factory MethodRevision.fromJson(Map<String, dynamic> j) =>
      MethodRevision(version: j['version'] as String? ?? '', date: _t(j['date']), change: j['change'] as String? ?? '', by: j['by'] as String? ?? '');
}

/// A test method / SOP with its performance characteristics.
class LabMethod {
  final String id;
  String code; // SOP-MET-01 or APHA 3111 B
  String title;
  String version;
  MethodStatus status;
  String technique; // AAS, ICP-OES, titration, UV-Vis…
  String reference; // APHA 23rd ed., US EPA 200.7…
  List<String> parameters;
  String matrices;
  String unit;
  double? mdl;
  double? loq;
  double? uncertaintyPct; // expanded, k = 2
  double? recoveryLo, recoveryHi;
  String? instrumentId;
  DateTime? effective;
  DateTime? reviewDue;
  final List<MethodRevision> revisions;
  String notes;

  LabMethod({
    required this.id,
    required this.code,
    required this.title,
    this.version = '1.0',
    this.status = MethodStatus.active,
    this.technique = '',
    this.reference = '',
    List<String>? parameters,
    this.matrices = '',
    this.unit = 'mg/L',
    this.mdl,
    this.loq,
    this.uncertaintyPct,
    this.recoveryLo,
    this.recoveryHi,
    this.instrumentId,
    this.effective,
    this.reviewDue,
    List<MethodRevision>? revisions,
    this.notes = '',
  })  : parameters = parameters ?? [],
        revisions = revisions ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'version': version,
        'status': status.name,
        'technique': technique,
        'reference': reference,
        'parameters': parameters,
        'matrices': matrices,
        'unit': unit,
        'mdl': mdl,
        'loq': loq,
        'uncertaintyPct': uncertaintyPct,
        'recoveryLo': recoveryLo,
        'recoveryHi': recoveryHi,
        'instrumentId': instrumentId,
        'effective': effective?.toIso8601String(),
        'reviewDue': reviewDue?.toIso8601String(),
        'revisions': [for (final r in revisions) r.toJson()],
        'notes': notes,
      };
  factory LabMethod.fromJson(Map<String, dynamic> j) => LabMethod(
        id: j['id'] as String,
        code: j['code'] as String? ?? '',
        title: j['title'] as String? ?? '',
        version: j['version'] as String? ?? '1.0',
        status: _enum(MethodStatus.values, j['status'], MethodStatus.active),
        technique: j['technique'] as String? ?? '',
        reference: j['reference'] as String? ?? '',
        parameters: _strs(j['parameters']),
        matrices: j['matrices'] as String? ?? '',
        unit: j['unit'] as String? ?? 'mg/L',
        mdl: _d(j['mdl']),
        loq: _d(j['loq']),
        uncertaintyPct: _d(j['uncertaintyPct']),
        recoveryLo: _d(j['recoveryLo']),
        recoveryHi: _d(j['recoveryHi']),
        instrumentId: j['instrumentId'] as String?,
        effective: _tn(j['effective']),
        reviewDue: _tn(j['reviewDue']),
        revisions: _maps(j['revisions']).map(MethodRevision.fromJson).toList(),
        notes: j['notes'] as String? ?? '',
      );
}

class PtResult {
  String parameter;
  String unit;
  double? reported;
  double? assigned;
  double? sigma; // standard deviation for proficiency assessment
  PtResult({required this.parameter, this.unit = 'mg/L', this.reported, this.assigned, this.sigma});

  /// z = (x − X) / σpt
  double? get z => reported == null || assigned == null || sigma == null || sigma == 0 ? null : (reported! - assigned!) / sigma!;

  Map<String, dynamic> toJson() => {'parameter': parameter, 'unit': unit, 'reported': reported, 'assigned': assigned, 'sigma': sigma};
  factory PtResult.fromJson(Map<String, dynamic> j) =>
      PtResult(parameter: j['parameter'] as String? ?? '', unit: j['unit'] as String? ?? 'mg/L', reported: _d(j['reported']), assigned: _d(j['assigned']), sigma: _d(j['sigma']));
}

/// ISO 13528 interpretation of a z-score.
enum PtVerdict { satisfactory, questionable, unsatisfactory }

extension PtVerdictX on PtVerdict {
  String get label => const ['Satisfactory', 'Questionable', 'Unsatisfactory'][index];
}

PtVerdict? ptVerdict(double? z) {
  if (z == null) return null;
  final a = z.abs();
  if (a <= 2) return PtVerdict.satisfactory;
  if (a < 3) return PtVerdict.questionable;
  return PtVerdict.unsatisfactory;
}

class PtRound {
  final String id;
  String provider; // e.g. ERA, LGC AQUACHECK, inter-lab comparison
  String scheme;
  String round;
  String matrix;
  DateTime date;
  DateTime? reportDue;
  final List<PtResult> results;
  String notes;
  PtRound({required this.id, this.provider = '', this.scheme = '', this.round = '', this.matrix = '', DateTime? date, this.reportDue, List<PtResult>? results, this.notes = ''})
      : date = date ?? DateTime.now(),
        results = results ?? [];

  int count(PtVerdict v) => results.where((r) => ptVerdict(r.z) == v).length;
  int get scored => results.where((r) => r.z != null).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider,
        'scheme': scheme,
        'round': round,
        'matrix': matrix,
        'date': date.toIso8601String(),
        'reportDue': reportDue?.toIso8601String(),
        'results': [for (final r in results) r.toJson()],
        'notes': notes,
      };
  factory PtRound.fromJson(Map<String, dynamic> j) => PtRound(
        id: j['id'] as String,
        provider: j['provider'] as String? ?? '',
        scheme: j['scheme'] as String? ?? '',
        round: j['round'] as String? ?? '',
        matrix: j['matrix'] as String? ?? '',
        date: _t(j['date']),
        reportDue: _tn(j['reportDue']),
        results: _maps(j['results']).map(PtResult.fromJson).toList(),
        notes: j['notes'] as String? ?? '',
      );
}

enum NcSource { qcFailure, proficiencyTest, complaint, audit, equipment, sampleHandling, other }

extension NcSourceX on NcSource {
  String get label => const ['QC failure', 'Proficiency test', 'Client complaint', 'Audit finding', 'Equipment', 'Sample handling', 'Other'][index];
}

enum NcSeverity { minor, major, critical }

extension NcSeverityX on NcSeverity {
  String get label => const ['Minor', 'Major', 'Critical'][index];
}

enum NcStatus { open, investigating, actionTaken, closed }

extension NcStatusX on NcStatus {
  String get label => const ['Open', 'Investigating', 'Action taken', 'Closed'][index];
}

/// Non-conformance with root cause and corrective / preventive action.
class NonConformance {
  final String id;
  String number;
  DateTime date;
  String raisedBy;
  NcSource source;
  NcSeverity severity;
  NcStatus status;
  String title;
  String description;
  String reference; // sample code, PT round, instrument…
  String immediateAction;
  String rootCause;
  String correctiveAction;
  String preventiveAction;
  String owner;
  DateTime? dueDate;
  DateTime? closedAt;
  String effectiveness;
  NonConformance({
    required this.id,
    required this.number,
    DateTime? date,
    this.raisedBy = '',
    this.source = NcSource.qcFailure,
    this.severity = NcSeverity.minor,
    this.status = NcStatus.open,
    this.title = '',
    this.description = '',
    this.reference = '',
    this.immediateAction = '',
    this.rootCause = '',
    this.correctiveAction = '',
    this.preventiveAction = '',
    this.owner = '',
    this.dueDate,
    this.closedAt,
    this.effectiveness = '',
  }) : date = date ?? DateTime.now();

  bool get isOpen => status != NcStatus.closed;
  bool get overdue => isOpen && dueDate != null && DateTime.now().isAfter(dueDate!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'date': date.toIso8601String(),
        'raisedBy': raisedBy,
        'source': source.name,
        'severity': severity.name,
        'status': status.name,
        'title': title,
        'description': description,
        'reference': reference,
        'immediateAction': immediateAction,
        'rootCause': rootCause,
        'correctiveAction': correctiveAction,
        'preventiveAction': preventiveAction,
        'owner': owner,
        'dueDate': dueDate?.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
        'effectiveness': effectiveness,
      };
  factory NonConformance.fromJson(Map<String, dynamic> j) => NonConformance(
        id: j['id'] as String,
        number: j['number'] as String? ?? '',
        date: _t(j['date']),
        raisedBy: j['raisedBy'] as String? ?? '',
        source: _enum(NcSource.values, j['source'], NcSource.other),
        severity: _enum(NcSeverity.values, j['severity'], NcSeverity.minor),
        status: _enum(NcStatus.values, j['status'], NcStatus.open),
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        reference: j['reference'] as String? ?? '',
        immediateAction: j['immediateAction'] as String? ?? '',
        rootCause: j['rootCause'] as String? ?? '',
        correctiveAction: j['correctiveAction'] as String? ?? '',
        preventiveAction: j['preventiveAction'] as String? ?? '',
        owner: j['owner'] as String? ?? '',
        dueDate: _tn(j['dueDate']),
        closedAt: _tn(j['closedAt']),
        effectiveness: j['effectiveness'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// Issued reports (for QR verification)
// ---------------------------------------------------------------------------

class IssuedReport {
  final String id;
  String number; // RPT-2026-0001
  DateTime issued;
  String issuedBy;
  List<String> sampleIds;
  List<String> sampleCodes;
  String hash; // fingerprint of the results at the time of issue
  IssuedReport({required this.id, required this.number, DateTime? issued, this.issuedBy = '', List<String>? sampleIds, List<String>? sampleCodes, this.hash = ''})
      : issued = issued ?? DateTime.now(),
        sampleIds = sampleIds ?? [],
        sampleCodes = sampleCodes ?? [];

  Map<String, dynamic> toJson() =>
      {'id': id, 'number': number, 'issued': issued.toIso8601String(), 'issuedBy': issuedBy, 'sampleIds': sampleIds, 'sampleCodes': sampleCodes, 'hash': hash};
  factory IssuedReport.fromJson(Map<String, dynamic> j) => IssuedReport(
        id: j['id'] as String,
        number: j['number'] as String? ?? '',
        issued: _t(j['issued']),
        issuedBy: j['issuedBy'] as String? ?? '',
        sampleIds: _strs(j['sampleIds']),
        sampleCodes: _strs(j['sampleCodes']),
        hash: j['hash'] as String? ?? '',
      );
}
