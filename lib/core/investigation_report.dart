import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_state.dart';
import '../data/models.dart';
import 'guidelines.dart';
import 'indices.dart';
import 'investigation.dart';
import 'report.dart';
import 'utm.dart';

const _accent = PdfColor.fromInt(0xFF2F5BD3);
const _ink = PdfColor.fromInt(0xFF0E1116);
const _dim = PdfColor.fromInt(0xFF5A6478);
const _line = PdfColor.fromInt(0xFFD5DAE2);
const _panel = PdfColor.fromInt(0xFFF4F6F9);
const _bad = PdfColor.fromInt(0xFFC62828);
const _badBg = PdfColor.fromInt(0xFFF7E2E2);
const _ctrlBg = PdfColor.fromInt(0xFFE8F4EF);

PdfColor _cfColor(double cf) {
  if (cf < 1) return const PdfColor.fromInt(0xFFFFFFFF);
  if (cf < 3) return const PdfColor.fromInt(0xFFFCF1CD);
  if (cf < 6) return const PdfColor.fromInt(0xFFFBD9AC);
  return const PdfColor.fromInt(0xFFECB7B7);
}

String _stdText(Limit? l) {
  if (l == null) return 'NG';
  return l.unit.isEmpty ? l.text : l.text.replaceAll(' ${l.unit}', '');
}

String cellText(Result? r) => r == null ? '' : resultText(r);

String paramHeader(InvestigationGroup g, String p) {
  final u = g.unitFor(p);
  return u.isEmpty ? p : '$p ($u)';
}

class InvestigationReports {
  InvestigationReports._();

  static Future<Uint8List> pdf(AppState app, String project, List<Sample> samples) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final mono = pw.Font.ttf(await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
    final st = app.settings;
    final groups = buildInvestigation(samples, app.limitsFor);
    final doc = pw.Document(title: 'Investigation report: $project', author: st.labName, creator: 'LabLedger');
    final now = DateTime.now();
    final dates = samples.map((s) => s.collectedAt).toList()..sort();

    pw.Widget h(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 5),
          child: pw.Text(t.toUpperCase(), style: pw.TextStyle(font: bold, fontSize: 8.5, letterSpacing: 1.1, color: _accent)),
        );

