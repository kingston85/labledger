import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/location_service.dart';
import 'lab_models.dart';
import 'lab_ops.dart';
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
  String labAddress = 'Mamba Point, Monrovia, Liberia';
  String labPhone = '';
  String labEmail = '';
  String currency = 'USD';
  double defaultTaxPct = 0;
  int paymentTermsDays = 30;
  String bankDetails = '';
  bool requireApproval = true;
  int autoLockMinutes = 10;
  String logoB64 = ''; // PNG/JPEG shown on reports
  bool qrOnReports = true;
  String accreditation = ''; // e.g. "ISO/IEC 17025:2017 (in preparation)"
  String reportNote = '';

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
        'labAddress': labAddress,
        'labPhone': labPhone,
        'labEmail': labEmail,
        'currency': currency,
        'defaultTaxPct': defaultTaxPct,
        'paymentTermsDays': paymentTermsDays,
        'bankDetails': bankDetails,
        'requireApproval': requireApproval,
        'autoLockMinutes': autoLockMinutes,
        'logoB64': logoB64,
        'qrOnReports': qrOnReports,
        'accreditation': accreditation,
        'reportNote': reportNote,
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
    labAddress = j['labAddress'] as String? ?? labAddress;
    labPhone = j['labPhone'] as String? ?? labPhone;
    labEmail = j['labEmail'] as String? ?? labEmail;
    currency = j['currency'] as String? ?? currency;
    defaultTaxPct = (j['defaultTaxPct'] as num?)?.toDouble() ?? defaultTaxPct;
    paymentTermsDays = (j['paymentTermsDays'] as num?)?.toInt() ?? paymentTermsDays;
    bankDetails = j['bankDetails'] as String? ?? bankDetails;
    requireApproval = j['requireApproval'] as bool? ?? requireApproval;
    autoLockMinutes = (j['autoLockMinutes'] as num?)?.toInt() ?? autoLockMinutes;
    logoB64 = j['logoB64'] as String? ?? logoB64;
    qrOnReports = j['qrOnReports'] as bool? ?? qrOnReports;
    accreditation = j['accreditation'] as String? ?? accreditation;
    reportNote = j['reportNote'] as String? ?? reportNote;
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
  final List<Instrument> instruments = [];
  final List<Reagent> reagents = [];
  final List<AppUser> users = [];
  final List<AuditEntry> audit = [];
  final List<Client> clients = [];
  final List<PriceItem> prices = [];
  final List<LabRequest> requests = [];
  final List<Invoice> invoices = [];
  final List<FieldTrip> trips = [];
  final List<StockMove> stockMoves = [];
  final List<PurchaseRequest> purchases = [];
  final List<MaintenanceLog> maintenance = [];
  final List<LabMethod> methods = [];
  final List<PtRound> ptRounds = [];
  final List<NonConformance> ncs = [];
  final List<IssuedReport> issuedReports = [];
  final Set<String> demoIds = {};
  AppUser? currentUser;
  DateTime lastActivity = DateTime.now();
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
        'instruments': [for (final i in instruments) i.toJson()],
        'reagents': [for (final r in reagents) r.toJson()],
        'users': [for (final u in users) u.toJson()],
        'audit': [for (final a in audit.length > 5000 ? audit.sublist(audit.length - 5000) : audit) a.toJson()],
        'clients': [for (final c in clients) c.toJson()],
        'prices': [for (final p in prices) p.toJson()],
        'requests': [for (final r in requests) r.toJson()],
        'invoices': [for (final i in invoices) i.toJson()],
        'trips': [for (final t in trips) t.toJson()],
        'stockMoves': [for (final m in stockMoves) m.toJson()],
        'purchases': [for (final p in purchases) p.toJson()],
        'maintenance': [for (final m in maintenance) m.toJson()],
        'methods': [for (final m in methods) m.toJson()],
        'ptRounds': [for (final r in ptRounds) r.toJson()],
        'ncs': [for (final n in ncs) n.toJson()],
        'issuedReports': [for (final r in issuedReports) r.toJson()],
        'demoIds': demoIds.toList(),
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
    instruments
      ..clear()
      ..addAll(list('instruments').map(Instrument.fromJson));
    reagents
      ..clear()
      ..addAll(list('reagents').map(Reagent.fromJson));
    users
      ..clear()
      ..addAll(list('users').map(AppUser.fromJson));
    audit
      ..clear()
      ..addAll(list('audit').map(AuditEntry.fromJson));
    clients
      ..clear()
      ..addAll(list('clients').map(Client.fromJson));
    prices
      ..clear()
      ..addAll(list('prices').map(PriceItem.fromJson));
    requests
      ..clear()
      ..addAll(list('requests').map(LabRequest.fromJson));
    invoices
      ..clear()
      ..addAll(list('invoices').map(Invoice.fromJson));
    trips
      ..clear()
      ..addAll(list('trips').map(FieldTrip.fromJson));
    stockMoves
      ..clear()
      ..addAll(list('stockMoves').map(StockMove.fromJson));
    purchases
      ..clear()
      ..addAll(list('purchases').map(PurchaseRequest.fromJson));
    maintenance
      ..clear()
      ..addAll(list('maintenance').map(MaintenanceLog.fromJson));
    methods
      ..clear()
      ..addAll(list('methods').map(LabMethod.fromJson));
    ptRounds
      ..clear()
      ..addAll(list('ptRounds').map(PtRound.fromJson));
    ncs
      ..clear()
      ..addAll(list('ncs').map(NonConformance.fromJson));
    issuedReports
      ..clear()
      ..addAll(list('issuedReports').map(IssuedReport.fromJson));
    demoIds
      ..clear()
      ..addAll([for (final x in (j['demoIds'] as List? ?? const [])) x as String]);
  }

  /// Replaces everything with the contents of a backup file.
  void restore(Map<String, dynamic> data) {
    final who = userName;
    _fromJson(data);
    _ensureBuiltIns();
    currentUser = null;
    log('restore', 'Backup', '', '${samples.length} samples restored', asUser: who);
    notifyListeners();
  }

  // ---------------- Users, permissions, audit ----------------

  bool get usersEnabled => users.any((u) => u.active);
  bool get locked => usersEnabled && currentUser == null;
  Role get role => currentUser?.role ?? Role.admin;
  String get userName => currentUser?.name ?? (settings.analyst.isEmpty ? 'Lab user' : settings.analyst);
  bool get canEdit => role != Role.viewer;
  bool get canApprove => role == Role.admin || role == Role.reviewer;
  bool get isAdmin => role == Role.admin;

  static String hashPin(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin:labledger')).toString();

  static String newSalt() {
    final r = math.Random.secure();
    return base64Url.encode(List<int>.generate(12, (_) => r.nextInt(256)));
  }

  void setPin(AppUser u, String pin) {
    u.salt = newSalt();
    u.pinHash = hashPin(u.salt, pin);
  }

  bool login(AppUser u, String pin) {
    if (!u.active || hashPin(u.salt, pin) != u.pinHash) {
      log('login failed', 'User', u.name, '', asUser: u.name);
      notifyListeners();
      return false;
    }
    currentUser = u;
    u.lastLogin = DateTime.now();
    lastActivity = DateTime.now();
    log('login', 'User', u.name, '');
    notifyListeners();
    return true;
  }

  void logout() {
    if (currentUser != null) log('logout', 'User', currentUser!.name, '');
    currentUser = null;
    notifyListeners();
  }

  void touch() => lastActivity = DateTime.now();

  /// Appends to the audit trail (call inside or outside update()).
  void log(String action, String entity, String ref, String detail, {String? asUser}) {
    audit.add(AuditEntry(DateTime.now(), asUser ?? userName, action, entity, ref, detail));
  }

  // ---------------- Business helpers ----------------

  Client? client(String? id) {
    if (id == null) return null;
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  LabRequest? request(String? id) {
    if (id == null) return null;
    for (final r in requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  PriceItem? priceItem(String? id) {
    if (id == null) return null;
    for (final p in prices) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Next document number like REQ-2026-0007 within the current year.
  String nextNumber(String prefix, Iterable<String> existing) {
    final y = DateTime.now().year;
    var m = 0;
    final re = RegExp('^$prefix-$y-(\\d+)\$');
    for (final e in existing) {
      final mm = re.firstMatch(e);
      if (mm != null) m = math.max(m, int.parse(mm.group(1)!));
    }
    return '$prefix-$y-${(m + 1).toString().padLeft(4, '0')}';
  }

  String nextRequestNumber() => nextNumber('REQ', requests.map((r) => r.number));
  String nextInvoiceNumber() => nextNumber('INV', invoices.map((i) => i.number));
  String nextReceiptNumber() => nextNumber('RCT', invoices.expand((i) => i.payments).map((p) => p.receiptNo));

  List<Sample> samplesForRequest(String requestId) => samples.where((s) => s.requestId == requestId).toList();

  /// Creates an invoice from a request's lines.
  Invoice invoiceFromRequest(LabRequest r) {
    final inv = Invoice(
      id: newId(),
      number: nextInvoiceNumber(),
      clientId: r.clientId,
      requestId: r.id,
      dueDate: DateTime.now().add(Duration(days: settings.paymentTermsDays)),
      lines: [for (final l in r.lines) DocLine(description: l.description, qty: l.qty, unitPrice: l.unitPrice, priceItemId: l.priceItemId)],
      discountPct: r.discountPct,
      taxPct: r.taxPct,
      notes: r.project.isEmpty ? '' : 'Project: ${r.project}',
    );
    invoices.insert(0, inv);
    log('create', 'Invoice', inv.number, 'from ${r.number}, ${money(inv.total, settings.currency)}');
    return inv;
  }

  double get outstanding => invoices.where((i) => !i.cancelled && i.issued).fold(0.0, (a, i) => a + (i.balance > 0 ? i.balance : 0));

  /// Approves every unapproved result of a sample.
  int approveSample(Sample s) {
    var n = 0;
    for (final r in s.results.where((r) => !r.approved)) {
      r.approvedBy = userName;
      r.approvedAt = DateTime.now();
      n++;
    }
    if (n > 0) {
      if (s.status.index < SampleStatus.reviewed.index) s.status = SampleStatus.reviewed;
      log('approve', 'Sample', s.code, '$n result${n == 1 ? '' : 's'} approved');
    }
    return n;
  }

  bool needsApproval(Sample s) => settings.requireApproval && s.results.any((r) => !r.approved);

  // ---------------- Helpers ----------------

  String nextCode() => '${settings.idPrefix}-${DateTime.now().year}-${settings.nextSeq.toString().padLeft(4, '0')}';

  Sample addSample(Sample s) {
    samples.insert(0, s);
    settings.nextSeq++;
    log('create', 'Sample', s.code, [s.matrix.label, s.project, client(s.clientId)?.name ?? ''].where((x) => x.isNotEmpty).join(' · '));
    notifyListeners();
    return s;
  }

  Sample? sampleById(String id) {
    for (final s in samples) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Register items needing attention: (title, detail, severity 2 = overdue/expired, 1 = soon).
  List<(String, String, int)> get registerAlerts {
    final out = <(String, String, int)>[];
    for (final i in instruments.where((i) => i.inService)) {
      for (final (what, due) in [('calibration', i.calibrationDue), ('service', i.serviceDue)]) {
        if (due == null) continue;
        final d = daysUntil(due);
        if (d < 0) {
          out.add((i.name, '${what[0].toUpperCase()}${what.substring(1)} overdue by ${-d} day${d == -1 ? '' : 's'}', 2));
        } else if (d <= 14) {
          out.add((i.name, '${what[0].toUpperCase()}${what.substring(1)} due in $d day${d == 1 ? '' : 's'}', 1));
        }
      }
    }
    for (final r in reagents) {
      if (r.expiry != null) {
        final d = daysUntil(r.expiry!);
        if (d < 0) {
          out.add((r.name, 'Expired ${shortDate(r.expiry!)}${r.lot.isEmpty ? '' : ' · lot ${r.lot}'}', 2));
        } else if (d <= 30) {
          out.add((r.name, 'Expires in $d day${d == 1 ? '' : 's'}${r.lot.isEmpty ? '' : ' · lot ${r.lot}'}', 1));
        }
      }
      if (r.lowStock) out.add((r.name, 'Low stock: ${r.quantity} ${r.unit}', 1));
    }
    out.sort((a, b) => b.$3.compareTo(a.$3));
    return out;
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
    instruments.removeWhere((i) => i.notes == 'Demo item');
    clients.removeWhere((c) => c.notes == 'Demo item');
    prices.removeWhere((p) => p.notes == 'Demo item');
    requests.removeWhere((r) => r.notes == 'Demo item');
    invoices.removeWhere((i) => i.notes == 'Demo item');
    reagents.removeWhere((r) => r.notes == 'Demo item');
    trips.removeWhere((t) => demoIds.contains(t.id));
    purchases.removeWhere((p) => demoIds.contains(p.id));
    methods.removeWhere((m) => demoIds.contains(m.id));
    ptRounds.removeWhere((r) => demoIds.contains(r.id));
    ncs.removeWhere((n) => demoIds.contains(n.id));
    maintenance.removeWhere((m) => demoIds.contains(m.id));
    stockMoves.removeWhere((m) => demoIds.contains(m.id));
    demoIds.clear();
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

    _loadBusinessDemo(now);
    instruments.addAll([
      Instrument(id: newId(), notes: 'Demo item', name: 'UV-Vis spectrophotometer', model: 'HACH DR6000', serial: 'DR6-1043', location: 'Instrument room',
          lastCalibration: now.subtract(const Duration(days: 350)), calibrationDays: 365, lastService: now.subtract(const Duration(days: 200)), serviceDays: 180),
      Instrument(id: newId(), notes: 'Demo item', name: 'pH / conductivity meter', model: 'HQ40d multi', serial: 'HQ-5521', location: 'Field kit',
          lastCalibration: now.subtract(const Duration(days: 8)), calibrationDays: 7),
      Instrument(id: newId(), notes: 'Demo item', name: 'Turbidity meter', model: '2100Q', serial: 'TB-2207', location: 'Field kit',
          lastCalibration: now.subtract(const Duration(days: 40)), calibrationDays: 90),
      Instrument(id: newId(), notes: 'Demo item', name: 'Analytical balance', model: 'AS 220.R2', serial: 'BAL-0081', location: 'Weighing room',
          lastCalibration: now.subtract(const Duration(days: 120)), calibrationDays: 365),
    ]);
    reagents.addAll([
      Reagent(id: newId(), notes: 'Demo item', name: 'Iron standard 1000 mg/L', kind: ReagentKind.standard, lot: 'FE-23118', supplier: 'Merck', expiry: now.add(const Duration(days: 21)), quantity: 80, unit: 'mL', minStock: 50),
      Reagent(id: newId(), notes: 'Demo item', name: 'FerroVer iron reagent pillows', lot: 'A3071', supplier: 'HACH', expiry: now.add(const Duration(days: 240)), quantity: 40, unit: 'pillows', minStock: 50),
      Reagent(id: newId(), notes: 'Demo item', name: 'pH buffer 7.00', lot: 'B7-0412', supplier: 'HACH', opened: now.subtract(const Duration(days: 60)), expiry: now.subtract(const Duration(days: 3)), quantity: 250, unit: 'mL'),
      Reagent(id: newId(), notes: 'Demo item', name: 'Nitric acid 65% (trace metal)', lot: 'HN-5590', supplier: 'Sigma', expiry: now.add(const Duration(days: 600)), quantity: 1.5, unit: 'L', minStock: 0.5),
      Reagent(id: newId(), notes: 'Demo item', name: 'Drinking-water CRM (metals)', kind: ReagentKind.crm, lot: 'CRM-TMDW-B', supplier: 'HPS', expiry: now.add(const Duration(days: 300)), quantity: 2, unit: 'bottles', minStock: 1),
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
    this.loadLabDemo(now); // ignore: unnecessary_this
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

  void _loadBusinessDemo(DateTime now) {
    const tag = 'Demo item';
    final c1 = Client(id: newId(), name: 'Nimba Iron Ore Ltd (demo)', type: ClientType.company, contact: 'Environment Manager', phone: '+231 77 000 0001', email: 'env@example.com', address: 'Yekepa, Nimba County', notes: tag);
    final c2 = Client(id: newId(), name: 'Monrovia Water Utility (demo)', type: ClientType.government, contact: 'Water Quality Officer', phone: '+231 88 000 0002', address: 'Monrovia', notes: tag);
    final c3 = Client(id: newId(), name: 'Green Coast NGO (demo)', type: ClientType.ngo, contact: 'Programme Lead', email: 'info@example.org', address: 'Buchanan, Grand Bassa', notes: tag);
    clients.addAll([c1, c2, c3]);
    PriceItem pi(String code, String name, String cat, double price, int tat, [List<String> params = const []]) =>
        PriceItem(id: newId(), code: code, name: name, category: cat, price: price, turnaroundDays: tat, parameters: [...params], notes: tag);
    final items = [
      pi('PHY-01', 'Field parameters (pH, EC, TDS, turbidity, ORP, salinity)', 'Physical', 15, 1,
          ['pH', 'Electrical conductivity', 'Total dissolved solids', 'Turbidity', 'ORP', 'Salinity']),
      pi('PHY-02', 'Total suspended solids', 'Physical', 10, 3, ['Total suspended solids']),
      pi('NUT-01', 'Nutrients & ions package', 'Chemical', 40, 5,
          ['Nitrate (as NO3)', 'Nitrite (as NO2)', 'Ammonia', 'Phosphate', 'Sulfate', 'Chloride', 'Total hardness (CaCO3)']),
      pi('MET-01', 'Mining metals suite (18 elements)', 'Metals', 120, 10, [
        'Aluminium (Al)', 'Bismuth (Bi)', 'Iron (Fe)', 'Arsenic (As)', 'Tin (Sn)', 'Selenium (Se)', 'Barium (Ba)', 'Beryllium (Be)', 'Boron (B)',
        'Cadmium (Cd)', 'Chromium (Cr)', 'Copper (Cu)', 'Lead (Pb)', 'Lithium (Li)', 'Manganese (Mn)', 'Strontium (Sr)', 'Titanium (Ti)', 'Zinc (Zn)',
      ]),
      pi('MET-02', 'Single metal (spectrophotometer)', 'Metals', 12, 5),
      pi('MIC-01', 'E. coli & total coliforms', 'Microbiology', 25, 2, ['E. coli', 'Total coliforms']),
      pi('SOL-01', 'Soil / sediment metals (digestion + suite)', 'Soil', 150, 14),
      pi('FLD-01', 'Field sampling (per day, team of 3)', 'Field services', 250, 0),
      pi('RPT-01', 'Investigation report (interpretation)', 'Reporting', 200, 5),
    ];
    prices.addAll(items);
    PriceItem byCode(String c) => items.firstWhere((i) => i.code == c);
    DocLine line(String code, double qty) => DocLine(description: '${byCode(code).code} · ${byCode(code).name}', qty: qty, unitPrice: byCode(code).price, priceItemId: byCode(code).id);

    final r1 = LabRequest(
      id: newId(),
      number: 'REQ-${now.year}-0001',
      clientId: c1.id,
      date: DateTime(2026, 8, 12),
      dueDate: DateTime(2026, 8, 26),
      project: 'Demo: Bolo Town water investigation',
      status: RequestStatus.completed,
      lines: [line('PHY-01', 9), line('NUT-01', 9), line('MET-01', 9), line('FLD-01', 2), line('RPT-01', 1)],
      notes: tag,
    );
    final r2 = LabRequest(
      id: newId(),
      number: 'REQ-${now.year}-0002',
      clientId: c2.id,
      date: now.subtract(const Duration(days: 3)),
      dueDate: now.add(const Duration(days: 7)),
      project: 'Quarterly distribution network check',
      status: RequestStatus.quote,
      lines: [line('PHY-01', 12), line('MIC-01', 12), line('MET-02', 12)],
      discountPct: 10,
      notes: tag,
    );
    final r3 = LabRequest(
      id: newId(),
      number: 'REQ-${now.year}-0003',
      clientId: c3.id,
      date: now.subtract(const Duration(days: 10)),
      dueDate: now.subtract(const Duration(days: 1)),
      project: 'Demo: Bonlah soil (Gbai River)',
      status: RequestStatus.inProgress,
      lines: [line('SOL-01', 7), line('RPT-01', 1)],
      notes: tag,
    );
    requests.addAll([r3, r2, r1]);
    for (final smp in samples) {
      if (smp.project == r1.project) {
        smp.clientId = c1.id;
        smp.requestId = r1.id;
        smp.dueDate = r1.dueDate;
        smp.status = SampleStatus.reported;
        smp.reportedAt = DateTime(2026, 8, 22 + (smp.code.hashCode % 4).abs());
        for (final res in smp.results) {
          res.approvedBy = 'Lab supervisor (demo)';
          res.approvedAt = DateTime(2026, 8, 21);
        }
      } else if (smp.project == r3.project) {
        smp.clientId = c3.id;
        smp.requestId = r3.id;
        smp.dueDate = r3.dueDate;
      }
    }
    final i1 = Invoice(
      id: newId(),
      number: 'INV-${now.year}-0001',
      clientId: c1.id,
      requestId: r1.id,
      date: DateTime(2026, 8, 23),
      dueDate: DateTime(2026, 9, 22),
      lines: [for (final l in r1.lines) DocLine(description: l.description, qty: l.qty, unitPrice: l.unitPrice, priceItemId: l.priceItemId)],
      payments: [Payment(id: newId(), date: DateTime(2026, 9, 10), amount: 1500, method: 'Bank transfer', reference: 'TRF-88213', receiptNo: 'RCT-${now.year}-0001')],
      notes: tag,
    );
    final i2 = Invoice(
      id: newId(),
      number: 'INV-${now.year}-0002',
      clientId: c3.id,
      requestId: r3.id,
      date: now.subtract(const Duration(days: 40)),
      dueDate: now.subtract(const Duration(days: 10)),
      lines: [DocLine(description: 'FLD-01 · Field sampling (per day, team of 3)', qty: 1, unitPrice: 250)],
      notes: tag,
    );
    final i3 = Invoice(
      id: newId(),
      number: 'INV-${now.year}-0003',
      clientId: c2.id,
      date: now.subtract(const Duration(days: 75)),
      dueDate: now.subtract(const Duration(days: 45)),
      lines: [DocLine(description: 'PHY-01 · Field parameters', qty: 10, unitPrice: 15), DocLine(description: 'MIC-01 · E. coli & total coliforms', qty: 10, unitPrice: 25)],
      payments: [Payment(id: newId(), date: now.subtract(const Duration(days: 50)), amount: 400, method: 'Mobile money', reference: 'MM-55102', receiptNo: 'RCT-${now.year}-0002')],
      notes: tag,
    );
    invoices.addAll([i3, i2, i1].reversed);
    audit.add(AuditEntry(now.subtract(const Duration(minutes: 5)), 'System', 'create', 'Demo', 'LabLedger', 'Demo data loaded'));
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
