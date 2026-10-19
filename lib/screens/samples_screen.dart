import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/data_grid.dart';
import '../widgets/share.dart';
import 'sample_detail_screen.dart';
import 'sample_form_screen.dart';

class SamplesScreen extends StatefulWidget {
  const SamplesScreen({super.key});

  @override
  State<SamplesScreen> createState() => _SamplesScreenState();
}

class _SamplesScreenState extends State<SamplesScreen> {
  final _q = TextEditingController();
  SampleStatus? _status;
  Matrix? _matrix;
  bool _onlyExceed = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final q = _q.text.trim().toLowerCase();
    final list = app.samples.where((s) {
      if (_status != null && s.status != _status) return false;
      if (_matrix != null && s.matrix != _matrix) return false;
      if (_onlyExceed) {
        final set = app.limitsFor(s);
        if (!s.results.any((r) {
          final st = checkResult(r, set).status;
          return st == Compliance.exceed || st == Compliance.belowMin;
        })) return false;
      }
      if (q.isEmpty) return true;
      return s.code.toLowerCase().contains(q) ||
          s.site.toLowerCase().contains(q) ||
          s.project.toLowerCase().contains(q) ||
          (app.client(s.clientId)?.name.toLowerCase().contains(q) ?? false) ||
          s.results.any((r) => r.parameter.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Samples'),
        actions: [
          IconButton(
            tooltip: 'Export results (CSV)',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => shareText(context, 'LabLedger_results.csv', Reports.resultsCsv(app, list), 'text/csv',
                subject: 'LabLedger results'),
          ),
        ],
      ),
      floatingActionButton: !app.canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SampleFormScreen())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New sample'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search code, site, project or parameter',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(_q.clear)),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Exceedances'),
                  selected: _onlyExceed,
                  onSelected: (v) => setState(() => _onlyExceed = v),
                ),
                const SizedBox(width: 8),
                for (final st in SampleStatus.values) ...[
                  ChoiceChip(
                    label: Text(st.label),
                    selected: _status == st,
                    onSelected: (v) => setState(() => _status = v ? st : null),
                  ),
                  const SizedBox(width: 8),
                ],
                PopupMenuButton<int>(
                  onSelected: (i) => setState(() => _matrix = i < 0 ? null : Matrix.values[i]),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: -1, child: Text('All matrices')),
                    for (final m in Matrix.values) PopupMenuItem(value: m.index, child: Text(m.label)),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.filter_list_rounded, size: 16),
                    label: Text(_matrix?.label ?? 'Matrix'),
                  ),
                ),
              ],
            ),
          ),
          if (isWide(context))
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                child: DataGrid<Sample>(
                  rows: list,
                  onTap: (s) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s))),
                  minWidth: 1000,
                  initialSort: 5,
                  initialAscending: false,
                  empty: 'No samples match the filters.',
                  columns: [
                    GridColumn('Code', width: 130, cell: (s) => gridText(context, s.code, mono: true, bold: true, color: s.isControl ? c.good : null), sortKey: (s) => s.code),
                    GridColumn('Location', flex: 2, cell: (s) => gridText(context, s.site.isEmpty ? '—' : s.site, size: 12.5), sortKey: (s) => s.site),
                    GridColumn('Project', flex: 1.5, cell: (s) => gridText(context, s.project, size: 12.5), sortKey: (s) => s.project),
                    GridColumn('Client', flex: 1.3, cell: (s) => gridText(context, app.client(s.clientId)?.name ?? '—', size: 12.5), sortKey: (s) => app.client(s.clientId)?.name ?? ''),
                    GridColumn('Matrix', width: 110, cell: (s) => gridText(context, s.matrix.label, size: 12), sortKey: (s) => s.matrix.index),
                    GridColumn('Collected', width: 105, cell: (s) => gridText(context, shortDate(s.collectedAt), size: 12), sortKey: (s) => s.collectedAt),
                    GridColumn('Due', width: 100, cell: (s) => gridText(context, s.dueDate == null ? '—' : shortDate(s.dueDate!), size: 12, color: s.overdue ? c.poor : null), sortKey: (s) => s.dueDate ?? DateTime(2100)),
                    GridColumn('Status', width: 110, cell: (s) => StatusChip(s.status), sortKey: (s) => s.status.index),
                    GridColumn('Results', width: 76, numeric: true, cell: (s) => gridText(context, '${s.results.length}', mono: true), sortKey: (s) => s.results.length),
                    GridColumn('Out', width: 60, numeric: true, cell: (s) {
                      final set = app.limitsFor(s);
                      final n = s.results.where((r) {
                        final k = checkResult(r, set).status;
                        return k == Compliance.exceed || k == Compliance.belowMin;
                      }).length;
                      return gridText(context, n == 0 ? '—' : '$n', mono: true, bold: n > 0, color: n > 0 ? c.poor : c.inkDim);
                    }, sortKey: (s) {
                      final set = app.limitsFor(s);
                      return s.results.where((r) => checkResult(r, set).status == Compliance.exceed).length;
                    }),
                    GridColumn('Approved', width: 86, cell: (s) {
                      if (s.results.isEmpty) return gridText(context, '—', color: c.inkDim);
                      final ok = s.results.every((r) => r.approved);
                      return Icon(ok ? Icons.verified_rounded : Icons.pending_rounded, size: 18, color: ok ? c.good : c.fair);
                    }, sortKey: (s) => s.results.where((r) => r.approved).length),
                  ],
                ),
              ),
            )
          else
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.science_outlined,
                      title: 'No samples found',
                      body: 'Change the filters, or register a new sample.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => SampleTile(sample: list[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${list.length} of ${app.samples.length} samples', style: LBText.body(c.inkDim, size: 12)),
          ),
        ],
      ),
    );
  }
}

class SampleTile extends StatelessWidget {
  final Sample sample;
  const SampleTile({super.key, required this.sample});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final set = app.limitsFor(sample);
    final bad = sample.results.where((r) {
      final st = checkResult(r, set).status;
      return st == Compliance.exceed || st == Compliance.belowMin;
    }).length;
    return LBCard(
      padding: const EdgeInsets.all(14),
      borderColor: bad > 0 ? c.poor.withOpacity(0.45) : null,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: sample))),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(sample.matrix.isSolid ? Icons.landscape_rounded : Icons.water_drop_rounded, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sample.code, style: LBText.reading(14, c.ink, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sample.site.isEmpty ? sample.matrix.label : sample.site,
                    style: LBText.body(c.inkDim, size: 12.5), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    StatusChip(sample.status),
                    if (sample.isControl) ...[const SizedBox(width: 6), Tag('CONTROL', color: c.good)],
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('${sample.results.length} results · ${shortDate(sample.collectedAt)}',
                          style: LBText.body(c.inkDim, size: 11.5), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (bad > 0)
            Column(
              children: [
                Icon(Icons.warning_amber_rounded, color: c.poor),
                Text('$bad', style: LBText.reading(12, c.poor, weight: FontWeight.w700)),
              ],
            ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final SampleStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final color = switch (status) {
      SampleStatus.collected => c.inkDim,
      SampleStatus.received => c.accent,
      SampleStatus.inAnalysis => c.fair,
      SampleStatus.reviewed => const Color(0xFFB57BFF),
      SampleStatus.reported => c.good,
    };
    return Tag(status.label, color: color);
  }
}
