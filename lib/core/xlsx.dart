// Minimal Excel (.xlsx) writer: several sheets of text and numbers with a
// bold, shaded header row, frozen header, column widths and auto-filter.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

String _x(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String colName(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

class XlsxSheet {
  final String name;
  final List<String> header;
  final List<List<Object?>> rows;
  XlsxSheet(String name, this.header, this.rows) : name = _sheetName(name);

  static String _sheetName(String n) {
    final s = n.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
    return s.isEmpty ? 'Sheet' : (s.length > 31 ? s.substring(0, 31) : s);
  }
}

class XlsxBuilder {
  final List<XlsxSheet> sheets = [];

  void add(String name, List<String> header, List<List<Object?>> rows) => sheets.add(XlsxSheet(name, header, rows));

  String _cell(String ref, Object? v, {int style = 0}) {
    final st = style == 0 ? '' : ' s="$style"';
    if (v == null) return '<c r="$ref"$st/>';
    if (v is num && v.isFinite) return '<c r="$ref"$st><v>$v</v></c>';
    if (v is bool) return '<c r="$ref" t="b"$st><v>${v ? 1 : 0}</v></c>';
    if (v is DateTime) {
      // Excel serial date (1900 system).
      final serial = v.difference(DateTime(1899, 12, 30)).inSeconds / 86400.0;
      return '<c r="$ref" s="${v.hour == 0 && v.minute == 0 ? 2 : 3}"><v>$serial</v></c>';
    }
    return '<c r="$ref" t="inlineStr"$st><is><t xml:space="preserve">${_x(v.toString())}</t></is></c>';
  }

  String _sheetXml(XlsxSheet sh) {
    final cols = sh.header.length;
    final widths = List<double>.generate(cols, (i) => sh.header[i].length + 2.0);
    for (final r in sh.rows.take(500)) {
      for (var i = 0; i < r.length && i < cols; i++) {
        final v = r[i];
        final len = v is DateTime ? 16.0 : (v?.toString().length ?? 0).toDouble();
        if (len + 2 > widths[i]) widths[i] = len + 2;
      }
    }
    final b = StringBuffer('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
        '<sheetFormatPr defaultRowHeight="15"/>');
    if (cols > 0) {
      b.write('<cols>');
      for (var i = 0; i < cols; i++) {
        final w = widths[i] > 60 ? 60 : widths[i];
        b.write('<col min="${i + 1}" max="${i + 1}" width="${w.toStringAsFixed(1)}" customWidth="1"/>');
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    b.write('<row r="1">');
    for (var i = 0; i < cols; i++) {
      b.write(_cell('${colName(i)}1', sh.header[i], style: 1));
    }
    b.write('</row>');
    for (var r = 0; r < sh.rows.length; r++) {
      b.write('<row r="${r + 2}">');
      final row = sh.rows[r];
      for (var i = 0; i < row.length; i++) {
        b.write(_cell('${colName(i)}${r + 2}', row[i]));
      }
      b.write('</row>');
    }
    b.write('</sheetData>');
    if (cols > 0) b.write('<autoFilter ref="A1:${colName(cols - 1)}${sh.rows.length + 1}"/>');
    b.write('<pageMargins left="0.5" right="0.5" top="0.75" bottom="0.75" header="0.3" footer="0.3"/></worksheet>');
    return b.toString();
  }

  Uint8List build() {
    if (sheets.isEmpty) add('Sheet1', const [], const []);
    final a = Archive();
    void put(String name, String content) {
      final bytes = utf8.encode(content);
      a.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    put('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${[for (var i = 0; i < sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '</Types>');
    put('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        '</Relationships>');
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    put('docProps/core.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:creator>LabLedger</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">${now}Z</dcterms:created></cp:coreProperties>');
    put('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_x(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets>'
        '<definedNames>${[for (var i = 0; i < sheets.length; i++) if (sheets[i].header.isNotEmpty) '<definedName name="_xlnm._FilterDatabase" localSheetId="$i" hidden="1">\'${_x(sheets[i].name).replaceAll("'", "''")}\'!\$A\$1:\$${colName(sheets[i].header.length - 1)}\$${sheets[i].rows.length + 1}</definedName>'].join()}</definedNames>'
        '</workbook>');
    put('xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
        '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>');
    put('xl/styles.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<numFmts count="2"><numFmt numFmtId="164" formatCode="dd/mm/yyyy"/><numFmt numFmtId="165" formatCode="dd/mm/yyyy hh:mm"/></numFmts>'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
        '<fill><patternFill patternType="solid"><fgColor rgb="FF2F5BD3"/><bgColor indexed="64"/></patternFill></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="4">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
        '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
        '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
        '</cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>');
    for (var i = 0; i < sheets.length; i++) {
      put('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
    }
    return Uint8List.fromList(ZipEncoder().encode(a)!);
  }
}
