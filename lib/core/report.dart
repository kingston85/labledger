import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_state.dart';
import '../data/models.dart';
import 'guidelines.dart';

String fmtValue(double v) {
  final a = v.abs();
  if (a != 0 && (a < 0.001 || a >= 1e6)) return v.toStringAsExponential(2);
  if (a < 0.1) return v.toStringAsFixed(4).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  if (a < 100) return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}

String resultText(Result r) {
  if (r.belowLod) return r.lod != null ? '< ${fmtValue(r.lod!)}' : '< LOD';
  if (r.value == null) return '—';
  return fmtValue(r.value!);
}

String complianceLabel(Compliance c) {
  switch (c) {
    case Compliance.pass:
      return 'Within limit';
    case Compliance.exceed:
      return 'EXCEEDS';
    case Compliance.belowMin:
      return 'BELOW RANGE';
    case Compliance.belowLod:
      return 'Not detected';
    case Compliance.noLimit:
      return 'No limit';
    case Compliance.unitMismatch:
      return 'Unit mismatch';
    case Compliance.missing:
      return 'Pending';
  }
}

class Reports {
  Reports._();

  static const _accent = PdfColor.fromInt(0xFF2F5BD3);
  static const _ink = PdfColor.fromInt(0xFF0E1116);
  static const _dim = PdfColor.fromInt(0xFF5A6478);
  static const _line = PdfColor.fromInt(0xFFD5DAE2);
  static const _panel = PdfColor.fromInt(0xFFF4F6F9);
  static const _bad = PdfColor.fromInt(0xFFC62828);
  static const _good = PdfColor.fromInt(0xFF0F8A55);

