// Minimal Word (.docx, Office Open XML) writer: headings, paragraphs,
// bullets, shaded tables, page breaks and a page-number footer. Output
// opens in Microsoft Word, LibreOffice, Google Docs and WPS.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

const docxMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

String _x(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

class DocxBuilder {
  final bool landscape;
  final String title;
  final String author;
  final String footer;
  final String accent; // hex RRGGBB for headings and table headers
  final StringBuffer _body = StringBuffer();

  DocxBuilder({this.landscape = false, this.title = '', this.author = '', this.footer = '', this.accent = '2F5BD3'});

  String _run(String text, {bool bold = false, bool italic = false, double? size, String? color, String? font}) {
    final props = StringBuffer();
    if (font != null) props.write('<w:rFonts w:ascii="$font" w:hAnsi="$font" w:cs="$font"/>');
    if (bold) props.write('<w:b/>');
    if (italic) props.write('<w:i/>');
    if (color != null) props.write('<w:color w:val="$color"/>');
    if (size != null) props.write('<w:sz w:val="${(size * 2).round()}"/><w:szCs w:val="${(size * 2).round()}"/>');
    // Preserve line breaks inside a run.
    final parts = text.split('\n');
    final t = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) t.write('<w:br/>');
      t.write('<w:t xml:space="preserve">${_x(parts[i])}</w:t>');
    }
    return '<w:r>${props.isEmpty ? '' : '<w:rPr>$props</w:rPr>'}$t</w:r>';
  }

  String _p(String runs, {String? style, String align = 'left', int before = 0, int after = 80, int indent = 0, bool keepNext = false}) {
    final pp = StringBuffer();
    if (style != null) pp.write('<w:pStyle w:val="$style"/>');
    if (keepNext) pp.write('<w:keepNext/>');
    pp.write('<w:spacing w:before="$before" w:after="$after"/>');
    if (indent > 0) pp.write('<w:ind w:left="$indent" w:hanging="220"/>');
    if (align != 'left') pp.write('<w:jc w:val="$align"/>');
    return '<w:p><w:pPr>$pp</w:pPr>$runs</w:p>';
  }

  void titleBlock(String main, {String? kicker, String? sub}) {
    if (kicker != null && kicker.isNotEmpty) _body.write(_p(_run(kicker.toUpperCase(), bold: true, size: 8.5, color: '5A6478'), after: 0));
    _body.write(_p(_run(main, bold: true, size: 20, color: '0E1116'), style: 'Title', after: 40));
    if (sub != null && sub.isNotEmpty) _body.write(_p(_run(sub, size: 10, color: '5A6478'), after: 200));
  }

  void heading(String text, {int level = 1}) {
    _body.write(_p(_run(text, bold: true, size: level == 1 ? 13 : 11, color: accent), style: 'Heading$level', before: level == 1 ? 260 : 180, after: 100, keepNext: true));
  }

  void para(String text, {bool bold = false, bool italic = false, double size = 10, String? color, String align = 'left', int after = 80}) {
    _body.write(_p(_run(text, bold: bold, italic: italic, size: size, color: color), align: align, after: after));
  }

  /// Paragraph from (text, bold) segments.
  void rich(List<(String, bool)> parts, {double size = 10, String? color}) {
    _body.write(_p(parts.map((e) => _run(e.$1, bold: e.$2, size: size, color: color)).join()));
  }

  void bullet(String text, {double size = 10}) {
    _body.write(_p(_run('•\t', size: size, color: accent) + _run(text, size: size), indent: 360, after: 60));
  }

  void note(String text) => para(text, size: 8, color: '5A6478', after: 120);

  void spacer([int twips = 120]) => _body.write(_p('', after: twips));

  void pageBreak() => _body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');

  /// Table with a shaded, repeating header row. [shade] returns a hex fill
  /// (RRGGBB) for a body cell or null. [widths] are relative column weights.
  void table(List<String> headers, List<List<String>> rows,
      {String? Function(int row, int col)? shade, List<double>? widths, double size = 8.5, Set<int> center = const {}, Set<int> boldCols = const {}}) {
    final total = landscape ? 14800 : 9900; // usable width in twips
    final w = widths ?? List.filled(headers.length, 1.0);
    final sum = w.fold<double>(0, (a, b) => a + b);
    final cols = [for (final x in w) (x / sum * total).round()];
    final b = StringBuffer('<w:tbl><w:tblPr><w:tblW w:w="$total" w:type="dxa"/>'
        '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="C9CFD9"/><w:left w:val="single" w:sz="4" w:color="C9CFD9"/>'
        '<w:bottom w:val="single" w:sz="4" w:color="C9CFD9"/><w:right w:val="single" w:sz="4" w:color="C9CFD9"/>'
        '<w:insideH w:val="single" w:sz="4" w:color="D5DAE2"/><w:insideV w:val="single" w:sz="4" w:color="E3E7ED"/></w:tblBorders>'
        '<w:tblLayout w:type="fixed"/><w:tblCellMar><w:left w:w="70" w:type="dxa"/><w:right w:w="70" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>');
    for (final c in cols) {
      b.write('<w:gridCol w:w="$c"/>');
    }
    b.write('</w:tblGrid>');
    String cell(String text, int c, {String? fill, bool bold = false, bool header = false}) {
      final align = center.contains(c) && !(header && c == 0) ? 'center' : 'left';
      return '<w:tc><w:tcPr><w:tcW w:w="${cols[c]}" w:type="dxa"/>${fill == null ? '' : '<w:shd w:val="clear" w:color="auto" w:fill="$fill"/>'}<w:vAlign w:val="center"/></w:tcPr>'
          '${_p(_run(text, bold: bold, size: size, color: header ? 'FFFFFF' : '0E1116'), align: align, after: 0)}</w:tc>';
    }

    b.write('<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>');
    for (var c = 0; c < headers.length; c++) {
      b.write(cell(headers[c], c, fill: accent, bold: true, header: true));
    }
    b.write('</w:tr>');
    for (var r = 0; r < rows.length; r++) {
      b.write('<w:tr><w:trPr><w:cantSplit/></w:trPr>');
      for (var c = 0; c < headers.length; c++) {
        final text = c < rows[r].length ? rows[r][c] : '';
        b.write(cell(text, c, fill: shade?.call(r, c) ?? (r.isOdd ? 'F6F8FA' : null), bold: boldCols.contains(c)));
      }
      b.write('</w:tr>');
    }
    b.write('</w:tbl>');
    _body.write(b);
    spacer(60);
  }

  /// Signature lines (label under a rule).
  void signatures(List<(String, String)> boxes) {
    final cols = boxes.length;
    final total = landscape ? 14800 : 9900;
    final w = (total / cols).round();
    final b = StringBuffer('<w:tbl><w:tblPr><w:tblW w:w="$total" w:type="dxa"/><w:tblLayout w:type="fixed"/></w:tblPr><w:tblGrid>');
    for (var i = 0; i < cols; i++) {
      b.write('<w:gridCol w:w="$w"/>');
    }
    b.write('</w:tblGrid><w:tr><w:trPr><w:trHeight w:val="700"/></w:trPr>');
    for (final (label, name) in boxes) {
      b.write('<w:tc><w:tcPr><w:tcW w:w="$w" w:type="dxa"/>'
          '<w:tcMar><w:right w:w="300" w:type="dxa"/></w:tcMar><w:vAlign w:val="bottom"/></w:tcPr>'
          '${_p(_run(name, size: 10), after: 0)}'
          '<w:p><w:pPr><w:pBdr><w:top w:val="single" w:sz="6" w:space="1" w:color="0E1116"/></w:pBdr><w:spacing w:after="0"/></w:pPr>${_run(label, size: 8, color: '5A6478')}</w:p></w:tc>');
    }
    b.write('</w:tr></w:tbl>');
    spacer(400);
    _body.write(b);
  }

  Uint8List bytes() {
    final pgW = landscape ? 16838 : 11906, pgH = landscape ? 11906 : 16838;
    final document = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>$_body'
        '<w:sectPr><w:footerReference w:type="default" r:id="rIdFooter"/>'
        '<w:pgSz w:w="$pgW" w:h="$pgH"${landscape ? ' w:orient="landscape"' : ''}/>'
        '<w:pgMar w:top="900" w:right="1000" w:bottom="900" w:left="1000" w:header="500" w:footer="500" w:gutter="0"/></w:sectPr>'
        '</w:body></w:document>';
    final footerXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:pPr><w:tabs><w:tab w:val="right" w:pos="${landscape ? 14800 : 9900}"/></w:tabs></w:pPr>'
        '${_run(footer, size: 7.5, color: '5A6478')}<w:r><w:rPr><w:sz w:val="15"/><w:color w:val="5A6478"/></w:rPr><w:tab/><w:t xml:space="preserve">Page </w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="15"/><w:color w:val="5A6478"/></w:rPr><w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:rPr><w:sz w:val="15"/><w:color w:val="5A6478"/></w:rPr><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
        '<w:r><w:rPr><w:sz w:val="15"/><w:color w:val="5A6478"/></w:rPr><w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r><w:rPr><w:sz w:val="15"/><w:color w:val="5A6478"/></w:rPr><w:t>1</w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="15"/><w:color w:val="5A6478"/></w:rPr><w:fldChar w:fldCharType="end"/></w:r></w:p></w:ftr>';
    const styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri" w:eastAsia="Calibri"/>'
        '<w:sz w:val="20"/><w:szCs w:val="20"/><w:lang w:val="en-GB"/></w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr><w:spacing w:after="80" w:line="259" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
        '<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:qFormat/><w:rPr><w:b/><w:sz w:val="40"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:keepNext/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="26"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
        '<w:pPr><w:keepNext/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:sz w:val="22"/></w:rPr></w:style>'
        '</w:styles>';
    const contentTypes = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '</Types>';
    const rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        '</Relationships>';
    const docRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '<Relationship Id="rIdFooter" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>'
        '</Relationships>';
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    final core = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_x(title)}</dc:title><dc:creator>${_x(author)}</dc:creator>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">${now}Z</dcterms:created></cp:coreProperties>';

    final a = Archive();
    void add(String name, String content) {
      final data = utf8.encode(content);
      a.addFile(ArchiveFile(name, data.length, data));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', document);
    add('word/styles.xml', styles);
    add('word/footer1.xml', footerXml);
    add('word/_rels/document.xml.rels', docRels);
    add('docProps/core.xml', core);
    return Uint8List.fromList(ZipEncoder().encode(a)!);
  }
}
