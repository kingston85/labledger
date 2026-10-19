import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labledger/core/guidelines.dart';
import 'package:labledger/core/importer.dart';
import 'package:labledger/core/indices.dart';
import 'package:labledger/core/investigation.dart';
import 'package:labledger/core/word_reports.dart';
import 'package:labledger/data/app_state.dart';
import 'package:labledger/data/models.dart';

Result r(String p, double v, [String unit = 'mg/L']) => Result(id: p, parameter: p, value: v, unit: unit);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Water indices (hand-calculated)', () {
    final s = Sample(id: 's', code: 'KR-SW-001', results: [r('pH', 7.5, ''), r('Iron (Fe)', 2.77), r('Manganese (Mn)', 1.02)]);
    final g = buildInvestigation([s], (_) => liberiaWater()).single;
    final i = computeIndices(g).single;

    test('WQI', () => expect(i.wqi!.value, closeTo(108.288, 0.01)));
    test('HPI', () => expect(i.hpi!.value, closeTo(114.1667, 0.001)));
    test('HEI and contamination index', () {
      expect(i.hei!.value, closeTo(2.405, 1e-9));
      expect(i.cd!.value, closeTo(0.405, 1e-9));
    });
    test('Nemerow', () => expect(i.nemerow!.value, closeTo(1.29696, 1e-4)));
    test('classes', () {
      expect(i.wqi!.cls, 'Unsuitable for drinking');
      expect(i.hpi!.severity, 4);
    });
  });

  group('Soil indices', () {
    final ctrl = Sample(id: 'c', code: 'GR-C-SL-001', matrix: Matrix.soil, isControl: true, results: [
      r('Iron (Fe)', 0.61, 'mg/kg'),
      r('Lead (Pb)', 0.011, 'mg/kg'),
      r('Manganese (Mn)', 0.009, 'mg/kg'),
    ]);
    final s = Sample(id: 's', code: 'GR-SL-001', matrix: Matrix.soil, results: [
      r('Iron (Fe)', 8.01, 'mg/kg'),
      r('Lead (Pb)', 0.117, 'mg/kg'),
      r('Manganese (Mn)', 2.17, 'mg/kg'),
    ]);
    final g = buildInvestigation([ctrl, s], (_) => null).single;
    final i = computeIndices(g).firstWhere((e) => e.sample.code == 'GR-SL-001');

    test('Igeo', () => expect(i.igeo['Iron (Fe)'], closeTo(math.log(8.01 / (1.5 * 0.61)) / math.ln2, 1e-9)));
    test('ecological risk', () {
      expect(i.er['Lead (Pb)'], closeTo(5 * 0.117 / 0.011, 1e-9));
      expect(i.ri!.value, closeTo(5 * 0.117 / 0.011 + 2.17 / 0.009, 1e-9));
    });
    test('PLI', () {
      final cfs = [8.01 / 0.61, 0.117 / 0.011, 2.17 / 0.009];
      expect(i.pli!.value, closeTo(math.pow(cfs.reduce((a, b) => a * b), 1 / 3), 1e-9));
    });
  });

  group('Import', () {
    test('report table: parameters down, samples across, standard ignored', () {
      const t = 'Parameter (unit)\tKR-SW-001\tKR-C-SW-004\t*Liberian Standards\n'
          'pH\t6.47\t7.19\t6.5-8.5\n'
          'Conductivity (µS/cm)\t156\t92\t150\n'
          'Lead (ppm)\t0.005\t<0.001\t0.01\n'
          'Strontium (ppm)\t0.005\t0.001\tNG\n';
      final p = parseResults(t);
      expect(p.codes, {'KR-SW-001', 'KR-C-SW-004'});
      expect(p.rows.length, 8);
      final lead = p.rows.firstWhere((x) => x.code == 'KR-C-SW-004' && x.parameter == 'Lead (Pb)');
      expect(lead.value.belowLod, isTrue);
      expect(lead.value.lod, 0.001);
      expect(lead.unit, 'ppm');
      expect(p.rows.firstWhere((x) => x.parameter == 'Electrical conductivity').unit, 'µS/cm');
    });
    test('long format with quotes and units column', () {
      const t = 'Sample ID,Parameter,Result,Unit\nBT-GW-009,"Iron, total",2.07,mg/L\nBT-GW-009,Nitrate,44,mg/L\n';
      final p = parseResults(t);
      expect(p.rows.length, 2);
      expect(p.rows.last.parameter, 'Nitrate (as NO3)');
    });
    test('samples down, parameters across, triplicates', () {
      const t = 'Sample;pH;Iron (mg/L)\nYC-SW-005;6.97;2.05 2.12 2.13\n';
      final p = parseResults(t);
      expect(p.rows.length, 2);
      final fe = p.rows.firstWhere((x) => x.parameter == 'Iron (Fe)');
      expect(fe.value.value, closeTo(2.1, 1e-9));
      expect(fe.value.replicates.length, 3);
    });
    test('matrix from code', () {
      expect(matrixFromCode('GR-SL-006'), Matrix.soil);
      expect(matrixFromCode('BT-GW-009'), Matrix.groundwater);
      expect(matrixFromCode('LAB-2026-0001'), isNull);
    });
  });

  group('Word export', () {
    test('investigation and sample reports are valid .docx packages', () async {
      final app = AppState();
      await app.init(); // no storage in tests → demo data
      final project = app.samples.first.project;
      final samples = app.samplesInProject(project);
      final inv = WordReports.investigation(app, project, samples);
      final one = WordReports.samples(app, samples.take(2).toList());
      for (final bytes in [inv, one]) {
        final z = ZipDecoder().decodeBytes(bytes);
        final names = z.files.map((f) => f.name).toSet();
        expect(names, containsAll(['[Content_Types].xml', '_rels/.rels', 'word/document.xml', 'word/styles.xml', 'word/footer1.xml', 'word/_rels/document.xml.rels']));
        final doc = utf8.decode(z.files.firstWhere((f) => f.name == 'word/document.xml').content as List<int>);
        expect(doc, contains('<w:tbl>'));
        expect('<w:tbl>'.allMatches(doc).length, '</w:tbl>'.allMatches(doc).length);
        expect('<w:p>'.allMatches(doc).length + '<w:p><w:pPr>'.allMatches(doc).length, greaterThan(0));
        expect(doc.contains('&') && RegExp(r'&(?!amp;|lt;|gt;|quot;)').hasMatch(doc), isFalse);
      }
      final inText = utf8.decode(ZipDecoder().decodeBytes(inv).files.firstWhere((f) => f.name == 'word/document.xml').content as List<int>);
      expect(inText, contains('KR-SW-001'));
      expect(inText, contains('Pollution indices'));
      Directory('test_output').createSync(recursive: true);
      File('test_output/investigation.docx').writeAsBytesSync(inv);
      File('test_output/samples.docx').writeAsBytesSync(one);
      // Soil demo too.
      final soil = app.samples.where((s) => s.matrix.isSolid).toList();
      File('test_output/soil.docx').writeAsBytesSync(WordReports.investigation(app, soil.first.project, soil));
    });
  });
}