    pw.Widget table(List<String> headers, List<List<String>> rows,
        {PdfColor? Function(int row, int col)? shade, double font = 7.2, Map<int, pw.TableColumnWidth>? widths}) {
      return pw.Table(
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _line, width: 0.4),
          bottom: pw.BorderSide(color: _line, width: 0.4),
        ),
        columnWidths: widths,
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _panel),
            children: [
              for (final hd in headers)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  child: pw.Text(hd, style: pw.TextStyle(font: bold, fontSize: font, color: _ink)),
                ),
            ],
          ),
          for (var r = 0; r < rows.length; r++)
            pw.TableRow(children: [
              for (var col = 0; col < rows[r].length; col++)
                pw.Container(
                  color: shade?.call(r, col),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                  child: pw.Text(rows[r][col],
                      style: pw.TextStyle(font: col == 0 ? regular : mono, fontSize: font, color: _ink)),
                ),
            ]),
        ],
      );
    }

    final content = <pw.Widget>[];
    final exceedTotal = groups.fold<int>(0, (a, g) {
      var n = 0;
      for (final s in g.samples) {
        for (final p in g.parameters) {
          final c = g.check(s, p);
          if (!g.solid && (c.status == Compliance.exceed || c.status == Compliance.belowMin)) n++;
        }
      }
      return a + n;
    });
    final nResults = samples.fold<int>(0, (a, s) => a + s.results.length);
    final withReps = samples.expand((s) => s.results).where((r) => r.replicates.length > 1).toList();

    content.add(pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(color: _panel, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
      child: pw.Row(children: [
        for (final kv in [
          ('Samples', '${samples.length}'),
          ('Controls', '${samples.where((s) => s.isControl).length}'),
          ('Results', '$nResults'),
          ('Non-compliant results', '$exceedTotal'),
          ('Sampling', dates.isEmpty ? '—' : '${shortDate(dates.first)}${dates.length > 1 && shortDate(dates.last) != shortDate(dates.first) ? ' – ${shortDate(dates.last)}' : ''}'),
        ])
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(kv.$1, style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
              pw.Text(kv.$2, style: pw.TextStyle(font: bold, fontSize: 11, color: kv.$1.startsWith('Non') && exceedTotal > 0 ? _bad : _ink)),
            ]),
          ),
      ]),
    ));

    // Findings first, as in an executive summary.
    for (final g in groups) {
      content.add(h('Key findings · ${g.title}'));
      for (final line in allFindings(g)) {
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('•  ', style: const pw.TextStyle(fontSize: 8.5, color: _accent)),
            pw.Expanded(child: pw.Text(line, style: const pw.TextStyle(fontSize: 8.5, color: _ink, lineSpacing: 1.5))),
          ]),
        ));
      }
    }

    // Sample register.
    content.add(h('Sampling locations'));
    final reg = [...samples]..sort((a, b) => a.collectedAt.compareTo(b.collectedAt));
    content.add(table(
      ['Sample code', 'Location / description', 'Matrix', 'Lat, Lon', 'UTM 29N X', 'UTM 29N Y', 'Date', 'Time'],
      [
        for (final s in reg)
          () {
            final u = s.lat != null && s.lon != null ? toUtm(s.lat!, s.lon!, zone: 29) : null;
            return [
              '${s.code}${s.isControl ? ' (control)' : ''}',
              s.site,
              s.matrix.label,
              s.lat != null && s.lon != null ? '${s.lat!.toStringAsFixed(5)}, ${s.lon!.toStringAsFixed(5)}' : '—',
              u == null ? '—' : u.easting.toStringAsFixed(0),
              u == null ? '—' : u.northing.toStringAsFixed(0),
              shortDate(s.collectedAt),
              timeOfDay(s.collectedAt),
            ];
          }()
      ],
      shade: (r, c) => reg[r].isControl ? _ctrlBg : null,
      widths: {0: const pw.FixedColumnWidth(78), 1: const pw.FlexColumnWidth(3)},
    ));

    // Results matrices, chunked so columns stay readable.
    for (final g in groups) {
      const per = 9;
      for (var start = 0; start < g.samples.length; start += per) {
        final chunk = g.samples.sublist(start, math.min(start + per, g.samples.length));
        content.add(h('Results · ${g.title}${g.samples.length > per ? ' (${start + 1}–${start + chunk.length})' : ''}'));
        final rows = [
          for (final p in g.parameters)
            [
              paramHeader(g, p),
              for (final s in chunk) cellText(g.cell(s, p)),
              if (!g.solid) _stdText(g.limitFor(p)),
            ]
        ];
        content.add(table(
          ['Parameter', for (final s in chunk) s.isControl ? '${s.code}\n(control)' : s.code, if (!g.solid) 'Standard'],
          rows,
          shade: (r, c) {
            if (c == 0 || c > chunk.length) return null;
            final s = chunk[c - 1];
            final k = g.check(s, g.parameters[r]);
            if (!g.solid && (k.status == Compliance.exceed || k.status == Compliance.belowMin)) return _badBg;
            return s.isControl ? _ctrlBg : null;
          },
          widths: {0: const pw.FixedColumnWidth(118)},
        ));
      }
      if (!g.solid && g.limits != null) {
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text('Shaded red: outside ${g.limits!.name}. NG = no guideline. Green columns: control samples.',
              style: const pw.TextStyle(fontSize: 7, color: _dim)),
        ));
      }

      // Control comparison.
      if (g.controls.isNotEmpty && g.impacted.isNotEmpty) {
        final imp = g.impacted;
        final params = g.parameters.where((p) => imp.any((s) => g.factor(s, p) != null)).toList();
        for (var start = 0; start < imp.length; start += 9) {
          final chunk = imp.sublist(start, math.min(start + 9, imp.length));
          content.add(h('${g.solid ? 'Contamination factor (CF = sample ÷ control)' : 'Enrichment vs control (× control)'} · ${g.title}'));
          final rows = [
            for (final p in params)
              [
                paramHeader(g, p),
                () {
                  final ref = g.controlRef(p);
                  return ref == null ? '—' : '${ref.nonDetect ? '<' : ''}${fmtValue(ref.value)}';
                }(),
                for (final s in chunk) () {
                  final f = g.factor(s, p);
                  return f == null ? '—' : f.toStringAsFixed(f >= 10 ? 0 : 1);
                }(),
              ],
            if (g.solid)
              ['Pollution load index', '', for (final s in chunk) g.pli(s)?.toStringAsFixed(2) ?? '—'],
          ];
          content.add(table(
            ['Parameter', 'Control', for (final s in chunk) s.code],
            rows,
            shade: (r, c) {
              if (c < 2 || r >= params.length) return null;
              final f = g.factor(chunk[c - 2], params[r]);
              return f == null ? null : _cfColor(f);
            },
            widths: {0: const pw.FixedColumnWidth(118)},
          ));
        }
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(
              'Classes (Håkanson 1980): < 1 low · 1–3 moderate · 3–6 considerable · ≥ 6 very high. '
              'A control below detection uses its detection limit, so factors are conservative. '
              '${g.solid ? 'PLI = geometric mean of CFs (Tomlinson 1980); PLI > 1 indicates pollution.' : ''}',
              style: const pw.TextStyle(fontSize: 7, color: _dim)),
        ));
      }
    }

    // Pollution indices.
    for (final g in groups) {
      final idx = computeIndices(g);
      String f(Indexed? x) => x == null ? '—' : '${x.value.toStringAsFixed(x.value.abs() >= 100 ? 0 : 1)} ${x.cls}';
      if (!g.solid) {
        if (!idx.any((e) => e.wqi != null || e.hpi != null)) continue;
        content.add(h('Pollution indices · ${g.title}'));
        content.add(table(
          ['Sample', 'WQI', 'HPI', 'HEI', 'Contamination index', 'Nemerow'],
          [for (final e in idx) [e.sample.isControl ? '${e.sample.code} (control)' : e.sample.code, f(e.wqi), f(e.hpi), f(e.hei), f(e.cd), f(e.nemerow)]],
          shade: (r, col) => col > 0 && [idx[r].wqi, idx[r].hpi, idx[r].hei, idx[r].cd, idx[r].nemerow][col - 1]?.severity == 4 ? _badBg : null,
          widths: {0: const pw.FixedColumnWidth(90)},
        ));
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(
              'WQI: weighted arithmetic index (≤25 excellent, 26–50 good, 51–75 poor, 76–100 very poor, >100 unsuitable). HPI critical value 100. '
              'HEI <10 low, 10–20 medium, >20 high. Contamination index <1 low, 1–3 medium, >3 high. Nemerow ≤0.7 clean … >3 heavy. Non-detects at half the detection limit.',
              style: const pw.TextStyle(fontSize: 7, color: _dim)),
        ));
      } else if (g.controls.isNotEmpty) {
        final imp = idx.where((e) => !e.sample.isControl).toList();
        if (imp.isEmpty) continue;
        content.add(h('Pollution indices · ${g.title}'));
        content.add(table(
          ['Sample', 'PLI', 'Degree of contamination', 'Ecological risk RI'],
          [for (final e in imp) [e.sample.code, f(e.pli), f(e.cdeg), f(e.ri)]],
          widths: {0: const pw.FixedColumnWidth(90)},
        ));
        final metals = g.parameters.where((p) => imp.any((e) => e.igeo.containsKey(p))).toList();
        for (var start = 0; start < imp.length; start += 9) {
          final chunk = imp.sublist(start, math.min(start + 9, imp.length));
          content.add(h('Geo-accumulation index (Igeo) · ${g.title}'));
          content.add(table(
            ['Parameter', for (final e in chunk) e.sample.code],
            [for (final p in metals) [p, for (final e in chunk) e.igeo[p] == null ? '—' : e.igeo[p]!.toStringAsFixed(2)]],
            shade: (r, col) {
              if (col == 0) return null;
              final v = chunk[col - 1].igeo[metals[r]];
              return v == null ? null : _cfColor(v <= 0 ? 0.5 : (v <= 2 ? 2 : (v <= 3 ? 4 : 7)));
            },
            widths: {0: const pw.FixedColumnWidth(118)},
          ));
        }
        content.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3),
          child: pw.Text(
              'Background = control sample mean. Igeo = log2(Cn/1.5Bn): ≤0 unpolluted, 0–1 unpolluted–moderate, 1–2 moderate, 2–3 moderate–heavy, 3–4 heavy, 4–5 heavy–extreme, >5 extreme. '
              'RI = Σ Tr·CF (Håkanson): <150 low, 150–300 moderate, 300–600 considerable, ≥600 very high.',
              style: const pw.TextStyle(fontSize: 7, color: _dim)),
        ));
      }
    }

    content.add(h('Quality assurance / quality control'));
    final qaLines = <String>[
      if (withReps.isNotEmpty)
        '${withReps.length} of $nResults results are means of replicate analyses '
            '(largest RSD ${withReps.map((r) => _rsd(r.replicates)).reduce(math.max).toStringAsFixed(1)}%; acceptance ≤ ${st.replicateRsdMax.toStringAsFixed(0)}%).',
      if (samples.any((s) => s.isControl)) 'Control (background) samples were collected outside the impact pathway and analysed with the same methods.',
      'Methods: ${samples.expand((s) => s.results).map((r) => r.method).where((m) => m.isNotEmpty).toSet().join(', ')}.',
    ];
    final params = samples.expand((s) => s.results).map((r) => paramKey(r.parameter)).toSet();
    final qcRel = app.qc.where((q) => params.contains(paramKey(q.parameter))).toList();
    for (final l in qaLines) {
      content.add(pw.Text('•  $l', style: const pw.TextStyle(fontSize: 8.5, color: _ink, lineSpacing: 1.4)));
    }
    if (qcRel.isNotEmpty) {
      content.add(pw.SizedBox(height: 5));
      content.add(table(
        ['Check', 'Parameter', 'Batch', 'Date', 'Result', 'Status'],
        [
          for (final q in qcRel.take(20))
            () {
              final e = app.qcEvaluate(q);
              return [q.type.label, q.parameter, q.batch, shortDate(q.date), e.$3, e.$1 ? 'Pass' : 'FAIL'];
            }()
        ],
      ));
    }

    content.add(pw.SizedBox(height: 28));
    content.add(pw.Row(children: [
      _sig('Prepared by', st.analyst),
      pw.SizedBox(width: 24),
      _sig('Reviewed / approved by', st.reviewer),
      pw.SizedBox(width: 24),
      _sig('Date', ''),
    ]));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(30, 26, 30, 24),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2))),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(st.labName, style: pw.TextStyle(font: bold, fontSize: 10.5, color: _ink)),
              pw.Text('Field investigation: laboratory results and assessment', style: const pw.TextStyle(fontSize: 8.5, color: _dim)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(project, style: pw.TextStyle(font: bold, fontSize: 11, color: _accent)),
            pw.Text('Issued ${shortDate(now)}', style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
          ]),
        ]),
      ),
      footer: (ctx) => pw.Row(children: [
        pw.Expanded(
          child: pw.Text('Generated by LabLedger. Results relate only to the samples as received.',
              style: const pw.TextStyle(fontSize: 6.8, color: _dim)),
        ),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(font: mono, fontSize: 7, color: _dim)),
      ]),
      build: (_) => content,
    ));
    return doc.save();
  }

  /// Blank-ready chain-of-custody / sample submission form for a project.
  static Future<Uint8List> cocSheet(AppState app, String project, List<Sample> samples) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final st = app.settings;
    final doc = pw.Document(title: 'Chain of custody: $project', author: st.labName, creator: 'LabLedger');
    final list = [...samples]..sort((a, b) => a.collectedAt.compareTo(b.collectedAt));
    pw.Widget box(String label, String value, {double flex = 1}) => pw.Expanded(
          flex: (flex * 10).round(),
          child: pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(5, 3, 5, 4),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.6)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: _dim)),
              pw.SizedBox(height: 2),
              pw.Text(value.isEmpty ? ' ' : value, style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
        );
    pw.Widget grid(List<String> headers, List<List<String>> rows, Map<int, pw.TableColumnWidth> widths, {double rowH = 20}) => pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: widths,
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _panel), children: [
              for (final h in headers)
                pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(h, style: pw.TextStyle(font: bold, fontSize: 7.2))),
            ]),
            for (final r in rows)
              pw.TableRow(children: [
                for (final c in r)
                  pw.Container(
                    constraints: pw.BoxConstraints(minHeight: rowH),
                    padding: const pw.EdgeInsets.all(3),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(c, style: const pw.TextStyle(fontSize: 7.8)),
                  ),
              ]),
          ],
        );
    final params = samples.expand((s) => s.results).map((r) => r.parameter).toSet().toList();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(26, 22, 26, 20),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (ctx) => [
        pw.Row(children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(st.labName, style: pw.TextStyle(font: bold, fontSize: 11)),
              pw.Text('CHAIN OF CUSTODY & SAMPLE SUBMISSION FORM', style: pw.TextStyle(font: bold, fontSize: 13, color: _accent)),
            ]),
          ),
          pw.Text('Form LL-COC-01', style: const pw.TextStyle(fontSize: 8, color: _dim)),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          box('Project / investigation', project, flex: 3),
          box('Client / requested by', ''),
          box('Sampling team leader', samples.map((s) => s.collector).where((x) => x.isNotEmpty).toSet().join(', ')),
          box('Contact phone', ''),
        ]),
        pw.Row(children: [
          box('Site / area', ''),
          box('Sampling date(s)', list.isEmpty ? '' : (shortDate(list.first.collectedAt) == shortDate(list.last.collectedAt) ? shortDate(list.first.collectedAt) : '${shortDate(list.first.collectedAt)} – ${shortDate(list.last.collectedAt)}')),
          box('Cooler temperature on dispatch (°C)', ''),
          box('Turnaround', 'Normal  /  Urgent'),
        ]),
        pw.SizedBox(height: 8),
        grid(
          ['#', 'Sample code', 'Location / description', 'Matrix', 'Date', 'Time', 'Lat, Lon / UTM', 'Containers & preservation', 'Analyses requested', 'Remarks'],
          [
            for (var i = 0; i < list.length; i++)
              [
                '${i + 1}',
                '${list[i].code}${list[i].isControl ? ' (C)' : ''}',
                list[i].site,
                list[i].matrix.label,
                shortDate(list[i].collectedAt),
                timeOfDay(list[i].collectedAt),
                list[i].lat == null || list[i].lon == null ? '' : '${list[i].lat!.toStringAsFixed(5)}, ${list[i].lon!.toStringAsFixed(5)}',
                list[i].preservation,
                '',
                '',
              ],
            for (var i = 0; i < 4; i++) ['${list.length + i + 1}', '', '', '', '', '', '', '', '', ''],
          ],
          {
            0: const pw.FixedColumnWidth(16),
            1: const pw.FixedColumnWidth(64),
            2: const pw.FlexColumnWidth(2.4),
            3: const pw.FixedColumnWidth(54),
            4: const pw.FixedColumnWidth(52),
            5: const pw.FixedColumnWidth(30),
            6: const pw.FixedColumnWidth(78),
            7: const pw.FlexColumnWidth(1.6),
            8: const pw.FlexColumnWidth(1.6),
            9: const pw.FlexColumnWidth(1.2),
          },
        ),
        if (params.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text('Analysis suite for this investigation: ${params.join(', ')}.', style: const pw.TextStyle(fontSize: 7, color: _dim)),
        ],
        pw.SizedBox(height: 10),
        pw.Text('CUSTODY TRANSFERS', style: pw.TextStyle(font: bold, fontSize: 8.5, color: _accent)),
        pw.SizedBox(height: 4),
        grid(
          ['Relinquished by (name & signature)', 'Date', 'Time', 'Received by (name & signature)', 'Date', 'Time', 'Condition / seal / temperature'],
          [for (var i = 0; i < 4; i++) ['', '', '', '', '', '', '']],
          {1: const pw.FixedColumnWidth(56), 2: const pw.FixedColumnWidth(40), 4: const pw.FixedColumnWidth(56), 5: const pw.FixedColumnWidth(40)},
          rowH: 24,
        ),
        pw.SizedBox(height: 10),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          box('LAB USE · Received at lab (date / time)', ''),
          box('Custody seals intact?   Yes / No', ''),
          box('Temperature on receipt (°C)', ''),
          box('Lab sample IDs assigned', ''),
          box('Received by (lab)', ''),
        ]),
        pw.SizedBox(height: 6),
        pw.Text('Keep samples cool (≤ 6 °C) and in the dark. Record every hand-over above. Metals: HNO3 to pH < 2. Nutrients: 4 °C, analyse within 48 h. '
            'Microbiology: sterile bottles, analyse within 24 h.', style: const pw.TextStyle(fontSize: 6.8, color: _dim)),
      ],
    ));
    return doc.save();
  }

  static double _rsd(List<double> v) {
    final n = v.length;
    final m = v.reduce((a, b) => a + b) / n;
    if (n < 2 || m == 0) return 0;
    final sd = math.sqrt(v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (n - 1));
    return sd / m.abs() * 100;
  }

  static pw.Widget _sig(String label, String name) => pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(height: 18, alignment: pw.Alignment.bottomLeft, child: pw.Text(name, style: const pw.TextStyle(fontSize: 9.5))),
          pw.Container(height: 0.8, color: _ink),
          pw.SizedBox(height: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
        ]),
      );

  static String _csv(String s) => (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;

  /// Parameter × sample matrix with the standard column, as in report tables.
  static String matrixCsv(AppState app, List<Sample> samples) {
    final b = StringBuffer();
    for (final g in buildInvestigation(samples, app.limitsFor)) {
      b.writeln(_csv(g.title));
      b.writeln(['Parameter', 'Unit', for (final s in g.samples) _csv(s.isControl ? '${s.code} (control)' : s.code), 'Standard'].join(','));
      for (final p in g.parameters) {
        b.writeln([
          _csv(p),
          _csv(g.unitFor(p)),
          for (final s in g.samples) _csv(cellText(g.cell(s, p))),
          _csv(g.limitFor(p)?.text ?? (g.solid ? '' : 'NG')),
        ].join(','));
      }
      b.writeln();
    }
    return b.toString();
  }
}
