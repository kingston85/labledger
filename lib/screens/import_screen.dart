import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/importer.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';

/// Paste or open a CSV of results and merge it into samples.
class ImportScreen extends StatefulWidget {
  final String? project;
  const ImportScreen({super.key, this.project});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _text = TextEditingController();
  late final _project = TextEditingController(text: widget.project ?? '');
  Matrix _matrix = Matrix.surfaceWater;
  bool _overwrite = true;
  ImportParse? _parse;

  void _reparse() {
    final app = AppScope.read(context);
    setState(() => _parse = _text.text.trim().isEmpty ? null : parseResults(_text.text, knownCodes: app.samples.map((s) => s.code).toSet()));
  }

  Future<void> _open() async {
    try {
      final f = await openFile(acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV / text', extensions: ['csv', 'txt', 'tsv'], mimeTypes: ['text/csv', 'text/plain', 'text/comma-separated-values', 'application/octet-stream']),
      ]);
      if (f == null) return;
      _text.text = await f.readAsString();
      _reparse();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
    }
  }

  Sample? _find(AppState app, String code) {
    final k = code.trim().toLowerCase();
    for (final s in app.samples) {
      if (s.code.trim().toLowerCase() == k) return s;
    }
    return null;
  }

  void _apply() {
    final app = AppScope.read(context);
    final p = _parse;
    if (p == null || p.rows.isEmpty) return;
    var added = 0, updated = 0, created = 0;
    app.update(() {
      for (final code in p.codes) {
        var s = _find(app, code);
        if (s == null) {
          final m = matrixFromCode(code) ?? _matrix;
          s = Sample(
            id: newId(),
            code: code,
            project: _project.text.trim(),
            matrix: m,
            isControl: codeLooksControl(code),
            status: SampleStatus.inAnalysis,
            receivedAt: DateTime.now(),
            limitSetId: m.isSolid ? null : app.settings.defaultLimitSetId,
          );
          app.samples.insert(0, s);
          created++;
        }
        for (final r in p.rows.where((r) => r.code == code)) {
          var unit = r.unit;
          if (s.matrix.isSolid && unit == 'ppm') unit = 'mg/kg';
          if (s.matrix.isSolid && unit == 'mg/L') unit = 'mg/kg';
          final existing = s.results.where((x) => paramKey(x.parameter) == paramKey(r.parameter)).firstOrNull;
          if (existing != null && !_overwrite) continue;
          final res = existing ?? Result(id: newId(), parameter: r.parameter);
          res
            ..value = r.value.belowLod ? null : r.value.value
            ..belowLod = r.value.belowLod
            ..lod = r.value.belowLod ? r.value.lod : res.lod
            ..replicates = r.value.replicates
            ..unit = unit
            ..analyst = res.analyst.isEmpty ? app.settings.analyst : res.analyst
            ..source = 'import';
          if (res.method.isEmpty) res.method = defaultMethods[r.parameter] ?? '';
          if (existing == null) {
            s.results.add(res);
            added++;
          } else {
            updated++;
          }
        }
        if (s.status.index < SampleStatus.inAnalysis.index) s.status = SampleStatus.inAnalysis;
      }
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Imported: $added new results, $updated updated${created > 0 ? ', $created new samples' : ''}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final p = _parse;
    final newCodes = p == null ? <String>[] : p.codes.where((code) => _find(app, code) == null).toList();
    final unknownParams = p == null ? <String>{} : p.rows.where((r) => !r.known).map((r) => r.rawParameter).toSet();
    return Scaffold(
      appBar: AppBar(title: const Text('Import results'), actions: [
        TextButton(onPressed: p == null || p.rows.isEmpty ? null : _apply, child: const Text('Import')),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Text('Paste a table from Excel, a report or an instrument export, or open a CSV file. LabLedger recognises three layouts:',
              style: LBText.body(c.inkDim, size: 13)),
          const SizedBox(height: 8),
          for (final l in const [
            'Report table: parameters down, sample codes across (a "Standard" column is ignored).',
            'Spreadsheet: sample codes down, parameters across.',
            'Instrument export: columns Sample, Parameter, Value (and optional Unit).',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('•  $l', style: LBText.body(c.ink, size: 12.5)),
            ),
          const SizedBox(height: 6),
          Text('Units in brackets like "Iron (mg/L)" are read; "<0.001" is stored as not detected; "2.05 2.08 2.07" is stored as a triplicate mean.',
              style: LBText.body(c.inkDim, size: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _open, icon: const Icon(Icons.folder_open_rounded), label: const Text('Open CSV file'))),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _text.clear();
                  _reparse();
                },
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            minLines: 6,
            maxLines: 14,
            onChanged: (_) => _reparse(),
            style: LBText.reading(11.5, c.ink),
            decoration: const InputDecoration(
              hintText: 'Parameter\tKR-SW-001\tKR-SW-002\nIron (mg/L)\t2.77\t2.20\nLead (ppm)\t0.005\t<0.001',
              alignLabelWithHint: true,
            ),
          ),
          if (p != null) ...[
            const SectionHeader('Preview'),
            LBCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.layout, style: LBText.body(c.ink, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${p.rows.length} results for ${p.codes.length} samples', style: LBText.body(c.inkDim, size: 12.5)),
                for (final w in p.warnings) Text(w, style: LBText.body(c.fair, size: 12.5)),
                if (unknownParams.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Not in the parameter list (kept as written, no limit check): ${unknownParams.take(8).join(', ')}',
                        style: LBText.body(c.fair, size: 12)),
                  ),
              ]),
            ),
            if (newCodes.isNotEmpty) ...[
              const SizedBox(height: 10),
              LBCard(
                borderColor: c.accent.withOpacity(0.5),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${newCodes.length} new sample${newCodes.length == 1 ? '' : 's'} will be created: ${newCodes.take(10).join(', ')}${newCodes.length > 10 ? '…' : ''}',
                      style: LBText.body(c.ink, size: 13)),
                  const SizedBox(height: 10),
                  TextField(controller: _project, decoration: const InputDecoration(labelText: 'Project for new samples', isDense: true)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<Matrix>(
                    value: _matrix,
                    decoration: const InputDecoration(labelText: 'Matrix (when the code doesn\'t say, e.g. -SW-, -SL-)', isDense: true),
                    items: [for (final m in Matrix.values) DropdownMenuItem(value: m, child: Text(m.label))],
                    onChanged: (m) => setState(() => _matrix = m ?? _matrix),
                  ),
                ]),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _overwrite,
              onChanged: (v) => setState(() => _overwrite = v),
              title: const Text('Replace existing results for the same parameter'),
            ),
            if (p.rows.isNotEmpty)
              LBCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final r in p.rows.take(40))
                    ListTile(
                      dense: true,
                      title: Text('${r.code} · ${r.parameter}', style: LBText.body(r.known ? c.ink : c.fair, size: 13, weight: FontWeight.w600)),
                      trailing: Text(
                        r.value.belowLod
                            ? '< ${r.value.lod == null ? 'LOD' : fmtValue(r.value.lod!)} ${r.unit}'
                            : '${fmtValue(r.value.value!)} ${r.unit}${r.value.replicates.length > 1 ? ' (n=${r.value.replicates.length})' : ''}',
                        style: LBText.reading(12.5, c.ink),
                      ),
                    ),
                  if (p.rows.length > 40) Padding(padding: const EdgeInsets.all(8), child: Text('…and ${p.rows.length - 40} more', style: LBText.body(c.inkDim, size: 12))),
                ]),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: p.rows.isEmpty ? null : _apply,
              icon: const Icon(Icons.download_done_rounded),
              label: Text('Import ${p.rows.length} results'),
            ),
          ],
        ],
      ),
    );
  }
}
