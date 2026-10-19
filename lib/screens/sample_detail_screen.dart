import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/docx.dart';
import '../core/report.dart';
import '../core/word_reports.dart';
import '../core/stats.dart';
import '../core/utm.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/share.dart';
import 'bulk_entry.dart';
import 'home_screen.dart';
import 'sample_form_screen.dart';
import 'samples_screen.dart';

class SampleDetailScreen extends StatelessWidget {
  final Sample sample;
  const SampleDetailScreen({super.key, required this.sample});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final s = sample;
    final set = app.limitsFor(s);
    final checks = [for (final r in s.results) checkResult(r, set)];
    final bad = checks.where((k) => k.status == Compliance.exceed || k.status == Compliance.belowMin).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.code),
        actions: [
          IconButton(
            tooltip: 'PDF report',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () async {
              final bytes = await Reports.sampleReport(app, [s]);
              if (context.mounted) {
                await shareBytes(context, '${safeName(s.code)}_report.pdf', bytes, 'application/pdf', subject: 'Lab report ${s.code}');
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleFormScreen(sample: s)));
              } else if (v == 'docx') {
                final bytes = WordReports.samples(app, [s]);
                if (context.mounted) await shareBytes(context, '${safeName(s.code)}_report.docx', bytes, docxMime, subject: 'Lab report ${s.code}');
              } else if (v == 'csv') {
                shareText(context, '${safeName(s.code)}.csv', Reports.resultsCsv(app, [s]), 'text/csv');
              } else if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete sample?'),
                    content: Text('${s.code} and its ${s.results.length} results will be removed.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  app.update(() => app.samples.remove(s));
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit details')),
              PopupMenuItem(value: 'docx', child: Text('Report · Word (.docx)')),
              PopupMenuItem(value: 'csv', child: Text('Export CSV')),
              PopupMenuItem(value: 'delete', child: Text('Delete sample')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showResultForm(context, s),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add result'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 96),
        children: [
          Text(s.site.isEmpty ? s.matrix.label : s.site, style: LBText.title(c.ink, size: 20)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            StatusChip(s.status),
            if (s.isControl) Tag('CONTROL', color: c.good),
            Tag(s.matrix.label, color: c.inkDim),
            if (s.project.isNotEmpty) Tag(s.project, color: c.inkDim),
          ]),
          const SizedBox(height: 14),
          _StatusStepper(sample: s),
          const SizedBox(height: 14),
          LBCard(
            child: Column(
              children: [
                _kv(context, 'Collected', dateTime(s.collectedAt)),
                _kv(context, 'Received', s.receivedAt == null ? '—' : dateTime(s.receivedAt!)),
                _kv(context, 'Collected by', s.collector.isEmpty ? '—' : s.collector),
                _kv(context, 'Preservation', s.preservation.isEmpty ? '—' : s.preservation),
                _kv(context, 'Coordinates',
                    s.lat != null && s.lon != null ? '${s.lat!.toStringAsFixed(5)}, ${s.lon!.toStringAsFixed(5)}' : '—'),
                if (s.lat != null && s.lon != null) _kv(context, 'UTM', toUtm(s.lat!, s.lon!, zone: 29).toString()),
                _kv(context, 'Limits', set?.name ?? 'None'),
                if (s.notes.isNotEmpty) _kv(context, 'Remarks', s.notes),
              ],
            ),
          ),
          SectionHeader(
            'Results (${s.results.length})',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.results.isNotEmpty) Tag(bad > 0 ? '$bad out of limit' : 'All within limits', color: bad > 0 ? c.poor : c.good),
                IconButton(
                  tooltip: 'Enter a parameter panel',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showBulkEntry(context, s),
                  icon: Icon(Icons.playlist_add_rounded, color: c.accent),
                ),
              ],
            ),
          ),
          if (s.results.isEmpty)
            LBCard(
              onTap: () => showBulkEntry(context, s),
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, color: c.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('No results yet. Tap here to enter a whole panel (field readings, mining metals, nutrients), '
                        'use "Add result", or calculate from a calibration curve.',
                        style: LBText.body(c.inkDim, size: 13)),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < s.results.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ResultRow(sample: s, result: s.results[i], check: checks[i]),
              ),
          SectionHeader(
            'Chain of custody',
            trailing: TextButton.icon(
              onPressed: () => _addCustody(context, app, s),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Transfer'),
            ),
          ),
          if (s.custody.isEmpty)
            LBCard(child: Text('No transfers recorded.', style: LBText.body(c.inkDim, size: 13)))
          else
            LBCard(
              child: Column(
                children: [
                  for (var i = 0; i < s.custody.length; i++) _CustodyRow(c: s.custody[i], last: i == s.custody.length - 1),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final c = context.lb;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: LBText.body(c.inkDim, size: 13))),
          Expanded(child: Text(v, style: LBText.body(c.ink, size: 13.5, weight: FontWeight.w600))),
        ],
      ),
    );
  }

  static Future<void> _addCustody(BuildContext context, AppState app, Sample s) async {
    final from = TextEditingController(text: s.custody.isNotEmpty ? s.custody.last.to : s.collector);
    final to = TextEditingController();
    final cond = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custody transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: from, decoration: const InputDecoration(labelText: 'Released by')),
            const SizedBox(height: 10),
            TextField(controller: to, decoration: const InputDecoration(labelText: 'Received by'), autofocus: true),
            const SizedBox(height: 10),
            TextField(controller: cond, decoration: const InputDecoration(labelText: 'Condition (temperature, seal)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record')),
        ],
      ),
    );
    if (ok == true) {
      app.update(() {
        s.custody.add(Custody(time: DateTime.now(), from: from.text.trim(), to: to.text.trim(), condition: cond.text.trim()));
        if (s.receivedAt == null && to.text.toLowerCase().contains('lab')) {
          s.receivedAt = DateTime.now();
          if (s.status == SampleStatus.collected) s.status = SampleStatus.received;
        }
      });
    }
  }
}

