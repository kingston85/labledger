// Bulk import of results from CSV / pasted spreadsheet tables. Understands
// three layouts:
//   long:         sample, parameter, value[, unit]   (instrument exports)
//   parameter-rows: Parameter | S1 | S2 | … [| Standard]  (report tables)
//   sample-rows:  Sample | pH | Iron (mg/L) | …          (spreadsheets)

import '../data/models.dart';
import 'guidelines.dart';

class ImportRow {
  final String code;
  final String parameter; // canonical where recognised
  final String rawParameter;
  final ParsedValue value;
  final String unit;
  final bool known; // parameter recognised
  const ImportRow(this.code, this.parameter, this.rawParameter, this.value, this.unit, this.known);
}

class ImportParse {
  final String layout;
  final List<ImportRow> rows;
  final List<String> warnings;
  const ImportParse(this.layout, this.rows, this.warnings);
  Set<String> get codes => rows.map((r) => r.code).toSet();
}

/// Splits text into rows/cells, auto-detecting tab, semicolon or comma.
List<List<String>> parseDelimited(String text) {
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final first = lines.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  String delim = ',';
  if ('\t'.allMatches(first).length >= 1) {
    delim = '\t';
  } else if (';'.allMatches(first).length > ','.allMatches(first).length) {
    delim = ';';
  }
  final out = <List<String>>[];
  // Quote-aware splitter that also handles quoted newlines.
  final buf = StringBuffer();
  var row = <String>[];
  var inQ = false;
  final s = lines.join('\n');
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (inQ) {
      if (ch == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQ = false;
        }
      } else {
        buf.write(ch);
      }
    } else if (ch == '"') {
      inQ = true;
    } else if (ch == delim) {
      row.add(buf.toString().trim());
      buf.clear();
    } else if (ch == '\n') {
      row.add(buf.toString().trim());
      buf.clear();
      if (row.any((c) => c.isNotEmpty)) out.add(row);
      row = <String>[];
    } else {
      buf.write(ch);
    }
  }
  row.add(buf.toString().trim());
  if (row.any((c) => c.isNotEmpty)) out.add(row);
  return out;
}

final _unitInName = RegExp(r'^(.*?)\s*[\(\[]\s*(mg/l|µg/l|ug/l|mg/kg|µg/g|ug/g|ppm|ppb|ppt|psu|µs/cm|us/cm|ms/cm|ntu|mv|°c|deg c|cfu/100 ?ml|%)\s*[\)\]]\s*$', caseSensitive: false);

(String, String?) splitParamUnit(String raw) {
  final m = _unitInName.firstMatch(raw.trim());
  if (m == null) return (raw.trim(), null);
  var u = m.group(2)!.trim();
  final l = u.toLowerCase();
  if (l == 'mg/l') u = 'mg/L';
  if (l == 'µg/l' || l == 'ug/l') u = 'µg/L';
  if (l == 'µs/cm' || l == 'us/cm') u = 'µS/cm';
  if (l == 'ntu') u = 'NTU';
  if (l == 'mv') u = 'mV';
  if (l == 'ppm') u = 'ppm';
  if (l == 'ppb') u = 'ppb';
  if (l == 'mg/kg') u = 'mg/kg';
  if (l == '°c' || l == 'deg c') u = '°C';
  return (m.group(1)!.trim(), u);
}

bool _isKnown(String p) => commonParameters.keys.any((k) => paramKey(k) == paramKey(p));

ImportRow? _row(String code, String rawParam, String cell, {String? unitOverride}) {
  final c = code.trim();
  if (c.isEmpty || rawParam.trim().isEmpty) return null;
  final t = cell.trim();
  if (t.isEmpty || const {'-', '–', '—', 'na', 'n/a', 'nt', 'not tested'}.contains(t.toLowerCase())) return null;
  final pv = parseResultText(t);
  if (pv.isEmpty) return null;
  final (name, unit) = splitParamUnit(rawParam);
  final canon = canonicalParameter(name);
  final u = unitOverride?.trim().isNotEmpty == true ? unitOverride!.trim() : (unit ?? commonParameters[canon] ?? 'mg/L');
  return ImportRow(c, canon, rawParam.trim(), pv, u, _isKnown(name));
}

