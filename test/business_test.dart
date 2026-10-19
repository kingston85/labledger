// LabLedger 1.0: business documents, users/audit, approval, analytics, GIS.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labledger/core/analytics.dart';
import 'package:labledger/core/business_docs.dart';
import 'package:labledger/core/gis.dart';
import 'package:labledger/data/app_state.dart';
import 'package:labledger/data/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Money', () {
    test('totals with discount and tax are rounded to cents', () {
      final inv = Invoice(id: 'i', number: 'INV-1', lines: [
        DocLine(description: 'Metals', qty: 3, unitPrice: 33.333),
        DocLine(description: 'pH', qty: 2, unitPrice: 5),
      ], discountPct: 10, taxPct: 7.5);
      expect(inv.subtotal, closeTo(109.999, 1e-9));
      expect(inv.discount, 11.0);
      expect(inv.tax, closeTo(7.42, 1e-9)); // 98.999 × 7.5 % = 7.4249
      expect(inv.total, closeTo(106.42, 1e-9));
    });

    test('invoice status follows payments and due date', () {
      final inv = Invoice(id: 'i', number: 'INV-1', dueDate: DateTime.now().add(const Duration(days: 5)), lines: [DocLine(description: 'x', unitPrice: 100)]);
      expect(inv.status, InvoiceStatus.unpaid);
      inv.payments.add(Payment(id: 'p', amount: 40));
      expect(inv.status, InvoiceStatus.partial);
      expect(inv.balance, 60);
      inv.payments.add(Payment(id: 'q', amount: 60));
      expect(inv.status, InvoiceStatus.paid);
      final late = Invoice(id: 'j', number: 'INV-2', dueDate: DateTime.now().subtract(const Duration(days: 1)), lines: [DocLine(description: 'x', unitPrice: 10)]);
      expect(late.status, InvoiceStatus.overdue);
      late.issued = false;
      expect(late.status, InvoiceStatus.draft);
      late.cancelled = true;
      expect(late.status, InvoiceStatus.cancelled);
    });

    test('formatting', () {
      expect(money(1234567.5, 'USD'), r'$1,234,567.50');
      expect(money(-12, 'LRD'), r'-L$12.00');
      expect(money(999, 'EUR'), '€999.00');
      expect(money(1000, 'XOF'), 'XOF 1,000.00');
    });

    test('JSON round trip', () {
      final inv = Invoice(id: 'i', number: 'INV-1', lines: [DocLine(description: 'x', qty: 2, unitPrice: 3)], payments: [Payment(id: 'p', amount: 1, receiptNo: 'RCT-1')], taxPct: 5);
      final back = Invoice.fromJson(jsonDecode(jsonEncode(inv.toJson())) as Map<String, dynamic>);
      expect(back.total, inv.total);
      expect(back.payments.single.receiptNo, 'RCT-1');
    });
  });

  group('Workflow', () {
    late AppState app;
    setUp(() async {
      app = AppState();
      await app.init();
    });

    test('document numbering', () {
      final y = DateTime.now().year;
      expect(app.nextNumber('REQ', ['REQ-$y-0003', 'REQ-$y-0010', 'REQ-${y - 1}-0099', 'junk']), 'REQ-$y-0011');
      expect(app.nextNumber('INV', const []), 'INV-$y-0001');
    });

    test('invoice from request copies lines and terms', () {
      final r = app.requests.first;
      final inv = app.invoiceFromRequest(r);
      expect(inv.total, closeTo(r.total, 1e-9));
      expect(inv.requestId, r.id);
      expect(app.audit.last.entity, 'Invoice');
    });

    test('PIN sign-in, failure logging and roles', () {
      final u = AppUser(id: 'u1', name: 'Ama Kollie', role: Role.reviewer);
      app.setPin(u, '2468');
      app.users.add(u);
      expect(u.pinHash, isNot(contains('2468')));
      expect(app.locked, isTrue);
      expect(app.login(u, '1111'), isFalse);
      expect(app.audit.last.action, 'login failed');
      expect(app.login(u, '2468'), isTrue);
      expect(app.locked, isFalse);
      expect(app.canApprove, isTrue);
      expect(app.isAdmin, isFalse);
      expect(u.initials, 'AK');
      app.logout();
      expect(app.locked, isTrue);
    });

    test('approval gate and turnaround', () {
      final s = Sample(id: 'x', code: 'T-1', collectedAt: DateTime.now().subtract(const Duration(days: 5)), receivedAt: DateTime.now().subtract(const Duration(days: 4)), results: [Result(id: 'r', parameter: 'pH', value: 7, unit: '')]);
      app.settings.requireApproval = true;
      expect(app.needsApproval(s), isTrue);
      expect(app.approveSample(s), 1);
      expect(app.needsApproval(s), isFalse);
      expect(s.status, SampleStatus.reviewed);
      expect(s.results.single.approvedBy, isNotEmpty);
      s.status = SampleStatus.reported;
      expect(s.reportedAt, isNotNull);
      expect(s.turnaroundDays, closeTo(4, 0.1));
      s.status = SampleStatus.received;
      expect(s.reportedAt, isNull);
    });

    test('analytics count samples per month', () {
      final a = Analytics(app, months: 12);
      expect(a.samplesPerMonth().length, 12);
      final thisMonth = app.samples.where((s) {
        final d = s.receivedAt ?? s.collectedAt;
        return d.year == DateTime.now().year && d.month == DateTime.now().month;
      }).length;
      expect(a.samplesPerMonth().last, thisMonth.toDouble());
    });

    test('GeoJSON and KML exports', () {
      final pts = app.samples.where((s) => s.lat != null).toList();
      expect(pts, isNotEmpty);
      final g = jsonDecode(geoJson(app, pts)) as Map<String, dynamic>;
      expect(g['type'], 'FeatureCollection');
      final f = (g['features'] as List).first as Map<String, dynamic>;
      expect((f['geometry'] as Map)['coordinates'], [pts.first.lon, pts.first.lat]);
      final k = kml(app, pts);
      expect('<Placemark>'.allMatches(k).length, pts.length);
      expect(k, endsWith('</kml>\n'));
    });

    test('quotation and invoice export to Word', () {
      final q = BusinessDocs.word(app, request: app.requests.first);
      final i = BusinessDocs.word(app, invoice: app.invoices.first);
      for (final bytes in [q, i]) {
        final z = ZipDecoder().decodeBytes(bytes);
        final doc = utf8.decode(z.files.firstWhere((f) => f.name == 'word/document.xml').content as List<int>);
        expect('<w:tbl>'.allMatches(doc).length, '</w:tbl>'.allMatches(doc).length);
        expect(RegExp(r'&(?!amp;|lt;|gt;|quot;|apos;)').hasMatch(doc), isFalse);
      }
      Directory('test_output').createSync(recursive: true);
      File('test_output/quotation.docx').writeAsBytesSync(q);
      File('test_output/invoice.docx').writeAsBytesSync(i);
    });
  });
}
