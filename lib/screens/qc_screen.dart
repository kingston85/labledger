import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/report.dart';
import '../core/stats.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/plot.dart';

class QcScreen extends StatelessWidget {
  const QcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        final c = context.lb;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Quality control'),
            bottom: TabBar(
              indicatorColor: c.accent,
              labelColor: c.ink,
              unselectedLabelColor: c.inkDim,
              tabs: const [Tab(text: 'QC checks'), Tab(text: 'Control charts')],
            ),
          ),
          floatingActionButton: Builder(
            builder: (context) => FloatingActionButton.extended(
              onPressed: () {
                final tab = DefaultTabController.of(context).index;
                if (tab == 0) {
                  showQcForm(context);
                } else {
                  _newChart(context);
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ),
          body: const TabBarView(children: [_ChecksTab(), _ChartsTab()]),
        );
      }),
    );
  }

  static Future<void> _newChart(BuildContext context) async {
    final app = AppScope.read(context);
    final name = TextEditingController();
    final param = TextEditingController();
    final mean = TextEditingController();
    final sd = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New control chart'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'QC material', hintText: 'e.g. Pb 2.0 mg/L check std')),
              const SizedBox(height: 10),
              TextField(controller: param, decoration: const InputDecoration(labelText: 'Parameter')),
              const SizedBox(height: 10),
              TextField(controller: mean, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target mean (optional)')),
              const SizedBox(height: 10),
              TextField(controller: sd, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Target SD (optional)', helperText: 'Blank = calculate from the first 20 points')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final ch = ControlChart(
        id: newId(),
        name: name.text.trim(),
        parameter: param.text.trim(),
        targetMean: double.tryParse(mean.text.trim()),
        targetSd: double.tryParse(sd.text.trim()),
      );
      app.update(() => app.charts.insert(0, ch));
      if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ControlChartScreen(chart: ch)));
    }
  }
}

