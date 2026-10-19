// Quotations, invoices and receipts as PDF and Word.

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_state.dart';
import '../data/models.dart';
import 'docx.dart';
import 'lab_docs.dart';

const _accent = PdfColor.fromInt(0xFF2F5BD3);
const _ink = PdfColor.fromInt(0xFF0E1116);
const _dim = PdfColor.fromInt(0xFF5A6478);
const _line = PdfColor.fromInt(0xFFD5DAE2);
const _panel = PdfColor.fromInt(0xFFF4F6F9);
const _good = PdfColor.fromInt(0xFF0F8A55);
const _bad = PdfColor.fromInt(0xFFC62828);

enum DocKind { quotation, invoice }

String _qty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

class BusinessDocs {
  BusinessDocs._();

  static Future<Uint8List> pdf(AppState app, {LabRequest? request, Invoice? invoice}) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final st = app.settings;
    final cur = st.currency;
    final isInv = invoice != null;
    final Priced doc = isInv ? (invoice! as Priced) : (request! as Priced);
    final client = app.client(isInv ? invoice!.clientId : request!.clientId);
    final number = isInv ? invoice!.number : request!.number;
    final title = isInv ? 'INVOICE' : 'QUOTATION';
    final date = isInv ? invoice!.date : request!.date;
    final d = pw.Document(title: '$title $number', author: st.labName, creator: 'LabLedger');

