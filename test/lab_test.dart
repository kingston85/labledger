// LabLedger 1.1: field work, inventory, quality system, verification, Excel.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labledger/core/holding.dart';
import 'package:labledger/core/lab_docs.dart';
import 'package:labledger/core/quality.dart';
import 'package:labledger/core/report.dart';
import 'package:labledger/core/xlsx.dart';
import 'package:labledger/data/app_state.dart';
import 'package:labledger/data/lab_models.dart';
import 'package:labledger/data/lab_ops.dart';
import 'package:labledger/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Method validation', () {
    test('MDL study (vs scipy t.ppf(0.99, 6))', () {
      final m = mdlStudy([0.021, 0.018, 0.024, 0.020, 0.019, 0.023, 0.022])!;
      expect(m.n, 7);
      expect(m.sd, closeTo(0.002160246899469287, 1e-12));
      expect(m.t, closeTo(3.1426684032910064, 1e-6));
      expect(m.mdl, closeTo(0.006788939674269492, 1e-8));
      expect(m.loq, closeTo(0.02160246899469287, 1e-12));
      expect(mdlStudy([1, 2]), isNull);
    });
    test('expanded uncertainty', () => expect(expandedUncertainty(3, 4), closeTo(10, 1e-12)));
    test('PT z-scores (ISO 13528)', () {
      final r = PtResult(parameter: 'Pb', reported: 0.0142, assigned: 0.010, sigma: 0.0012);
      expect(r.z, closeTo(3.5, 1e-9));
      expect(ptVerdict(r.z), PtVerdict.unsatisfactory);
      expect(ptVerdict(-2.0), PtVerdict.satisfactory);
      expect(ptVerdict(2.5), PtVerdict.questionable);
      expect(ptVerdict(null), isNull);
    });
  });

  group('Holding times', () {
    test('rules by parameter and matrix', () {
      expect(holdingRule('Iron (Fe)', Matrix.groundwater)!.hold, const Duration(days: 182));
      expect(holdingRule('Nitrate (as NO3)', Matrix.surfaceWater)!.hold, const Duration(hours: 48));
      expect(holdingRule('E. coli', Matrix.drinkingWater)!.hold, const Duration(hours: 8));
      expect(holdingRule('pH', Matrix.surfaceWater)!.group, 'Field');
      expect(holdingRule('Iron (Fe)', Matrix.soil)!.hold, const Duration(days: 180));
      expect(holdingRule('Mercury (Hg)', Matrix.surfaceWater)!.hold, const Duration(days: 28));
      expect(holdingRule('Unobtainium', Matrix.surfaceWater), isNull);
    });
    test('exceeded holding time is flagged', () {
      final t0 = DateTime(2026, 9, 1, 9);
      final s = Sample(id: 's', code: 'X-SW-001', collectedAt: t0, results: [
        Result(id: 'a', parameter: 'Nitrate (as NO3)', value: 12, date: t0.add(const Duration(days: 3))),
        Result(id: 'b', parameter: 'Iron (Fe)', value: 0.4, date: t0.add(const Duration(days: 3))),
        Result(id: 'c', parameter: 'pH', value: 6.8, unit: '', date: t0.add(const Duration(days: 3))),
      ]);
      final ex = holdingExceeded(s);
      expect(ex.map((h) => h.result.parameter), ['Nitrate (as NO3)']);
      expect(analyseBy(s, ['Iron (Fe)', 'Nitrate (as NO3)']), t0.add(const Duration(hours: 48)));
    });
  });

  group('Lab operations', () {
    late AppState app;
    setUp(() async {
      app = AppState();
      await app.init();
    });

    test('demo data covers the new modules', () {
      expect(app.methods, isNotEmpty);
      expect(app.ptRounds, isNotEmpty);
      expect(app.ncs.length, 3);
      expect(app.trips.length, 2);
      expect(app.purchases, isNotEmpty);
      expect(app.samplesOnTrip(app.trips.first.id), isNotEmpty);
      expect(app.methodFor('Iron (Fe)')!.code, 'SOP-MET-01');
      expect(app.ptSuccessRate, closeTo(4 / 6 * 100, 1e-9));
    });

    test('stock movements and purchasing', () {
      final r = app.reagents.first;
      final q0 = r.quantity!;
      app.moveStock(r, 10, StockReason.used, note: 'test');
      expect(r.quantity, q0 - 10);
      app.moveStock(r, 25, StockReason.received);
      expect(r.quantity, q0 + 15);
      expect(app.movesFor(r.id).first.qty, 25);
      final pr = app.purchaseFromLowStock();
      expect(pr.lines, isNotEmpty);
      expect(pr.lines.every((l) => l.reagentId != null && l.qty >= 1), isTrue);
      final low = app.reagent(pr.lines.first.reagentId)!;
      final before = low.quantity ?? 0;
      app.receivePurchase(pr);
      expect(pr.status, PurchaseStatus.received);
      expect(low.quantity, closeTo(before + pr.lines.first.qty, 1e-9));
    });

    test('maintenance log updates the instrument', () {
      final i = app.instruments.first;
      final when = DateTime.now();
      app.addMaintenance(i, MaintenanceLog(id: 'm', instrumentId: i.id, date: when, kind: MaintenanceKind.calibration));
      expect(i.lastCalibration, when);
      expect(daysUntil(i.calibrationDue!), greaterThan(300));
      app.addMaintenance(i, MaintenanceLog(id: 'n', instrumentId: i.id, kind: MaintenanceKind.verification, passed: false));
      expect(i.inService, isFalse);
      expect(app.logsFor(i.id).length, greaterThanOrEqualTo(3));
    });

    test('non-conformance numbering', () {
      final y = DateTime.now().year;
      final nc = app.raiseNc(title: 'Blank above LOQ', severity: NcSeverity.major);
      expect(nc.number, 'NC-$y-0004');
      expect(daysUntil(nc.dueDate!), 14);
      expect(app.openNcs.contains(nc), isTrue);
    });

    test('report issue and verification', () {
      final s = app.samples.firstWhere((s) => s.results.isNotEmpty);
      app.approveSample(s);
      final r = app.issueReport([s]);
      expect(r.number, 'RPT-${DateTime.now().year}-0001');
      expect(r.hash.length, 12);
      expect(app.issueReport([s]).number, r.number); // unchanged → same report
      var (found, match, unchanged) = app.verifyReport(r.number, groupCode(r.hash));
      expect(found, isNotNull);
      expect(match, isTrue);
      expect(unchanged, isTrue);
      (_, match, _) = app.verifyReport(r.number, 'AAAA-BBBB-CCCC');
      expect(match, isFalse);
      s.results.first.value = (s.results.first.value ?? 0) + 1;
      (found, match, unchanged) = app.verifyReport(r.number.toLowerCase(), r.hash);
      expect(match, isTrue);
      expect(unchanged, isFalse);
      expect(app.issueReport([s]).number, isNot(r.number));
      expect(app.verifyReport('RPT-1999-0001', r.hash).$1, isNull);
    });

    test('calendar is sorted and has every source', () {
      final ev = app.calendarEvents();
      for (var i = 1; i < ev.length; i++) {
        expect(!ev[i].date.isBefore(ev[i - 1].date), isTrue);
      }
      final kinds = ev.map((e) => e.kind).toSet();
      expect(kinds, containsAll([CalKind.trip, CalKind.calibration, CalKind.reagentExpiry, CalKind.invoiceDue, CalKind.ncDue, CalKind.methodReview]));
    });

    test('backup round trip keeps the new modules', () {
      final json = jsonDecode(jsonEncode(app.toJson())) as Map<String, dynamic>;
      final b = AppState();
      b.restore(json);
      expect(b.trips.length, app.trips.length);
      expect(b.methods.first.revisions.length, app.methods.first.revisions.length);
      expect(b.ptRounds.first.results.length, app.ptRounds.first.results.length);
      expect(b.ncs.length, app.ncs.length);
      expect(b.purchases.first.lines.length, app.purchases.first.lines.length);
      expect(b.stockMoves.length, app.stockMoves.length);
      expect(b.samples.where((s) => s.tripId != null).length, app.samples.where((s) => s.tripId != null).length);
      b.clearDemo();
      expect(b.trips, isEmpty);
      expect(b.methods, isEmpty);
      expect(b.ncs, isEmpty);
    });

    test('documents: PDF report with QR, field sheet, forms, Excel', () async {
      Directory('test_output').createSync(recursive: true);
      final s = app.samples.firstWhere((s) => s.results.length > 5);
      app.approveSample(s);
      final issued = app.issueReport([s]);
      final pdf = await Reports.sampleReport(app, [s], issued: issued);
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      File('test_output/report_with_qr.pdf').writeAsBytesSync(pdf);
      final sheet = await LabDocs.fieldSheet(app, app.trips.last);
      File('test_output/field_sheet.pdf').writeAsBytesSync(sheet);
      final pr = await LabDocs.purchasePdf(app, app.purchases.first);
      File('test_output/purchase_request.pdf').writeAsBytesSync(pr);
      final nc = await LabDocs.ncPdf(app, app.ncs.first);
      File('test_output/capa_form.pdf').writeAsBytesSync(nc);
      for (final b in [sheet, pr, nc]) {
        expect(String.fromCharCodes(b.take(4)), '%PDF');
      }

      final full = LabDocs.fullWorkbook(app);
      final z = ZipDecoder().decodeBytes(full);
      final names = z.files.map((f) => f.name).toSet();
      expect(names, containsAll(['[Content_Types].xml', 'xl/workbook.xml', 'xl/styles.xml', 'xl/worksheets/sheet1.xml', 'xl/worksheets/sheet11.xml']));
      final wb = utf8.decode(z.files.firstWhere((f) => f.name == 'xl/workbook.xml').content as List<int>);
      expect(wb, contains('name="Proficiency tests"'));
      File('test_output/labledger_full.xlsx').writeAsBytesSync(full);
      File('test_output/samples.xlsx').writeAsBytesSync(LabDocs.samplesWorkbook(app, app.samples));
      final text = LabDocs.emailSummary(app, [s]);
      expect(text, contains(s.code));
    });
  });

  test('xlsx column names', () {
    expect(colName(0), 'A');
    expect(colName(25), 'Z');
    expect(colName(26), 'AA');
    expect(colName(701), 'ZZ');
    expect(colName(702), 'AAA');
    final x = XlsxBuilder()..add('A/B:C?', ['h'], [
      ['<&>'],
    ]);
    expect(x.sheets.single.name, 'A B C');
  });
}