  static Future<Uint8List> sampleReport(AppState app, List<Sample> samples) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final mono = pw.Font.ttf(await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
    final st = app.settings;
    final doc = pw.Document(title: 'Laboratory test report', author: st.labName, creator: 'LabLedger');
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final now = DateTime.now();

    for (final s in samples) {
      final set = app.limitsFor(s);
      final checks = [for (final r in s.results) checkResult(r, set)];
      final exceed = checks.where((c) => c.status == Compliance.exceed || c.status == Compliance.belowMin).length;
      final params = s.results.map((r) => normKey(r.parameter)).toSet();
      final qcRel = app.qc.where((q) => params.contains(normKey(q.parameter))).toList();

      pw.Widget kv(String k, String v) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(width: 92, child: pw.Text(k, style: const pw.TextStyle(fontSize: 8.5, color: _dim))),
              pw.Expanded(child: pw.Text(v.isEmpty ? '—' : v, style: const pw.TextStyle(fontSize: 9, color: _ink))),
            ]),
          );

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 28),
        theme: theme,
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2))),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(st.labName, style: pw.TextStyle(font: bold, fontSize: 11, color: _ink)),
                pw.Text('Laboratory test report', style: const pw.TextStyle(fontSize: 9, color: _dim)),
              ]),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(s.code, style: pw.TextStyle(font: bold, fontSize: 12, color: _accent)),
              pw.Text('Issued ${shortDate(now)}', style: const pw.TextStyle(fontSize: 8, color: _dim)),
            ]),
          ]),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line))),
          child: pw.Row(children: [
            pw.Expanded(
              child: pw.Text(
                'Results relate only to the sample as received. Limits: ${set?.name ?? 'none selected'}. '
                'This report shall not be reproduced except in full without approval of the laboratory.',
                style: const pw.TextStyle(fontSize: 6.8, color: _dim),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: _dim)),
          ]),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                kv('Sample site', s.site),
                kv('Project', s.project),
                kv('Matrix', s.matrix.label),
                kv('Coordinates', s.lat != null && s.lon != null ? '${s.lat!.toStringAsFixed(5)}, ${s.lon!.toStringAsFixed(5)}' : ''),
              ]),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                kv('Collected', dateTime(s.collectedAt)),
                kv('Received', s.receivedAt == null ? '' : dateTime(s.receivedAt!)),
                kv('Collected by', s.collector),
                kv('Preservation', s.preservation),
              ]),
            ),
          ]),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: exceed > 0 ? const PdfColor.fromInt(0x1AC62828) : const PdfColor.fromInt(0x1A0F8A55),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Text(
              s.results.isEmpty
                  ? 'No results recorded yet.'
                  : exceed > 0
                      ? '$exceed of ${s.results.length} parameters do not comply with ${set?.name ?? 'the selected limits'}.'
                      : 'All ${s.results.length} parameters comply with ${set?.name ?? 'the selected limits'} (where a limit applies).',
              style: pw.TextStyle(font: bold, fontSize: 9.5, color: exceed > 0 ? _bad : _good),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('RESULTS', style: pw.TextStyle(font: bold, fontSize: 8, letterSpacing: 1.2, color: _dim)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Parameter', 'Result', 'Unit', 'Method', 'Limit', 'Assessment'],
            data: [
              for (var i = 0; i < s.results.length; i++)
                [
                  s.results[i].parameter,
                  resultText(s.results[i]),
                  s.results[i].unit,
                  s.results[i].method,
                  checks[i].limit?.text ?? '—',
                  complianceLabel(checks[i].status),
                ]
            ],
            headerStyle: pw.TextStyle(font: bold, fontSize: 8, color: _ink),
            cellStyle: pw.TextStyle(font: mono, fontSize: 8, color: _ink),
            headerDecoration: const pw.BoxDecoration(color: _panel),
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            cellDecoration: (index, data, rowNum) {
              if (rowNum < 1 || rowNum > checks.length) return const pw.BoxDecoration();
              final st = checks[rowNum - 1].status;
              return st == Compliance.exceed || st == Compliance.belowMin
                  ? const pw.BoxDecoration(color: PdfColor.fromInt(0x14C62828))
                  : const pw.BoxDecoration();
            },
          ),
          if (s.results.any((r) => r.note.isNotEmpty)) ...[
            pw.SizedBox(height: 6),
            for (final r in s.results.where((r) => r.note.isNotEmpty))
              pw.Text('${r.parameter}: ${r.note}', style: const pw.TextStyle(fontSize: 8, color: _dim)),
          ],
          if (qcRel.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('QUALITY CONTROL', style: pw.TextStyle(font: bold, fontSize: 8, letterSpacing: 1.2, color: _dim)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['Check', 'Parameter', 'Batch', 'Date', 'Result', 'Status'],
              data: [
                for (final q in qcRel.take(12))
                  () {
                    final e = app.qcEvaluate(q);
                    return [q.type.label, q.parameter, q.batch, shortDate(q.date), e.$3, e.$1 ? 'Pass' : 'FAIL'];
                  }()
              ],
              headerStyle: pw.TextStyle(font: bold, fontSize: 7.5, color: _ink),
              cellStyle: const pw.TextStyle(fontSize: 7.5, color: _ink),
              headerDecoration: const pw.BoxDecoration(color: _panel),
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            ),
          ],
          if (s.custody.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('CHAIN OF CUSTODY', style: pw.TextStyle(font: bold, fontSize: 8, letterSpacing: 1.2, color: _dim)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['Date / time', 'Released by', 'Received by', 'Condition'],
              data: [for (final c in s.custody) [dateTime(c.time), c.from, c.to, c.condition]],
              headerStyle: pw.TextStyle(font: bold, fontSize: 7.5, color: _ink),
              cellStyle: const pw.TextStyle(fontSize: 7.5, color: _ink),
              headerDecoration: const pw.BoxDecoration(color: _panel),
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            ),
          ],
          if (s.notes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text('Remarks: ${s.notes}', style: const pw.TextStyle(fontSize: 8.5, color: _ink)),
          ],
          pw.SizedBox(height: 26),
          pw.Row(children: [
            _sig('Analysed by', st.analyst, bold),
            pw.SizedBox(width: 24),
            _sig('Reviewed / approved by', st.reviewer, bold),
            pw.SizedBox(width: 24),
            _sig('Date', '', bold),
          ]),
        ],
      ));
    }
    return doc.save();
  }

  static pw.Widget _sig(String label, String name, pw.Font bold) => pw.Expanded(
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(height: 18, alignment: pw.Alignment.bottomLeft, child: pw.Text(name, style: const pw.TextStyle(fontSize: 9.5))),
          pw.Container(height: 0.8, color: _ink),
          pw.SizedBox(height: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
        ]),
      );

  static String _csv(String s) => (s.contains(',') || s.contains('"') || s.contains('\n')) ? '"${s.replaceAll('"', '""')}"' : s;

  /// All results as a flat CSV for Excel.
  static String resultsCsv(AppState app, [List<Sample>? only]) {
    final b = StringBuffer('sample_code,site,project,matrix,latitude,longitude,collected,status,parameter,value,below_lod,lod,unit,'
        'method,analyst,result_date,dilution,limit,assessment,note\n');
    for (final s in only ?? app.samples) {
      final set = app.limitsFor(s);
      for (final r in s.results) {
        final c = checkResult(r, set);
        b.writeln([
          s.code,
          _csv(s.site),
          _csv(s.project),
          s.matrix.label,
          s.lat?.toStringAsFixed(6) ?? '',
          s.lon?.toStringAsFixed(6) ?? '',
          s.collectedAt.toIso8601String(),
          s.status.label,
          _csv(r.parameter),
          r.value?.toString() ?? '',
          r.belowLod ? 'yes' : 'no',
          r.lod?.toString() ?? '',
          r.unit,
          _csv(r.method),
          _csv(r.analyst),
          r.date.toIso8601String(),
          r.dilution.toString(),
          _csv(c.limit?.text ?? ''),
          complianceLabel(c.status),
          _csv(r.note),
        ].join(','));
      }
    }
    return b.toString();
  }
}