bool _skipCol(String h) => RegExp(r'standard|guideline|limit|^unit|^units|^method|who|epa|\bmax\b|\bmin\b', caseSensitive: false).hasMatch(h);

ImportParse parseResults(String text, {Set<String> knownCodes = const {}}) {
  final rows = parseDelimited(text);
  final warnings = <String>[];
  if (rows.length < 2) return const ImportParse('empty', [], ['Paste at least a header row and one data row.']);
  final header = rows.first;
  final hl = header.map((h) => h.toLowerCase()).toList();
  int find(RegExp r) => hl.indexWhere((h) => r.hasMatch(h));
  final known = {for (final k in knownCodes) k.toLowerCase()};
  bool isCode(String s) => known.contains(s.trim().toLowerCase()) || RegExp(r'^[A-Za-z]{1,4}(-[A-Za-z]{1,3})*-\d{2,4}$').hasMatch(s.trim());

  final sampleCol = find(RegExp(r'sample|^code|station|^id$|site code'));
  final paramCol = find(RegExp(r'param|analyte|determinand|element|^test'));
  final valueCol = find(RegExp(r'^value|result|conc|reading|mean'));
  final unitCol = find(RegExp(r'^units?$'));
  final out = <ImportRow>[];

  // Long format.
  if (sampleCol >= 0 && paramCol >= 0 && valueCol >= 0) {
    for (final r in rows.skip(1)) {
      String at(int i) => i >= 0 && i < r.length ? r[i] : '';
      final row = _row(at(sampleCol), at(paramCol), at(valueCol), unitOverride: unitCol >= 0 ? at(unitCol) : null);
      if (row != null) out.add(row);
    }
    return ImportParse('One result per row (sample, parameter, value)', out, warnings);
  }

  // Parameter rows, samples across.
  final headerCodes = header.skip(1).where(isCode).length;
  if (paramCol == 0 || headerCodes >= (header.length - 1) / 2) {
    final cols = <int>[];
    for (var i = 1; i < header.length; i++) {
      if (header[i].trim().isEmpty || _skipCol(header[i])) continue;
      cols.add(i);
    }
    final unitIdx = hl.indexWhere((h) => h == 'unit' || h == 'units');
    for (final r in rows.skip(1)) {
      if (r.isEmpty || r[0].trim().isEmpty) continue;
      for (final i in cols) {
        if (i >= r.length) continue;
        final row = _row(header[i].replaceAll(RegExp(r'\s*\(control\)\s*', caseSensitive: false), ''), r[0], r[i],
            unitOverride: unitIdx >= 0 && unitIdx < r.length ? r[unitIdx] : null);
        if (row != null) out.add(row);
      }
    }
    return ImportParse('Parameters down, samples across (report table)', out, warnings);
  }

  // Sample rows, parameters across.
  final firstColCodes = rows.skip(1).where((r) => r.isNotEmpty && isCode(r[0])).length;
  if (sampleCol == 0 || firstColCodes >= (rows.length - 1) / 2) {
    for (final r in rows.skip(1)) {
      if (r.isEmpty || r[0].trim().isEmpty) continue;
      for (var i = 1; i < header.length && i < r.length; i++) {
        if (header[i].trim().isEmpty || _skipCol(header[i]) || RegExp(r'date|time|lat|lon|location|site|matrix|remark|note|easting|northing', caseSensitive: false).hasMatch(header[i])) continue;
        final row = _row(r[0], header[i], r[i]);
        if (row != null) out.add(row);
      }
    }
    return ImportParse('Samples down, parameters across', out, warnings);
  }

  return const ImportParse('unknown', [], [
    'Could not recognise the layout. Use a header row with either sample codes across the top, '
        'a "Sample" column with parameters across, or columns Sample / Parameter / Value.'
  ]);
}

/// Guesses the matrix from an EPA-style code (KR-SW-001 → surface water).
Matrix? matrixFromCode(String code) {
  final c = '-${code.toUpperCase()}-';
  if (c.contains('-SW-')) return Matrix.surfaceWater;
  if (c.contains('-GW-')) return Matrix.groundwater;
  if (c.contains('-DW-')) return Matrix.drinkingWater;
  if (c.contains('-WW-')) return Matrix.wastewater;
  if (c.contains('-SL-')) return Matrix.soil;
  if (c.contains('-SD-')) return Matrix.sediment;
  return null;
}