class _StatusStepper extends StatelessWidget {
  final Sample sample;
  const _StatusStepper({required this.sample});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final idx = sample.status.index;
    return Row(
      children: [
        for (final st in SampleStatus.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => app.update(() {
                sample.status = st;
                if (st.index >= SampleStatus.received.index && sample.receivedAt == null) sample.receivedAt = DateTime.now();
              }),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 6,
                    decoration: BoxDecoration(
                      color: st.index <= idx ? c.accent : c.surface2,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(st.label,
                      textAlign: TextAlign.center,
                      style: LBText.body(st.index == idx ? c.ink : c.inkDim, size: 10.5, weight: st.index == idx ? FontWeight.w700 : FontWeight.w400)),
                ],
              ),
            ),
          ),
          if (st != SampleStatus.values.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final Sample sample;
  final Result result;
  final Check check;
  const _ResultRow({required this.sample, required this.result, required this.check});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final r = result;
    final bad = check.status == Compliance.exceed || check.status == Compliance.belowMin;
    return LBCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: bad ? c.poor.withOpacity(0.5) : null,
      onTap: () => showResultForm(context, sample, existing: r),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.parameter, style: LBText.body(c.ink, size: 14.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (r.method.isNotEmpty) r.method,
                    if (check.limit != null) 'limit ${check.limit!.text}',
                    if (r.source == 'calibration') 'from calibration',
                    if (r.replicates.length > 1)
                      'n=${r.replicates.length}, RSD ${Describe.of(r.replicates).rsd.toStringAsFixed(1)}%',
                  ].join(' · '),
                  style: LBText.body(c.inkDim, size: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${resultText(r)} ${r.unit}', style: LBText.reading(15, bad ? c.poor : c.ink, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              ComplianceChip(check.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustodyRow extends StatelessWidget {
  final Custody c;
  final bool last;
  const _CustodyRow({required this.c, required this.last});

  @override
  Widget build(BuildContext context) {
    final t = context.lb;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle)),
              if (!last) Expanded(child: Container(width: 2, color: t.line)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c.from} → ${c.to}', style: LBText.body(t.ink, size: 13.5, weight: FontWeight.w700)),
                  Text(dateTime(c.time), style: LBText.reading(12, t.inkDim)),
                  if (c.condition.isNotEmpty) Text(c.condition, style: LBText.body(t.inkDim, size: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result entry
// ---------------------------------------------------------------------------

Future<void> showResultForm(BuildContext context, Sample sample, {Result? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ResultForm(sample: sample, existing: existing),
  );
}

class _ResultForm extends StatefulWidget {
  final Sample sample;
  final Result? existing;
  const _ResultForm({required this.sample, this.existing});

  @override
  State<_ResultForm> createState() => _ResultFormState();
}

class _ResultFormState extends State<_ResultForm> {
  final _param = TextEditingController();
  final _value = TextEditingController();
  final _lod = TextEditingController();
  final _method = TextEditingController();
  final _analyst = TextEditingController();
  final _note = TextEditingController();
  String _unit = 'mg/L';
  bool _belowLod = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.read(context);
    final r = widget.existing;
    if (r != null) {
      _param.text = r.parameter;
      _value.text = r.replicates.length > 1 ? r.replicates.map(fmtValue).join(' ') : (r.value?.toString() ?? '');
      _lod.text = r.lod?.toString() ?? '';
      _method.text = r.method;
      _analyst.text = r.analyst;
      _note.text = r.note;
      _unit = r.unit;
      _belowLod = r.belowLod;
    } else {
      _analyst.text = app.settings.analyst;
      _unit = widget.sample.matrix.isSolid ? 'mg/kg' : 'mg/L';
    }
  }

  void _save() {
    final app = AppScope.read(context);
    final p = _param.text.trim();
    final parsed = parseResultText(_value.text);
    if (parsed.belowLod) {
      _belowLod = true;
      if (parsed.lod != null) _lod.text = parsed.lod.toString();
    }
    final v = parsed.value;
    if (p.isEmpty || (!_belowLod && v == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a parameter and a value (or tick < LOD).')));
      return;
    }
    app.update(() {
      final r = widget.existing ?? Result(id: newId(), parameter: p);
      r.parameter = p;
      r.value = _belowLod ? null : v;
      r.belowLod = _belowLod;
      r.lod = double.tryParse(_lod.text.trim());
      r.unit = _unit;
      r.method = _method.text.trim();
      r.analyst = _analyst.text.trim();
      r.note = _note.text.trim();
      r.replicates = _belowLod ? [] : parsed.replicates;
      if (widget.existing == null) {
        widget.sample.results.add(r);
        if (widget.sample.status.index < SampleStatus.inAnalysis.index) widget.sample.status = SampleStatus.inAnalysis;
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final set = app.limitsFor(widget.sample);
    final parsed = parseResultText(_value.text);
    final preview = Result(
      id: 'p',
      parameter: _param.text,
      value: parsed.value,
      belowLod: _belowLod || parsed.belowLod,
      unit: _unit,
    );
    final rep = parsed.replicates.length > 1 ? Describe.of(parsed.replicates) : null;
    final chk = checkResult(preview, set);
    final unitItems = {...units, _unit}.toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add result' : 'Edit result', style: LBText.title(c.ink)),
            Text(widget.sample.code, style: LBText.reading(13, c.inkDim)),
            const SizedBox(height: 14),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _param.text),
              optionsBuilder: (v) {
                final q = v.text.toLowerCase();
                return commonParameters.keys.where((p) => q.isEmpty || p.toLowerCase().contains(q)).take(12);
              },
              onSelected: (p) => setState(() {
                _param.text = p;
                final u = commonParameters[p];
                if (u != null) _unit = (widget.sample.matrix.isSolid && u == 'mg/L') ? 'mg/kg' : u;
                if (_method.text.trim().isEmpty) _method.text = defaultMethods[p] ?? '';
              }),
              fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  onChanged: (v) => setState(() => _param.text = v),
                  decoration: const InputDecoration(labelText: 'Parameter', hintText: 'e.g. Lead (Pb)'),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _value,
                    enabled: !_belowLod,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.text,
                    style: LBText.reading(17, c.ink, weight: FontWeight.w700),
                    decoration: const InputDecoration(labelText: 'Result', hintText: '2.07 · <0.001 · 2.05 2.08 2.07'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: [for (final u in unitItems) DropdownMenuItem(value: u, child: Text(u.isEmpty ? '(none)' : u))],
                    onChanged: (u) => setState(() => _unit = u ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rep != null
                  ? 'Replicates n=${rep.n}: mean ${fmtValue(rep.mean)}, SD ${fmtValue(rep.sd)}, RSD ${rep.rsd.toStringAsFixed(1)}%'
                      '${rep.rsd > app.settings.replicateRsdMax ? '  ⚠ above ${app.settings.replicateRsdMax.toStringAsFixed(0)}%: repeat the analysis' : ''}'
                  : parsed.belowLod
                      ? 'Recorded as not detected${parsed.lod != null ? ' (< ${fmtValue(parsed.lod!)})' : ''}'
                      : 'Tip: type triplicate readings separated by spaces to store their mean.',
              style: LBText.reading(11.5, rep != null && rep.rsd > app.settings.replicateRsdMax ? c.poor : c.inkDim),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _belowLod,
              onChanged: (v) => setState(() => _belowLod = v ?? false),
              title: const Text('Below limit of detection (< LOD)'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            TextField(
              controller: _lod,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: LBText.reading(14, c.ink),
              decoration: InputDecoration(labelText: 'LOD / reporting limit ($_unit)', isDense: true),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _method, decoration: const InputDecoration(labelText: 'Method', hintText: 'AAS, UV-Vis…', isDense: true))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _analyst, decoration: const InputDecoration(labelText: 'Analyst', isDense: true))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note', isDense: true)),
            const SizedBox(height: 12),
            if (_param.text.isNotEmpty)
              Row(
                children: [
                  ComplianceChip(chk.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(chk.limit != null ? 'Limit ${chk.limit!.text} (${set?.name ?? ''})' : 'No limit in ${set?.name ?? 'selected set'}',
                        style: LBText.body(c.inkDim, size: 12)),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  IconButton(
                    tooltip: 'Delete result',
                    onPressed: () {
                      app.update(() => widget.sample.results.remove(widget.existing));
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: c.poor),
                  ),
                Expanded(
                  child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('Save result')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