    pw.Widget kv(String k, String v, {bool strong = false, PdfColor? color}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(k, style: pw.TextStyle(fontSize: 9.5, color: _dim, font: strong ? bold : regular))),
            pw.Text(v, style: pw.TextStyle(fontSize: strong ? 12 : 9.5, font: strong ? bold : regular, color: color ?? _ink)),
          ]),
        );

    d.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (ctx) => pw.Row(children: [
        pw.Expanded(child: pw.Text('${st.labName} · $number', style: const pw.TextStyle(fontSize: 7.5, color: _dim))),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _dim)),
      ]),
      build: (ctx) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (pdfLogo(app, height: 42) != null) ...[pdfLogo(app, height: 42)!, pw.SizedBox(height: 6)],
              pw.Text(st.labName, style: pw.TextStyle(font: bold, fontSize: 14)),
              if (st.labAddress.isNotEmpty) pw.Text(st.labAddress, style: const pw.TextStyle(fontSize: 9, color: _dim)),
              if (st.labPhone.isNotEmpty || st.labEmail.isNotEmpty)
                pw.Text([st.labPhone, st.labEmail].where((x) => x.isNotEmpty).join(' · '), style: const pw.TextStyle(fontSize: 9, color: _dim)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 24, color: _accent, letterSpacing: 2)),
            pw.Text(number, style: pw.TextStyle(font: bold, fontSize: 11)),
          ]),
        ]),
        pw.SizedBox(height: 18),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: _panel, borderRadius: pw.BorderRadius.all(pw.Radius.circular(6))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(isInv ? 'BILL TO' : 'PREPARED FOR', style: pw.TextStyle(font: bold, fontSize: 8, color: _dim, letterSpacing: 1)),
                pw.SizedBox(height: 3),
                pw.Text(client?.name ?? '—', style: pw.TextStyle(font: bold, fontSize: 11)),
                if ((client?.contact ?? '').isNotEmpty) pw.Text('Attn: ${client!.contact}', style: const pw.TextStyle(fontSize: 9)),
                if ((client?.address ?? '').isNotEmpty) pw.Text(client!.address, style: const pw.TextStyle(fontSize: 9)),
                if ((client?.phone ?? '').isNotEmpty || (client?.email ?? '').isNotEmpty)
                  pw.Text([client!.phone, client.email].where((x) => x.isNotEmpty).join(' · '), style: const pw.TextStyle(fontSize: 9)),
                if ((client?.taxId ?? '').isNotEmpty) pw.Text('TIN: ${client!.taxId}', style: const pw.TextStyle(fontSize: 9)),
              ]),
            ),
          ),
          pw.SizedBox(width: 16),
          pw.SizedBox(
            width: 200,
            child: pw.Column(children: [
              kv('Date', shortDate(date)),
              if (isInv) kv('Due date', shortDate(invoice!.dueDate)),
              if (!isInv && request!.dueDate != null) kv('Results due', shortDate(request.dueDate!)),
              if (!isInv) kv('Valid for', '30 days'),
              if (isInv && invoice!.requestId != null) kv('Request', app.request(invoice!.requestId)?.number ?? ''),
              if (!isInv && request!.project.isNotEmpty) kv('Project', request.project),
              kv('Currency', cur),
            ]),
          ),
        ]),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Description', 'Qty', 'Unit price', 'Amount'],
          data: [
            for (var i = 0; i < doc.lines.length; i++)
              ['${i + 1}', doc.lines[i].description, _qty(doc.lines[i].qty), money(doc.lines[i].unitPrice, cur), money(doc.lines[i].total, cur)]
          ],
          headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _accent),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignments: {0: pw.Alignment.center, 2: pw.Alignment.center, 3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight},
          columnWidths: {0: const pw.FixedColumnWidth(22), 1: const pw.FlexColumnWidth(5), 2: const pw.FixedColumnWidth(36), 3: const pw.FixedColumnWidth(72), 4: const pw.FixedColumnWidth(80)},
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5), bottom: pw.BorderSide(color: _line, width: 0.5)),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        ),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          pw.Spacer(),
          pw.SizedBox(
            width: 230,
            child: pw.Column(children: [
              kv('Subtotal', money(doc.subtotal, cur)),
              if (doc.discountPct > 0) kv('Discount (${_qty(doc.discountPct)}%)', '-${money(doc.discount, cur)}'),
              if (doc.taxPct > 0) kv('Tax / GST (${_qty(doc.taxPct)}%)', money(doc.tax, cur)),
              pw.Divider(color: _line),
              kv('TOTAL', money(doc.total, cur), strong: true),
              if (isInv && invoice!.paid > 0) ...[
                kv('Paid', '-${money(invoice!.paid, cur)}', color: _good),
                kv('BALANCE DUE', money(invoice!.balance, cur), strong: true, color: invoice!.balance > 0 ? _bad : _good),
              ],
            ]),
          ),
        ]),
        if (isInv && invoice!.payments.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text('PAYMENTS RECEIVED', style: pw.TextStyle(font: bold, fontSize: 8, color: _dim, letterSpacing: 1)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Receipt', 'Method', 'Reference', 'Amount'],
            data: [for (final p in invoice!.payments) [shortDate(p.date), p.receiptNo, p.method, p.reference, money(p.amount, cur)]],
            headerStyle: pw.TextStyle(font: bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: _panel),
            cellAlignments: {4: pw.Alignment.centerRight},
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
          ),
        ],
        pw.SizedBox(height: 18),
        if ((isInv ? invoice!.notes : request!.notes).isNotEmpty && (isInv ? invoice!.notes : request!.notes) != 'Demo item')
          pw.Text('Notes: ${isInv ? invoice!.notes : request!.notes}', style: const pw.TextStyle(fontSize: 9)),
        if (isInv && st.bankDetails.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('PAYMENT DETAILS', style: pw.TextStyle(font: bold, fontSize: 8, color: _dim, letterSpacing: 1)),
          pw.Text(st.bankDetails, style: const pw.TextStyle(fontSize: 9)),
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          isInv
              ? 'Payment is due within ${invoice!.dueDate.difference(invoice!.date).inDays} days. Please quote $number with your payment.'
              : 'This quotation is valid for 30 days. Results are reported within the stated turnaround from receipt of samples at the laboratory.',
          style: const pw.TextStyle(fontSize: 8.5, color: _dim),
        ),
        pw.SizedBox(height: 40),
        pw.Row(children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(height: 0.8, width: 180, color: _ink),
              pw.SizedBox(height: 3),
              pw.Text('Authorised signature', style: const pw.TextStyle(fontSize: 8, color: _dim)),
            ]),
          ),
          if (!isInv)
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(height: 0.8, width: 180, color: _ink),
                pw.SizedBox(height: 3),
                pw.Text('Accepted by client (name, signature, date)', style: const pw.TextStyle(fontSize: 8, color: _dim)),
              ]),
            ),
        ]),
      ],
    ));
    return d.save();
  }

  /// A5-landscape payment receipt.
  static Future<Uint8List> receipt(AppState app, Invoice inv, Payment p) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
    final st = app.settings;
    final cur = st.currency;
    final client = app.client(inv.clientId);
    final d = pw.Document(title: 'Receipt ${p.receiptNo}', creator: 'LabLedger');
    pw.Widget row(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(children: [
            pw.SizedBox(width: 130, child: pw.Text(k, style: const pw.TextStyle(fontSize: 10, color: _dim))),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 2),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6))),
                child: pw.Text(v, style: const pw.TextStyle(fontSize: 11)),
              ),
            ),
          ]),
        );
    d.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5.landscape,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(st.labName, style: pw.TextStyle(font: bold, fontSize: 12)),
              if (st.labAddress.isNotEmpty) pw.Text(st.labAddress, style: const pw.TextStyle(fontSize: 8.5, color: _dim)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('OFFICIAL RECEIPT', style: pw.TextStyle(font: bold, fontSize: 16, color: _accent, letterSpacing: 1.5)),
            pw.Text(p.receiptNo, style: pw.TextStyle(font: bold, fontSize: 11)),
          ]),
        ]),
        pw.SizedBox(height: 16),
        row('Date', shortDate(p.date)),
        row('Received from', client?.name ?? '—'),
        row('Amount', '${money(p.amount, cur)} (${cur == 'USD' ? 'US dollars' : cur})'),
        row('For', 'Invoice ${inv.number}${inv.requestId == null ? '' : ' · ${app.request(inv.requestId)?.number ?? ''}'}'),
        row('Payment method', '${p.method}${p.reference.isEmpty ? '' : ' · ref ${p.reference}'}'),
        row('Balance remaining', money(inv.balance, cur)),
        pw.Spacer(),
        pw.Row(children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: inv.balance <= 0 ? _good : _accent, width: 2), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
            child: pw.Text(inv.balance <= 0 ? 'PAID IN FULL' : 'PART PAYMENT', style: pw.TextStyle(font: bold, fontSize: 12, color: inv.balance <= 0 ? _good : _accent)),
          ),
          pw.Spacer(),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(height: 0.8, width: 170, color: _ink),
            pw.SizedBox(height: 3),
            pw.Text('Received by (cashier)', style: const pw.TextStyle(fontSize: 8, color: _dim)),
          ]),
        ]),
      ]),
    ));
    return d.save();
  }

  static Uint8List word(AppState app, {LabRequest? request, Invoice? invoice}) {
    final st = app.settings;
    final cur = st.currency;
    final isInv = invoice != null;
    final Priced doc = isInv ? (invoice! as Priced) : (request! as Priced);
    final client = app.client(isInv ? invoice!.clientId : request!.clientId);
    final number = isInv ? invoice!.number : request!.number;
    final d = DocxBuilder(title: '${isInv ? 'Invoice' : 'Quotation'} $number', author: st.labName, footer: '${st.labName} · $number');
    d.titleBlock('${isInv ? 'INVOICE' : 'QUOTATION'} $number', kicker: st.labName, sub: [st.labAddress, st.labPhone, st.labEmail].where((x) => x.isNotEmpty).join(' · '));
    d.table(
      [isInv ? 'Bill to' : 'Prepared for', 'Details'],
      [
        [
          [client?.name ?? '—', if ((client?.contact ?? '').isNotEmpty) 'Attn: ${client!.contact}', if ((client?.address ?? '').isNotEmpty) client!.address, if ((client?.phone ?? '').isNotEmpty) client!.phone]
              .join('\n'),
          [
            'Date: ${shortDate(isInv ? invoice!.date : request!.date)}',
            if (isInv) 'Due: ${shortDate(invoice!.dueDate)}',
            if (!isInv && request!.project.isNotEmpty) 'Project: ${request.project}',
            'Currency: $cur',
          ].join('\n'),
        ]
      ],
      widths: [3, 2],
      size: 9.5,
    );
    d.table(
      ['#', 'Description', 'Qty', 'Unit price', 'Amount'],
      [
        for (var i = 0; i < doc.lines.length; i++) ['${i + 1}', doc.lines[i].description, _qty(doc.lines[i].qty), money(doc.lines[i].unitPrice, cur), money(doc.lines[i].total, cur)],
        ['', 'Subtotal', '', '', money(doc.subtotal, cur)],
        if (doc.discountPct > 0) ['', 'Discount (${_qty(doc.discountPct)}%)', '', '', '-${money(doc.discount, cur)}'],
        if (doc.taxPct > 0) ['', 'Tax / GST (${_qty(doc.taxPct)}%)', '', '', money(doc.tax, cur)],
        ['', 'TOTAL', '', '', money(doc.total, cur)],
        if (isInv && invoice!.paid > 0) ['', 'Paid', '', '', '-${money(invoice!.paid, cur)}'],
        if (isInv && invoice!.paid > 0) ['', 'BALANCE DUE', '', '', money(invoice!.balance, cur)],
      ],
      widths: [0.4, 5, 0.7, 1.3, 1.4],
      center: {0, 2},
      boldCols: const {},
      shade: (r, c) => r >= doc.lines.length ? 'EEF2F8' : null,
    );
    if (isInv && st.bankDetails.isNotEmpty) {
      d.heading('Payment details', level: 2);
      d.para(st.bankDetails);
    }
    d.note(isInv
        ? 'Payment is due within ${invoice!.dueDate.difference(invoice!.date).inDays} days. Please quote $number with your payment.'
        : 'This quotation is valid for 30 days.');
    d.signatures([('Authorised signature', ''), if (!isInv) ('Accepted by client', ''), ('Date', '')]);
    return d.bytes();
  }
}
