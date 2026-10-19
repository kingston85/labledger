// Field sheets, purchase requests, CAPA forms, Excel workbooks and
// e-mail-ready result summaries.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_state.dart';
import '../data/lab_models.dart';
import '../data/models.dart';
import 'guidelines.dart';
import 'holding.dart';
import 'report.dart';
import 'utm.dart';
import 'xlsx.dart';

const _accent = PdfColor.fromInt(0xFF2F5BD3);
const _ink = PdfColor.fromInt(0xFF0E1116);
const _dim = PdfColor.fromInt(0xFF5A6478);
const _line = PdfColor.fromInt(0xFFD5DAE2);
const _panel = PdfColor.fromInt(0xFFF4F6F9);

/// The laboratory logo as a PDF image, if one is set.
pw.Widget? pdfLogo(AppState app, {double height = 38}) {
  final b64 = app.settings.logoB64;
  if (b64.isEmpty) return null;
  try {
    return pw.Image(pw.MemoryImage(base64Decode(b64)), height: height, fit: pw.BoxFit.contain);
  } catch (_) {
    return null;
  }
}

String _q(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

class LabDocs {
  LabDocs._();

  static Future<(pw.Font, pw.Font)> _fonts() async => (
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf')),
        pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf')),
      );

  static pw.Widget _head(AppState app, pw.Font bold, String title, String sub) {
    final logo = pdfLogo(app);
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2))),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        if (logo != null) ...[logo, pw.SizedBox(width: 10)],
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(app.settings.labName, style: pw.TextStyle(font: bold, fontSize: 11)),
            if (app.settings.labAddress.isNotEmpty) pw.Text(app.settings.labAddress, style: const pw.TextStyle(fontSize: 8, color: _dim)),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 15, color: _accent)),
          pw.Text(sub, style: const pw.TextStyle(fontSize: 8.5, color: _dim)),
        ]),
      ]),
    );
  }

  static pw.Widget _kv(String k, String v, {double w = 90}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: w, child: pw.Text(k, style: const pw.TextStyle(fontSize: 8.5, color: _dim))),
          pw.Expanded(child: pw.Text(v.isEmpty ? '—' : v, style: const pw.TextStyle(fontSize: 9))),
        ]),
      );

  static pw.Widget _sig(String label) => pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(right: 18),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(height: 26),
            pw.Container(height: 0.7, color: _ink),
            pw.SizedBox(height: 3),
            pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
          ]),
        ),
      );

  // ---------------- Field sheet ----------------

  /// Printable trip plan: site list with blank columns for field readings,
  /// the pre-departure checklist, and sign-off.
  static Future<Uint8List> fieldSheet(AppState app, FieldTrip t) async {
    final (regular, bold) = await _fonts();
    final d = pw.Document(title: 'Field sheet ${t.title}', author: app.settings.labName, creator: 'LabLedger');
    final head = pw.TextStyle(font: bold, fontSize: 7.5, color: PdfColors.white);
    const cell = pw.TextStyle(fontSize: 7.5);
    d.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (ctx) => pw.Row(children: [
        pw.Expanded(child: pw.Text('${t.title} · field sheet · printed ${shortDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 7, color: _dim))),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _dim)),
      ]),
      build: (ctx) => [
        _head(app, bold, 'FIELD SAMPLING SHEET', t.title),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(children: [
              _kv('Project', t.project),
              _kv('Client', app.client(t.clientId)?.name ?? ''),
              _kv('Objective', t.objective),
            ]),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(children: [
              _kv('Date', '${shortDate(t.date)}${t.returnDate == null ? '' : ' – ${shortDate(t.returnDate!)}'}'),
              _kv('Team', t.team.join(', ')),
              _kv('Vehicle', t.vehicle),
            ]),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(children: [
              _kv('Weather', '______________________________'),
              _kv('Cooler temp. on departure', '________ °C'),
              _kv('Meters checked', 'pH ___  EC ___  DO ___  Turbidity ___'),
            ]),
          ),
        ]),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: const {
            0: pw.FixedColumnWidth(18),
            1: pw.FixedColumnWidth(62),
            2: pw.FlexColumnWidth(2.2),
            3: pw.FixedColumnWidth(70),
            4: pw.FlexColumnWidth(1.8),
            5: pw.FixedColumnWidth(34),
            6: pw.FixedColumnWidth(34),
            7: pw.FixedColumnWidth(30),
            8: pw.FixedColumnWidth(38),
            9: pw.FixedColumnWidth(34),
            10: pw.FixedColumnWidth(38),
            11: pw.FlexColumnWidth(2.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _accent),
              children: [
                for (final h in ['#', 'Code', 'Site / coordinates', 'Matrix', 'Analyses', 'Time', 'Temp °C', 'pH', 'EC µS/cm', 'DO mg/L', 'Turb. NTU', 'Observations / bottles'])
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(h, style: head)),
              ],
            ),
            for (var i = 0; i < (t.sites.isEmpty ? 8 : t.sites.length); i++)
              pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text('${i + 1}', style: cell)),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(i < t.sites.length ? t.sites[i].code : '', style: pw.TextStyle(font: bold, fontSize: 7.5))),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(i < t.sites.length ? t.sites[i].name : '', style: cell),
                      if (i < t.sites.length && t.sites[i].lat != null && t.sites[i].lon != null)
                        pw.Text('${t.sites[i].lat!.toStringAsFixed(5)}, ${t.sites[i].lon!.toStringAsFixed(5)}  ·  UTM ${toUtm(t.sites[i].lat!, t.sites[i].lon!, zone: 29)}',
                            style: const pw.TextStyle(fontSize: 6.5, color: _dim)),
                      pw.SizedBox(height: 12),
                    ]),
                  ),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(i < t.sites.length ? _matrixLabel(t.sites[i].matrix) : '', style: cell)),
                  pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(i < t.sites.length ? t.sites[i].parameters : '', style: cell)),
                  for (var k = 0; k < 7; k++) pw.SizedBox(height: 26),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text('PRE-DEPARTURE CHECKLIST', style: pw.TextStyle(font: bold, fontSize: 8, color: _dim, letterSpacing: 1)),
        pw.SizedBox(height: 4),
        pw.Wrap(spacing: 18, runSpacing: 3, children: [
          for (final c in t.checklist)
            pw.SizedBox(
              width: 240,
              child: pw.Row(children: [
                pw.Container(
                  width: 8,
                  height: 8,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 0.7), color: c.done ? _accent : null),
                ),
                pw.SizedBox(width: 5),
                pw.Expanded(child: pw.Text(c.text, style: const pw.TextStyle(fontSize: 8.5))),
              ]),
            ),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('PRESERVATION AND HOLDING TIMES', style: pw.TextStyle(font: bold, fontSize: 8, color: _dim, letterSpacing: 1)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.5),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _panel), children: [
              for (final h in ['Analysis', 'Container', 'Preservation', 'Max. holding'])
                pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 7))),
            ]),
            for (final r in _guideFor(t))
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(r.group == 'Metals' ? 'Metals (total / dissolved)' : r.keys.first[0].toUpperCase() + r.keys.first.substring(1), style: const pw.TextStyle(fontSize: 7))),
                pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text('${r.container} · ${r.volume}', style: const pw.TextStyle(fontSize: 7))),
                pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(r.preservation, style: const pw.TextStyle(fontSize: 7))),
                pw.Padding(padding: const pw.EdgeInsets.all(2.5), child: pw.Text(r.holdText, style: const pw.TextStyle(fontSize: 7))),
              ]),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Row(children: [_sig('Team leader'), _sig('Samples received at lab by'), _sig('Date / time and cooler temp. on arrival')]),
      ],
    ));
    return d.save();
  }

  static String _matrixLabel(String name) {
    for (final m in Matrix.values) {
      if (m.name == name) return m.label;
    }
    return name;
  }

  static List<HoldingRule> _guideFor(FieldTrip t) {
    final text = t.sites.map((s) => s.parameters.toLowerCase()).join(' ');
    final out = <HoldingRule>[];
    void add(String group, String key) {
      for (final r in holdingRules.where((r) => !r.solid && r.group == group)) {
        if (r.keys.contains(key) && !out.contains(r)) out.add(r);
      }
    }

    if (text.contains('metal')) add('Metals', 'iron');
    if (text.contains('nutrient') || text.contains('nitrate')) {
      add('Nutrients', 'nitrate');
      add('Nutrients', 'ammonia');
      add('Nutrients', 'total phosphorus');
    }
    if (text.contains('coli') || text.contains('micro')) add('Microbiology', 'coli');
    if (text.contains('tss') || text.contains('solid')) add('Physical', 'tss');
    if (text.contains('anion') || text.contains('sulfate')) add('Anions', 'sulfate');
    if (text.contains('bod')) add('Demand', 'bod');
    if (text.contains('cod')) add('Demand', 'cod');
    if (text.contains('oil') || text.contains('grease')) add('Organics', 'oil and grease');
    if (out.isEmpty) {
      add('Metals', 'iron');
      add('Nutrients', 'nitrate');
      add('Microbiology', 'coli');
    }
    return out;
  }

  // ---------------- Purchase request ----------------

  static Future<Uint8List> purchasePdf(AppState app, PurchaseRequest pr) async {
    final (regular, bold) = await _fonts();
    final cur = app.settings.currency;
    final d = pw.Document(title: 'Purchase request ${pr.number}', author: app.settings.labName, creator: 'LabLedger');
    d.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 34, 40, 34),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (ctx) => [
        _head(app, bold, 'PURCHASE REQUEST', '${pr.number} · ${pr.status.label}'),
        _kv('Date', shortDate(pr.date)),
        _kv('Requested by', pr.requestedBy),
        _kv('Supplier', pr.supplier),
        _kv('Justification', pr.justification),
        pw.SizedBox(height: 10),
        pw.Table(
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5), bottom: pw.BorderSide(color: _line)),
          columnWidths: const {0: pw.FixedColumnWidth(22), 1: pw.FlexColumnWidth(4), 2: pw.FixedColumnWidth(60), 3: pw.FixedColumnWidth(70), 4: pw.FixedColumnWidth(70)},
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _accent), children: [
              for (final h in ['#', 'Item', 'Qty', 'Unit price', 'Amount'])
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 8.5, color: PdfColors.white))),
            ]),
            for (var i = 0; i < pr.lines.length; i++)
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(pr.lines[i].description, style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${_q(pr.lines[i].qty)} ${pr.lines[i].unit}', style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(money(pr.lines[i].unitPrice, cur), style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(money(pr.lines[i].total, cur), style: const pw.TextStyle(fontSize: 9))),
              ]),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Estimated total  ${money(pr.total, cur)}', style: pw.TextStyle(font: bold, fontSize: 11))),
        if (pr.notes.isNotEmpty) ...[pw.SizedBox(height: 10), pw.Text(pr.notes, style: const pw.TextStyle(fontSize: 9, color: _dim))],
        pw.SizedBox(height: 30),
        pw.Row(children: [_sig('Requested by: ${pr.requestedBy}'), _sig('Approved by${pr.approvedBy.isEmpty ? '' : ': ${pr.approvedBy}'}'), _sig('Finance / procurement')]),
      ],
    ));
    return d.save();
  }

  // ---------------- Non-conformance / CAPA ----------------

  static Future<Uint8List> ncPdf(AppState app, NonConformance n) async {
    final (regular, bold) = await _fonts();
    final d = pw.Document(title: 'Non-conformance ${n.number}', author: app.settings.labName, creator: 'LabLedger');
    pw.Widget block(String title, String text) => pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(title.toUpperCase(), style: pw.TextStyle(font: bold, fontSize: 7.5, color: _dim, letterSpacing: 1)),
            pw.SizedBox(height: 3),
            pw.Text(text.isEmpty ? ' ' : text, style: const pw.TextStyle(fontSize: 9.5)),
            if (text.isEmpty) pw.SizedBox(height: 24),
          ]),
        );
    d.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 34, 40, 34),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (ctx) => [
        _head(app, bold, 'NON-CONFORMANCE & CAPA', '${n.number} · ${n.status.label}'),
        pw.Text(n.title, style: pw.TextStyle(font: bold, fontSize: 13)),
        pw.SizedBox(height: 6),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(children: [_kv('Raised', '${shortDate(n.date)} by ${n.raisedBy}'), _kv('Source', n.source.label), _kv('Reference', n.reference)])),
          pw.SizedBox(width: 16),
          pw.Expanded(
              child: pw.Column(children: [
            _kv('Severity', n.severity.label),
            _kv('Action owner', n.owner),
            _kv('Due / closed', '${n.dueDate == null ? '—' : shortDate(n.dueDate!)}${n.closedAt == null ? '' : ' / closed ${shortDate(n.closedAt!)}'}'),
          ])),
        ]),
        pw.SizedBox(height: 8),
        block('Description', n.description),
        block('Immediate action / correction', n.immediateAction),
        block('Root cause', n.rootCause),
        block('Corrective action', n.correctiveAction),
        block('Preventive action', n.preventiveAction),
        block('Verification of effectiveness', n.effectiveness),
        pw.SizedBox(height: 16),
        pw.Row(children: [_sig('Raised by'), _sig('Quality manager'), _sig('Closed by / date')]),
      ],
    ));
    return d.save();
  }

  // ---------------- Excel ----------------

  /// One worksheet per sample list: a wide table (one row per sample, one
  /// column per parameter) plus a long table of every result.
  static Uint8List samplesWorkbook(AppState app, List<Sample> samples) {
    final x = XlsxBuilder();
    final params = <String>[];
    final units = <String, String>{};
    for (final s in samples) {
      for (final r in s.results) {
        if (!params.contains(r.parameter)) params.add(r.parameter);
        units.putIfAbsent(r.parameter, () => r.unit);
      }
    }
    x.add('Results (wide)', [
      'Sample code', 'Site', 'Project', 'Matrix', 'Control', 'Collected', 'Latitude', 'Longitude', 'Status', 'Exceedances',
      for (final p in params) units[p]!.isEmpty ? p : '$p [${units[p]}]',
    ], [
      for (final s in samples)
        () {
          final set = app.limitsFor(s);
          final ex = s.results.where((r) {
            final k = checkResult(r, set).status;
            return k == Compliance.exceed || k == Compliance.belowMin;
          }).length;
          return <Object?>[
            s.code, s.site, s.project, s.matrix.label, s.isControl ? 'Yes' : '', s.collectedAt, s.lat, s.lon, s.status.label, ex,
            for (final p in params)
              () {
                for (final r in s.results) {
                  if (r.parameter == p) return r.belowLod ? resultText(r) : r.value;
                }
                return null;
              }(),
          ];
        }(),
    ]);
    x.add('Results (long)', ['Sample code', 'Site', 'Parameter', 'Value', 'Below LOD', 'LOD', 'Unit', 'Limit', 'Compliance', 'Method', 'Analyst', 'Analysed', 'Approved by', 'Holding time'], [
      for (final s in samples)
        for (final r in s.results)
          () {
            final k = checkResult(r, app.limitsFor(s));
            final hold = holdingChecks(s).where((h) => h.result == r).toList();
            return <Object?>[
              s.code, s.site, r.parameter, r.value, r.belowLod ? 'Yes' : '', r.lod, r.unit, k.limit?.text ?? '', complianceLabel(k.status), r.method, r.analyst, r.date, r.approvedBy,
              hold.isEmpty ? '' : (hold.first.exceeded ? 'EXCEEDED (${hold.first.rule.holdText})' : 'OK'),
            ];
          }(),
    ]);
    return x.build();
  }

  /// Everything in one workbook: samples, results, business, inventory, quality.
  static Uint8List fullWorkbook(AppState app) {
    final x = XlsxBuilder();
    final cur = app.settings.currency;
    x.add('Samples', ['Code', 'Site', 'Project', 'Matrix', 'Control', 'Collected', 'Received', 'Status', 'Client', 'Request', 'Due', 'Reported', 'TAT (days)', 'Latitude', 'Longitude', 'Results'], [
      for (final s in app.samples)
        [
          s.code, s.site, s.project, s.matrix.label, s.isControl ? 'Yes' : '', s.collectedAt, s.receivedAt, s.status.label, app.client(s.clientId)?.name ?? '',
          app.request(s.requestId)?.number ?? '', s.dueDate, s.reportedAt, s.turnaroundDays == null ? null : double.parse(s.turnaroundDays!.toStringAsFixed(2)), s.lat, s.lon, s.results.length,
        ],
    ]);
    x.add('Results', ['Sample', 'Parameter', 'Value', 'Below LOD', 'LOD', 'Unit', 'Limit', 'Compliance', 'Method', 'Analysed', 'Approved by'], [
      for (final s in app.samples)
        for (final r in s.results)
          () {
            final k = checkResult(r, app.limitsFor(s));
            return <Object?>[s.code, r.parameter, r.value, r.belowLod ? 'Yes' : '', r.lod, r.unit, k.limit?.text ?? '', complianceLabel(k.status), r.method, r.date, r.approvedBy];
          }(),
    ]);
    x.add('Clients', ['Name', 'Type', 'Contact', 'Phone', 'Email', 'Address'], [
      for (final c in app.clients) [c.name, c.type.label, c.contact, c.phone, c.email, c.address],
    ]);
    x.add('Requests', ['Number', 'Date', 'Client', 'Project', 'Status', 'Due', 'Total ($cur)'], [
      for (final r in app.requests) [r.number, r.date, app.client(r.clientId)?.name ?? '', r.project, r.status.label, r.dueDate, r.total],
    ]);
    x.add('Invoices', ['Number', 'Date', 'Client', 'Due', 'Status', 'Total ($cur)', 'Paid ($cur)', 'Balance ($cur)'], [
      for (final i in app.invoices) [i.number, i.date, app.client(i.clientId)?.name ?? '', i.dueDate, i.status.label, i.total, i.paid, i.balance],
    ]);
    x.add('Inventory', ['Item', 'Kind', 'Lot', 'Supplier', 'Location', 'Quantity', 'Unit', 'Reorder at', 'Expiry', 'Low stock'], [
      for (final r in app.reagents) [r.name, r.kind.label, r.lot, r.supplier, r.location, r.quantity, r.unit, r.minStock, r.expiry, r.lowStock ? 'Yes' : ''],
    ]);
    x.add('Instruments', ['Name', 'Model', 'Serial', 'Location', 'In service', 'Last calibration', 'Calibration due', 'Last service', 'Service due'], [
      for (final i in app.instruments) [i.name, i.model, i.serial, i.location, i.inService ? 'Yes' : 'No', i.lastCalibration, i.calibrationDue, i.lastService, i.serviceDue],
    ]);
    x.add('Methods', ['Code', 'Title', 'Version', 'Status', 'Technique', 'Reference', 'Parameters', 'MDL', 'LOQ', 'Unit', 'U (k=2) %', 'Review due'], [
      for (final m in app.methods) [m.code, m.title, m.version, m.status.label, m.technique, m.reference, m.parameters.join(', '), m.mdl, m.loq, m.unit, m.uncertaintyPct, m.reviewDue],
    ]);
    x.add('Proficiency tests', ['Provider', 'Scheme', 'Round', 'Date', 'Parameter', 'Reported', 'Assigned', 'σpt', 'z', 'Verdict'], [
      for (final p in app.ptRounds)
        for (final r in p.results)
          [p.provider, p.scheme, p.round, p.date, r.parameter, r.reported, r.assigned, r.sigma, r.z == null ? null : double.parse(r.z!.toStringAsFixed(2)), ptVerdict(r.z)?.label ?? ''],
    ]);
    x.add('Non-conformances', ['Number', 'Date', 'Title', 'Source', 'Severity', 'Status', 'Owner', 'Due', 'Closed', 'Root cause', 'Corrective action'], [
      for (final n in app.ncs) [n.number, n.date, n.title, n.source.label, n.severity.label, n.status.label, n.owner, n.dueDate, n.closedAt, n.rootCause, n.correctiveAction],
    ]);
    x.add('Audit trail', ['Time', 'User', 'Action', 'Record', 'Reference', 'Detail'], [
      for (final a in app.audit.reversed.take(5000)) [a.time, a.user, a.action, a.entity, a.ref, a.detail],
    ]);
    return x.build();
  }

  // ---------------- E-mail summary ----------------

  static String emailSummary(AppState app, List<Sample> samples, {String? heading}) {
    final b = StringBuffer();
    b.writeln(heading ?? 'Laboratory results — ${app.settings.labName}');
    b.writeln();
    for (final s in samples) {
      final set = app.limitsFor(s);
      final checks = [for (final r in s.results) (r, checkResult(r, set))];
      final bad = checks.where((x) => x.$2.status == Compliance.exceed || x.$2.status == Compliance.belowMin).toList();
      b.writeln('${s.code}${s.site.isEmpty ? '' : ' — ${s.site}'} (${s.matrix.label}, collected ${shortDate(s.collectedAt)})');
      if (s.results.isEmpty) {
        b.writeln('  Analysis in progress.');
      } else {
        for (final (r, k) in checks) {
          final flag = (k.status == Compliance.exceed || k.status == Compliance.belowMin) ? '  ⚠ ' : '    ';
          b.writeln('$flag${r.parameter}: ${resultText(r)} ${r.unit}${k.limit == null ? '' : '  (limit ${k.limit!.text})'}');
        }
        b.writeln(bad.isEmpty
            ? '  All results within ${set?.name ?? 'the applicable limits'}.'
            : '  ${bad.length} result${bad.length == 1 ? '' : 's'} outside ${set?.name ?? 'the limits'}: ${bad.map((x) => x.$1.parameter).join(', ')}.');
      }
      if (app.needsApproval(s)) b.writeln('  Note: preliminary — not yet approved by the reviewer.');
      b.writeln();
    }
    b.writeln('The full signed report is attached / available on request.');
    b.writeln();
    b.writeln(app.userName);
    b.writeln(app.settings.labName);
    if (app.settings.labPhone.isNotEmpty || app.settings.labEmail.isNotEmpty) b.writeln([app.settings.labPhone, app.settings.labEmail].where((x) => x.isNotEmpty).join(' · '));
    return b.toString();
  }
}