class _ChecksTab extends StatelessWidget {
  const _ChecksTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final list = [...app.qc]..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.verified_outlined,
          title: 'No QC checks yet',
          body: 'Record method blanks, duplicates, matrix spikes and reference materials. Pass/fail limits are set under More → Settings.',
        ),
      );
    }
    final pass = list.where(app.qcPasses).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        LBCard(
          child: Row(
            children: [
              Expanded(child: Reading(label: 'Checks', value: '${list.length}', size: 20)),
              Expanded(child: Reading(label: 'Passed', value: '$pass', size: 20, color: c.good)),
              Expanded(child: Reading(label: 'Failed', value: '${list.length - pass}', size: 20, color: list.length - pass > 0 ? c.poor : c.ink)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final q in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: () {
              final e = app.qcEvaluate(q);
              return LBCard(
                borderColor: e.$1 ? null : c.poor.withOpacity(0.5),
                onTap: () => showQcForm(context, existing: q),
                child: Row(
                  children: [
                    Icon(e.$1 ? Icons.check_circle_rounded : Icons.cancel_rounded, color: e.$1 ? c.good : c.poor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${q.type.label} · ${q.parameter}', style: LBText.body(c.ink, size: 14, weight: FontWeight.w700)),
                          Text(e.$3, style: LBText.body(c.inkDim, size: 12.5)),
                          Text('${q.batch.isEmpty ? '' : 'Batch ${q.batch} · '}${shortDate(q.date)}', style: LBText.body(c.inkDim, size: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }(),
          ),
      ],
    );
  }
}

Future<void> showQcForm(BuildContext context, {QcCheck? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QcForm(existing: existing),
  );
}

class _QcForm extends StatefulWidget {
  final QcCheck? existing;
  const _QcForm({this.existing});

  @override
  State<_QcForm> createState() => _QcFormState();
}

class _QcFormState extends State<_QcForm> {
  QcType _type = QcType.duplicate;
  final _param = TextEditingController();
  final _batch = TextEditingController();
  final _note = TextEditingController();
  final _v = [TextEditingController(), TextEditingController(), TextEditingController()];
  String _unit = 'mg/L';

  @override
  void initState() {
    super.initState();
    final q = widget.existing;
    if (q != null) {
      _type = q.type;
      _param.text = q.parameter;
      _batch.text = q.batch;
      _note.text = q.note;
      _unit = q.unit;
      for (var i = 0; i < q.values.length && i < 3; i++) {
        _v[i].text = q.values[i].toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final vals = [for (var i = 0; i < _type.fields.length; i++) double.tryParse(_v[i].text.trim())];
    final complete = vals.every((v) => v != null);
    final preview = complete ? QcCheck(id: 'p', type: _type, parameter: _param.text, values: [for (final v in vals) v!]) : null;
    final ev = preview == null ? null : app.qcEvaluate(preview);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Record QC check' : 'QC check', style: LBText.title(c.ink)),
            const SizedBox(height: 12),
            Segmented<QcType>(values: QcType.values, selected: _type, label: (t) => t.label, onChanged: (t) => setState(() => _type = t)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _param,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Parameter', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: units.contains(_unit) ? _unit : 'mg/L',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                    items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u.isEmpty ? '(none)' : u))],
                    onChanged: (u) => setState(() => _unit = u ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _type.fields.length; i++) ...[
              TextField(
                controller: _v[i],
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                style: LBText.reading(15, c.ink),
                decoration: InputDecoration(labelText: _type.fields[i], isDense: true, suffixText: _unit),
              ),
              const SizedBox(height: 10),
            ],
            TextField(controller: _batch, decoration: const InputDecoration(labelText: 'Batch / run', isDense: true)),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note', isDense: true)),
            const SizedBox(height: 14),
            if (ev != null)
              ResultCard(label: ev.$1 ? 'Pass' : 'Fail', value: ev.$2.isFinite ? fmtValue(ev.$2) + (_type == QcType.blank ? ' $_unit' : ' %') : '—', sub: ev.$3, ok: ev.$1),
            const SizedBox(height: 14),
            Row(
              children: [
                if (widget.existing != null)
                  IconButton(
                    onPressed: () {
                      app.update(() => app.qc.remove(widget.existing));
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: c.poor),
                  ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: !complete || _param.text.trim().isEmpty
                        ? null
                        : () {
                            app.update(() {
                              final q = widget.existing ?? QcCheck(id: newId(), type: _type, parameter: '');
                              q.type = _type;
                              q.parameter = _param.text.trim();
                              q.unit = _unit;
                              q.batch = _batch.text.trim();
                              q.note = _note.text.trim();
                              q.values = [for (final v in vals) v!];
                              if (widget.existing == null) app.qc.add(q);
                            });
                            Navigator.pop(context);
                          },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save check'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartsTab extends StatelessWidget {
  const _ChartsTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    if (app.charts.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.stacked_line_chart_rounded,
          title: 'No control charts',
          body: 'Track a check standard or reference material over time, with ±2s and ±3s limits and Westgard rules.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: app.charts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final ch = app.charts[i];
        final lim = chartLimits(ch);
        final flags = lim == null ? <List<WestgardRule>>[] : westgard([for (final p in ch.points) p.value], lim.$1, lim.$2);
        final rejects = flags.isEmpty ? false : flags.last.any((r) => r.rejects);
        return LBCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ControlChartScreen(chart: ch))),
          child: Row(
            children: [
              Icon(Icons.stacked_line_chart_rounded, color: rejects ? c.poor : c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ch.name, style: LBText.body(c.ink, size: 14.5, weight: FontWeight.w700)),
                    Text('${ch.parameter} · ${ch.points.length} points', style: LBText.body(c.inkDim, size: 12.5)),
                  ],
                ),
              ),
              Tag(rejects ? 'Out of control' : 'In control', color: rejects ? c.poor : c.good),
            ],
          ),
        );
      },
    );
  }
}

/// (mean, sd) used for the chart: fixed targets, else from the first 20 points.
(double, double)? chartLimits(ControlChart ch) {
  if (ch.targetMean != null && ch.targetSd != null && ch.targetSd! > 0) return (ch.targetMean!, ch.targetSd!);
  final base = ch.points.take(20).map((p) => p.value).toList();
  if (base.length < 3) return null;
  final d = Describe.of(base);
  if (d.sd == 0) return null;
  return (ch.targetMean ?? d.mean, ch.targetSd ?? d.sd);
}

class ControlChartScreen extends StatelessWidget {
  final ControlChart chart;
  const ControlChartScreen({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final ch = chart;
    final lim = chartLimits(ch);
    final vals = [for (final p in ch.points) p.value];
    final flags = lim == null ? <List<WestgardRule>>[] : westgard(vals, lim.$1, lim.$2);
    final n = ch.points.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(ch.name),
        actions: [
          IconButton(
            tooltip: 'Delete chart',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () {
              app.update(() => app.charts.remove(ch));
              Navigator.pop(context);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPoint(context, app),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add result'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (lim == null)
            const ResultCard(label: 'Limits', value: 'Need more data', sub: 'Add at least 3 results, or set a target mean and SD.', ok: false)
          else ...[
            Row(
              children: [
                Expanded(child: Reading(label: 'Mean', value: fmtValue(lim.$1), size: 18)),
                Expanded(child: Reading(label: 'SD', value: fmtValue(lim.$2), size: 18)),
                Expanded(child: Reading(label: 'CV %', value: (lim.$2 / lim.$1 * 100).toStringAsFixed(1), size: 18)),
              ],
            ),
            const SizedBox(height: 4),
            Text(ch.targetMean != null && ch.targetSd != null ? 'Fixed target limits' : 'Limits from the first ${math.min(20, n)} results',
                style: LBText.body(c.inkDim, size: 12)),
            Section(
              'Shewhart chart',
              child: PlotView(
                height: 300,
                xMin: 0.5,
                xMax: math.max(n, 2) + 0.5,
                yMin: lim.$1 - 4 * lim.$2,
                yMax: lim.$1 + 4 * lim.$2,
                xLabel: 'run',
                series: [
                  FnSeries((_) => lim.$1 + 3 * lim.$2, c.poor, label: '±3s', strokeWidth: 1.2),
                  FnSeries((_) => lim.$1 - 3 * lim.$2, c.poor, strokeWidth: 1.2),
                  FnSeries((_) => lim.$1 + 2 * lim.$2, c.fair, label: '±2s', strokeWidth: 1.2),
                  FnSeries((_) => lim.$1 - 2 * lim.$2, c.fair, strokeWidth: 1.2),
                  FnSeries((_) => lim.$1, c.good, label: 'mean', strokeWidth: 1.4),
                  PointSeries([for (var i = 0; i < n; i++) Offset(i + 1.0, vals[i])], c.accent, dots: true, label: 'QC result'),
                  MarkerSeries([
                    for (var i = 0; i < n; i++)
                      if (flags[i].any((r) => r.rejects)) Offset(i + 1.0, vals[i])
                  ], c.poor),
                ],
              ),
            ),
            PlotLegend([
              FnSeries((_) => 0, c.good, label: 'mean'),
              FnSeries((_) => 0, c.fair, label: '±2s warning'),
              FnSeries((_) => 0, c.poor, label: '±3s / rule violation'),
            ]),
            Section(
              'Westgard rule violations',
              child: () {
                final rows = <List<String>>[];
                for (var i = 0; i < n; i++) {
                  for (final r in flags[i]) {
                    rows.add(['${i + 1}', shortDate(ch.points[i].date), fmtValue(vals[i]), r.label, r.rejects ? 'Reject' : 'Warning']);
                  }
                }
                if (rows.isEmpty) return Text('No rule violations. The method is in statistical control.', style: LBText.body(c.good, size: 13));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResultTable(columns: const ['Run', 'Date', 'Value', 'Rule', 'Action'], rows: rows),
                    for (final r in {for (final f in flags) ...f})
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${r.label}: ${r.meaning}', style: LBText.body(c.inkDim, size: 12)),
                      ),
                  ],
                );
              }(),
            ),
          ],
          Section(
            'Results',
            child: ResultTable(
              columns: const ['Run', 'Date', 'Value', 'z'],
              rows: [
                for (var i = n - 1; i >= 0; i--)
                  [
                    '${i + 1}',
                    shortDate(ch.points[i].date),
                    fmtValue(vals[i]),
                    lim == null ? '—' : ((vals[i] - lim.$1) / lim.$2).toStringAsFixed(2),
                  ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPoint(BuildContext context, AppState app) async {
    final v = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add QC result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: v, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: 'Value (${chart.unit})')),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    final x = double.tryParse(v.text.trim());
    if (ok == true && x != null) {
      app.update(() => chart.points.add(ControlPoint(date: DateTime.now(), value: x, note: note.text.trim())));
    }
  }
}
