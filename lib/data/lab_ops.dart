// Operations for the 1.1 modules: stock, purchasing, maintenance, methods,
// proficiency testing, non-conformances, issued reports and the lab calendar.

import '../core/guidelines.dart';
import '../core/holding.dart';
import '../core/quality.dart';
import 'app_state.dart';
import 'lab_models.dart';
import 'models.dart';

enum CalKind { sampleDue, trip, calibration, service, reagentExpiry, invoiceDue, ncDue, ptDue, methodReview, purchase }

extension CalKindX on CalKind {
  String get label => const [
        'Results due',
        'Field trip',
        'Calibration due',
        'Service due',
        'Reagent expiry',
        'Invoice due',
        'Corrective action due',
        'PT report due',
        'Method review',
        'Purchase',
      ][index];
}

class CalEvent {
  final DateTime date;
  final CalKind kind;
  final String title;
  final String detail;
  final bool overdue;
  final Object? ref;
  const CalEvent(this.date, this.kind, this.title, this.detail, {this.overdue = false, this.ref});
}

extension LabOps on AppState {
  // ---------------- Lookups ----------------

  Instrument? instrument(String? id) {
    if (id == null) return null;
    for (final i in instruments) {
      if (i.id == id) return i;
    }
    return null;
  }

  Reagent? reagent(String? id) {
    if (id == null) return null;
    for (final r in reagents) {
      if (r.id == id) return r;
    }
    return null;
  }

  FieldTrip? trip(String? id) {
    if (id == null) return null;
    for (final t in trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The active method covering a parameter, if any.
  LabMethod? methodFor(String parameter) {
    final k = normKey(parameter);
    LabMethod? hit;
    for (final m in methods.where((m) => m.status != MethodStatus.retired)) {
      if (m.parameters.any((p) => normKey(p) == k || (k.length > 3 && normKey(p).contains(k)) || (normKey(p).length > 3 && k.contains(normKey(p))))) {
        if (hit == null || m.status == MethodStatus.active) hit = m;
      }
    }
    return hit;
  }

  List<Sample> samplesOnTrip(String tripId) => samples.where((s) => s.tripId == tripId).toList();

  // ---------------- Stock ----------------

  /// Records a stock movement and updates the on-hand quantity.
  void moveStock(Reagent r, double qty, StockReason reason, {String note = ''}) {
    update(() {
      final signed = switch (reason) { StockReason.received => qty.abs(), StockReason.adjusted => qty, _ => -qty.abs() };
      r.quantity = ((r.quantity ?? 0) + signed);
      if (r.quantity! < 0) r.quantity = 0;
      if (reason == StockReason.received) r.received = DateTime.now();
      stockMoves.insert(0, StockMove(id: newId(), reagentId: r.id, qty: signed, reason: reason, user: userName, note: note));
      log('stock ${reason.name}', 'Reagent', r.name, '${signed >= 0 ? '+' : ''}${_n(signed)} ${r.unit} → ${_n(r.quantity!)} ${r.unit}${note.isEmpty ? '' : ' · $note'}');
    });
  }

  List<StockMove> movesFor(String reagentId) => stockMoves.where((m) => m.reagentId == reagentId).toList();

  /// Average monthly use over the last 90 days (for reorder suggestions).
  double monthlyUse(String reagentId) {
    final since = DateTime.now().subtract(const Duration(days: 90));
    final used = stockMoves.where((m) => m.reagentId == reagentId && m.date.isAfter(since) && m.reason == StockReason.used).fold(0.0, (a, m) => a + m.qty.abs());
    return used / 3;
  }

  // ---------------- Purchasing ----------------

  String nextPurchaseNumber() => nextNumber('PR', purchases.map((p) => p.number));

  /// A draft purchase request for every reagent at or below its reorder level.
  PurchaseRequest purchaseFromLowStock() {
    final low = reagents.where((r) => r.lowStock || (r.expiry != null && daysUntil(r.expiry!) < 30)).toList();
    final pr = PurchaseRequest(
      id: newId(),
      number: nextPurchaseNumber(),
      requestedBy: userName,
      justification: 'Replenish items at or below reorder level, or expiring within 30 days.',
      lines: [
        for (final r in low)
          PurchaseLine(
            description: '${r.name}${r.supplier.isEmpty ? '' : ' (${r.supplier})'}',
            qty: ((r.minStock ?? 1) * 2 - (r.quantity ?? 0)).clamp(1, double.infinity).toDouble(),
            unit: r.unit,
            reagentId: r.id,
          ),
      ],
    );
    update(() {
      purchases.insert(0, pr);
      log('create', 'Purchase request', pr.number, '${pr.lines.length} item(s) from low stock');
    });
    return pr;
  }

  /// Marks a request received and books the quantities into stock.
  void receivePurchase(PurchaseRequest pr) {
    for (final l in pr.lines) {
      final r = reagent(l.reagentId);
      if (r != null) moveStock(r, l.qty, StockReason.received, note: pr.number);
    }
    update(() {
      pr.status = PurchaseStatus.received;
      log('receive', 'Purchase request', pr.number, money(pr.total, settings.currency));
    });
  }

  // ---------------- Equipment ----------------

  List<MaintenanceLog> logsFor(String instrumentId) => maintenance.where((m) => m.instrumentId == instrumentId).toList()..sort((a, b) => b.date.compareTo(a.date));

  /// Adds a maintenance / calibration record and updates the instrument's
  /// due dates. A failed check takes the instrument out of service.
  void addMaintenance(Instrument i, MaintenanceLog m) {
    update(() {
      maintenance.insert(0, m);
      if (m.passed) {
        if (m.kind == MaintenanceKind.calibration || m.kind == MaintenanceKind.verification) {
          if (i.lastCalibration == null || !m.date.isBefore(i.lastCalibration!)) i.lastCalibration = m.date;
        } else if (m.kind == MaintenanceKind.service || m.kind == MaintenanceKind.repair) {
          if (i.lastService == null || !m.date.isBefore(i.lastService!)) i.lastService = m.date;
          if (m.kind == MaintenanceKind.repair) i.inService = true;
        }
      } else {
        i.inService = false;
      }
      log('maintenance', 'Instrument', i.name, '${m.kind.label} · ${m.passed ? 'pass' : 'FAIL'}${m.outcome.isEmpty ? '' : ' · ${m.outcome}'}');
    });
  }

  // ---------------- Quality ----------------

  String nextNcNumber() => nextNumber('NC', ncs.map((n) => n.number));

  NonConformance raiseNc({required String title, String description = '', NcSource source = NcSource.other, NcSeverity severity = NcSeverity.minor, String reference = ''}) {
    final nc = NonConformance(
      id: newId(),
      number: nextNcNumber(),
      raisedBy: userName,
      title: title,
      description: description,
      source: source,
      severity: severity,
      reference: reference,
      dueDate: DateTime.now().add(Duration(days: severity == NcSeverity.critical ? 7 : (severity == NcSeverity.major ? 14 : 30))),
    );
    update(() {
      ncs.insert(0, nc);
      log('raise', 'Non-conformance', nc.number, title);
    });
    return nc;
  }

  List<NonConformance> get openNcs => ncs.where((n) => n.isOpen).toList();

  /// Share of scored PT results that were satisfactory (|z| ≤ 2), 0–100.
  double? get ptSuccessRate {
    var n = 0, ok = 0;
    for (final r in ptRounds) {
      for (final x in r.results) {
        final v = ptVerdict(x.z);
        if (v == null) continue;
        n++;
        if (v == PtVerdict.satisfactory) ok++;
      }
    }
    return n == 0 ? null : ok / n * 100;
  }

  /// Samples with at least one result analysed after its holding time.
  List<(Sample, List<HoldingCheck>)> get holdingBreaches => [
        for (final s in samples)
          if (holdingExceeded(s).isNotEmpty) (s, holdingExceeded(s)),
      ];

  // ---------------- Issued reports ----------------

  String nextReportNumber() => nextNumber('RPT', issuedReports.map((r) => r.number));

  /// Registers a report for a set of samples and returns it (with the
  /// fingerprint printed as a QR code).
  IssuedReport issueReport(List<Sample> list) {
    // Re-exporting unchanged results reuses the report already issued.
    final ids = {for (final s in list) s.id};
    for (final r in issuedReports) {
      if (r.sampleIds.length == ids.length && r.sampleIds.every(ids.contains) && reportFingerprint(r.number, list) == r.hash) return r;
    }
    final no = nextReportNumber();
    final r = IssuedReport(
      id: newId(),
      number: no,
      issuedBy: userName,
      sampleIds: [for (final s in list) s.id],
      sampleCodes: [for (final s in list) s.code],
      hash: reportFingerprint(no, list),
    );
    update(() {
      issuedReports.insert(0, r);
      log('issue', 'Report', no, list.map((s) => s.code).join(', '));
    });
    return r;
  }

  IssuedReport? issuedReport(String number) {
    final n = number.trim().toUpperCase();
    for (final r in issuedReports) {
      if (r.number.toUpperCase() == n) return r;
    }
    return null;
  }

  /// (report found, code matches the issued report, results unchanged since)
  (IssuedReport?, bool, bool) verifyReport(String number, String code) {
    final r = issuedReport(number);
    if (r == null) return (null, false, false);
    final clean = code.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final matches = clean == r.hash;
    final current = [for (final id in r.sampleIds) sampleById(id)].whereType<Sample>().toList();
    final unchanged = current.length == r.sampleIds.length && reportFingerprint(r.number, current) == r.hash;
    return (r, matches, unchanged);
  }

  // ---------------- Calendar ----------------

  List<CalEvent> calendarEvents() {
    final now = DateTime.now();
    final out = <CalEvent>[];
    for (final s in samples) {
      if (s.dueDate != null && s.status.index < SampleStatus.reported.index) {
        out.add(CalEvent(s.dueDate!, CalKind.sampleDue, s.code, '${s.site.isEmpty ? s.project : s.site} · ${s.status.label}', overdue: s.overdue, ref: s));
      }
    }
    for (final t in trips.where((t) => t.status != TripStatus.cancelled)) {
      out.add(CalEvent(t.date, CalKind.trip, t.title, '${t.sites.length} site(s) · ${t.team.join(', ')}', ref: t));
    }
    for (final i in instruments.where((i) => i.inService)) {
      if (i.calibrationDue != null) out.add(CalEvent(i.calibrationDue!, CalKind.calibration, i.name, 'Calibration due', overdue: i.calibrationDue!.isBefore(now), ref: i));
      if (i.serviceDue != null) out.add(CalEvent(i.serviceDue!, CalKind.service, i.name, 'Service due', overdue: i.serviceDue!.isBefore(now), ref: i));
    }
    for (final r in reagents.where((r) => r.expiry != null)) {
      out.add(CalEvent(r.expiry!, CalKind.reagentExpiry, r.name, r.lot.isEmpty ? 'Expires' : 'Lot ${r.lot} expires', overdue: r.expiry!.isBefore(now), ref: r));
    }
    for (final inv in invoices.where((i) => !i.cancelled && i.issued && i.balance > 0)) {
      out.add(CalEvent(inv.dueDate, CalKind.invoiceDue, inv.number, '${client(inv.clientId)?.name ?? ''} · ${money(inv.balance, settings.currency)}', overdue: inv.dueDate.isBefore(now), ref: inv));
    }
    for (final n in ncs.where((n) => n.isOpen && n.dueDate != null)) {
      out.add(CalEvent(n.dueDate!, CalKind.ncDue, n.number, n.title, overdue: n.overdue, ref: n));
    }
    for (final p in ptRounds.where((p) => p.reportDue != null)) {
      out.add(CalEvent(p.reportDue!, CalKind.ptDue, '${p.provider} ${p.round}'.trim(), p.scheme, ref: p));
    }
    for (final m in methods.where((m) => m.reviewDue != null && m.status != MethodStatus.retired)) {
      out.add(CalEvent(m.reviewDue!, CalKind.methodReview, m.code, m.title, overdue: m.reviewDue!.isBefore(now), ref: m));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Everything needing attention in the quality system.
  List<(String, String, int)> get qualityAlerts {
    final out = <(String, String, int)>[];
    for (final n in ncs.where((n) => n.isOpen)) {
      out.add((n.number, '${n.title} · ${n.overdue ? 'action overdue' : n.status.label}', n.overdue || n.severity != NcSeverity.minor ? 2 : 1));
    }
    for (final m in methods.where((m) => m.reviewDue != null && m.status != MethodStatus.retired)) {
      final d = daysUntil(m.reviewDue!);
      if (d < 0) {
        out.add((m.code, 'Method review overdue by ${-d} d', 2));
      } else if (d <= 30) {
        out.add((m.code, 'Method review in $d d', 1));
      }
    }
    for (final (s, list) in holdingBreaches) {
      out.add((s.code, 'Holding time exceeded: ${list.map((h) => h.result.parameter).join(', ')}', 1));
    }
    out.sort((a, b) => b.$3.compareTo(a.$3));
    return out;
  }

  // ---------------- Demo ----------------

  void loadLabDemo(DateTime now) {
    T demo<T>(T x, String id) {
      demoIds.add(id);
      return x;
    }

    final aas = instruments.isNotEmpty ? instruments.first : null;
    final meter = instruments.length > 1 ? instruments[1] : null;

    // Methods
    String id() => newId();
    final m1 = id(), m2 = id(), m3 = id(), m4 = id(), m5 = id(), m6 = id();
    methods.addAll([
      demo(
          LabMethod(
              id: m1,
              code: 'SOP-MET-01',
              title: 'Iron and manganese in water by UV-Vis',
              technique: 'UV-Vis (FerroVer / PAN)',
              reference: 'HACH 8008 / 8149; APHA 3500-Fe B',
              parameters: ['Iron (Fe)', 'Manganese (Mn)'],
              matrices: 'Drinking, surface and ground water',
              mdl: 0.02,
              loq: 0.06,
              uncertaintyPct: 12,
              recoveryLo: 85,
              recoveryHi: 115,
              instrumentId: aas?.id,
              version: '2.1',
              effective: now.subtract(const Duration(days: 300)),
              reviewDue: now.add(const Duration(days: 20)),
              revisions: [
                MethodRevision(version: '1.0', date: now.subtract(const Duration(days: 900)), change: 'First issue', by: 'QA officer'),
                MethodRevision(version: '2.0', date: now.subtract(const Duration(days: 420)), change: 'Added Mn by PAN method', by: 'QA officer'),
                MethodRevision(version: '2.1', date: now.subtract(const Duration(days: 300)), change: 'Revised MDL after 7-replicate study', by: 'QA officer'),
              ]),
          m1),
      demo(
          LabMethod(
              id: m2,
              code: 'SOP-FLD-01',
              title: 'Field measurement of pH, EC, ORP and temperature',
              technique: 'Multiparameter meter',
              reference: 'APHA 4500-H+ B, 2510 B, 2580 B',
              parameters: ['pH', 'Electrical conductivity', 'ORP', 'Temperature', 'Salinity'],
              matrices: 'Water',
              unit: '',
              uncertaintyPct: 3,
              instrumentId: meter?.id,
              effective: now.subtract(const Duration(days: 200)),
              reviewDue: now.add(const Duration(days: 165))),
          m2),
      demo(
          LabMethod(
              id: m3,
              code: 'SOP-PHY-02',
              title: 'Turbidity by nephelometry',
              technique: 'Nephelometer',
              reference: 'APHA 2130 B',
              parameters: ['Turbidity'],
              unit: 'NTU',
              mdl: 0.1,
              loq: 0.3,
              uncertaintyPct: 8,
              effective: now.subtract(const Duration(days: 500)),
              reviewDue: now.subtract(const Duration(days: 12))),
          m3),
      demo(
          LabMethod(
              id: m4,
              code: 'SOP-MET-04',
              title: 'Trace metals by flame AAS',
              technique: 'Flame AAS',
              reference: 'US EPA 7000B; APHA 3111 B',
              parameters: ['Lead (Pb)', 'Cadmium (Cd)', 'Copper (Cu)', 'Zinc (Zn)', 'Nickel (Ni)', 'Chromium (Cr)'],
              matrices: 'Water, soil digests',
              mdl: 0.005,
              loq: 0.015,
              uncertaintyPct: 15,
              recoveryLo: 80,
              recoveryHi: 120,
              status: MethodStatus.validated,
              effective: now.subtract(const Duration(days: 60)),
              reviewDue: now.add(const Duration(days: 300))),
          m4),
      demo(
          LabMethod(
              id: m5,
              code: 'SOP-NUT-01',
              title: 'Nitrate, nitrite and sulfate by UV-Vis',
              technique: 'UV-Vis',
              reference: 'HACH 8039 / 8507 / 8051',
              parameters: ['Nitrate (as NO3)', 'Nitrite (as NO2)', 'Sulfate (SO4)'],
              mdl: 0.3,
              loq: 1.0,
              uncertaintyPct: 10,
              effective: now.subtract(const Duration(days: 400)),
              reviewDue: now.add(const Duration(days: 90))),
          m5),
      demo(
          LabMethod(
              id: m6,
              code: 'SOP-SOIL-01',
              title: 'Aqua-regia digestion of soil and sediment',
              technique: 'Hot-block digestion + AAS',
              reference: 'ISO 11466; US EPA 3050B',
              parameters: ['Iron (Fe)', 'Manganese (Mn)', 'Zinc (Zn)', 'Copper (Cu)'],
              matrices: 'Soil, sediment',
              unit: 'mg/kg',
              mdl: 0.5,
              loq: 1.5,
              uncertaintyPct: 20,
              status: MethodStatus.draft,
              effective: now.subtract(const Duration(days: 10))),
          m6),
    ]);

    // Proficiency testing
    final pt = id();
    ptRounds.add(demo(
        PtRound(id: pt, provider: 'Inter-laboratory comparison', scheme: 'West Africa water chemistry', round: '2026-2', matrix: 'Drinking water', date: now.subtract(const Duration(days: 45)), results: [
          PtResult(parameter: 'Iron (Fe)', reported: 0.52, assigned: 0.50, sigma: 0.05),
          PtResult(parameter: 'Manganese (Mn)', reported: 0.21, assigned: 0.20, sigma: 0.02),
          PtResult(parameter: 'Nitrate (as NO3)', reported: 31.5, assigned: 28.0, sigma: 1.4),
          PtResult(parameter: 'Lead (Pb)', reported: 0.0142, assigned: 0.010, sigma: 0.0012),
          PtResult(parameter: 'Turbidity', unit: 'NTU', reported: 4.9, assigned: 5.0, sigma: 0.4),
          PtResult(parameter: 'pH', unit: '', reported: 7.12, assigned: 7.05, sigma: 0.1),
        ]),
        pt));
    final pt2 = id();
    ptRounds.add(demo(PtRound(id: pt2, provider: 'Inter-laboratory comparison', scheme: 'West Africa water chemistry', round: '2026-3', matrix: 'Drinking water', date: now.add(const Duration(days: 12)), reportDue: now.add(const Duration(days: 40))), pt2));

    // Non-conformances
    final n1 = id(), n2 = id(), n3 = id();
    ncs.addAll([
      demo(
          NonConformance(
              id: n1,
              number: 'NC-${now.year}-0001',
              date: now.subtract(const Duration(days: 40)),
              raisedBy: 'QA officer',
              source: NcSource.proficiencyTest,
              severity: NcSeverity.major,
              status: NcStatus.actionTaken,
              title: 'Lead PT result unsatisfactory (z = 3.5)',
              description: 'Round 2026-2 lead result 0.0142 mg/L against assigned 0.010 mg/L.',
              reference: 'PT 2026-2',
              immediateAction: 'Lead results reported since last satisfactory PT reviewed; none near the limit.',
              rootCause: 'Calibration standard prepared from an expired 1000 mg/L stock.',
              correctiveAction: 'New certified stock purchased; standards re-prepared; LabLedger expiry alerts enabled for all standards.',
              preventiveAction: 'Weekly review of the lab register expiry list.',
              owner: 'Chemist in charge',
              dueDate: now.add(const Duration(days: 5))),
          n1),
      demo(
          NonConformance(
              id: n2,
              number: 'NC-${now.year}-0002',
              date: now.subtract(const Duration(days: 9)),
              raisedBy: 'Analyst',
              source: NcSource.qcFailure,
              severity: NcSeverity.minor,
              status: NcStatus.open,
              title: 'Pb check standard drifting above +2s',
              description: 'Control chart shows 5 consecutive points above the mean.',
              reference: 'Demo: Pb 2.00 mg/L check standard',
              owner: 'Analyst',
              dueDate: now.subtract(const Duration(days: 1))),
          n2),
      demo(
          NonConformance(
              id: n3,
              number: 'NC-${now.year}-0003',
              date: now.subtract(const Duration(days: 70)),
              raisedBy: 'Sample reception',
              source: NcSource.sampleHandling,
              severity: NcSeverity.minor,
              status: NcStatus.closed,
              title: 'Cooler received at 14 °C',
              description: 'Bolo Town samples arrived above the 6 °C limit after vehicle breakdown.',
              immediateAction: 'Client informed; results flagged on the report.',
              rootCause: 'Insufficient ice packs for a two-day trip.',
              correctiveAction: 'Trip checklist now requires ice packs for 48 h.',
              closedAt: now.subtract(const Duration(days: 50)),
              effectiveness: 'Next three trips received ≤ 6 °C.',
              owner: 'Field team lead'),
          n3),
    ]);

    // Field trips
    final t1 = id(), t2 = id();
    final bolo = samples.where((s) => s.project.startsWith('Demo: Bolo')).toList();
    trips.addAll([
      demo(
          FieldTrip(
              id: t1,
              title: 'Bolo Town AML sampling',
              project: bolo.isEmpty ? 'Demo: Bolo Town water investigation' : bolo.first.project,
              date: bolo.isEmpty ? now.subtract(const Duration(days: 60)) : bolo.first.collectedAt,
              returnDate: bolo.isEmpty ? null : bolo.first.collectedAt.add(const Duration(days: 1)),
              team: ['J. Cooper', 'V. Allison', 'S. Emmanuel'],
              vehicle: 'EPA pickup LBR-4521',
              objective: 'Assess acid mine leachate impact on streams around Bolo Town.',
              status: TripStatus.completed,
              sites: [
                for (final s in bolo) PlannedSite(name: s.site, code: s.code, lat: s.lat, lon: s.lon, matrix: s.matrix.name, parameters: 'Field params, metals, anions', sampled: true),
              ],
              checklist: [for (final c in defaultTripChecklist()) CheckItem(c.text, true)]),
          t1),
      demo(
          FieldTrip(
              id: t2,
              title: 'Mano River quarterly monitoring',
              project: 'Mano River monitoring Q4',
              date: now.add(const Duration(days: 6)),
              returnDate: now.add(const Duration(days: 8)),
              team: ['S. Emmanuel', 'Field technician'],
              vehicle: 'EPA Land Cruiser',
              objective: 'Quarterly surface-water monitoring at 4 stations.',
              sites: [
                PlannedSite(name: 'Upstream bridge', code: 'MR-C-SW-001', lat: 7.0091, lon: -11.0921, parameters: 'Field params, metals, nutrients, E. coli'),
                PlannedSite(name: 'Mine discharge point', code: 'MR-SW-002', lat: 7.0219, lon: -11.0745, parameters: 'Field params, metals, TSS'),
                PlannedSite(name: 'Downstream village', code: 'MR-SW-003', lat: 7.0405, lon: -11.0617, parameters: 'Field params, metals, nutrients, E. coli'),
                PlannedSite(name: 'Community well', code: 'MR-GW-004', lat: 7.0452, lon: -11.0589, matrix: 'groundwater', parameters: 'Field params, metals, nitrate, E. coli'),
              ],
              checklist: [for (final (i, c) in defaultTripChecklist().indexed) CheckItem(c.text, i < 5)]),
          t2),
    ]);
    for (final s in bolo) {
      s.tripId = t1;
      if (s.weather.isEmpty) s.weather = 'Overcast, light rain earlier';
    }

    // Maintenance and stock history
    if (aas != null) {
      final l1 = id(), l2 = id();
      maintenance.addAll([
        demo(MaintenanceLog(id: l1, instrumentId: aas.id, date: aas.lastCalibration ?? now, kind: MaintenanceKind.calibration, by: 'HACH service engineer', outcome: 'Wavelength and photometric accuracy within spec', certificate: 'CAL-DR6-2025-118', cost: 450), l1),
        demo(MaintenanceLog(id: l2, instrumentId: aas.id, date: aas.lastService ?? now, kind: MaintenanceKind.service, by: 'Lab technician', outcome: 'Lamp hours 1,840; cuvette holder cleaned'), l2),
      ]);
    }
    if (meter != null) {
      final l3 = id();
      maintenance.add(demo(MaintenanceLog(id: l3, instrumentId: meter.id, date: meter.lastCalibration ?? now, kind: MaintenanceKind.calibration, by: 'Analyst', outcome: 'pH 4/7/10 slope 98.7 %; EC 1413 µS/cm ok'), l3));
    }
    for (final r in reagents.take(3)) {
      for (var k = 1; k <= 4; k++) {
        final sm = id();
        stockMoves.add(demo(StockMove(id: sm, reagentId: r.id, date: now.subtract(Duration(days: k * 17)), qty: r.unit == 'pillows' ? -10.0 : -15.0, reason: StockReason.used, user: 'Analyst', note: 'Routine analysis'), sm));
      }
    }

    // A purchase request waiting for approval
    final pr = id();
    purchases.add(demo(
        PurchaseRequest(id: pr, number: 'PR-${now.year}-0001', date: now.subtract(const Duration(days: 3)), requestedBy: 'Analyst', supplier: 'HACH via local agent', status: PurchaseStatus.submitted, justification: 'Low stock and expiring buffer.', lines: [
          PurchaseLine(description: 'FerroVer iron reagent pillows (100/pk)', qty: 2, unit: 'pack', unitPrice: 48, reagentId: reagents.length > 1 ? reagents[1].id : null),
          PurchaseLine(description: 'pH buffer 7.00, 500 mL', qty: 2, unit: 'bottle', unitPrice: 22, reagentId: reagents.length > 2 ? reagents[2].id : null),
          PurchaseLine(description: 'Sample bottles HDPE 500 mL (case of 50)', qty: 2, unit: 'case', unitPrice: 65),
        ]),
        pr));
  }
}

String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
