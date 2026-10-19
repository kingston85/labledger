import 'package:flutter/material.dart';

import '../core/analytics.dart';
import '../core/guidelines.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/components.dart';
import 'business_screen.dart';
import 'import_screen.dart';
import 'sample_detail_screen.dart';
import 'sample_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _months = 12;
  String? _trendProject;
  String? _trendParam;

  void _go(String key) => context.findAncestorStateOfType<ShellState>()?.goTo(key);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final a = Analytics(app, months: _months);
    final now = DateTime.now();
    final thisMonth = app.samples.where((s) => (s.receivedAt ?? s.collectedAt).year == now.year && (s.receivedAt ?? s.collectedAt).month == now.month).length;
    final open = app.samples.where((s) => s.status != SampleStatus.reported).toList();
    final overdue = app.samples.where((s) => s.overdue).toList();
    final toApprove = app.samples.where((s) => app.needsApproval(s) && s.status.index >= SampleStatus.inAnalysis.index).toList();
    final compliance = a.overallCompliance();
    final tat = a.meanTurnaround();
    final cur = app.settings.currency;
    final collected = a.collectedPerMonth();
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final hour = now.hour;
    final greet = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    Widget kpi(String label, String value, String sub, IconData icon, Color col, {List<double>? spark, VoidCallback? onTap}) => SizedBox(
          width: 228,
          child: LBCard(
            padding: const EdgeInsets.all(14),
            onTap: onTap,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: col.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: col, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: PanelLabel(label)),
              ]),
              const SizedBox(height: 10),
              Text(value, style: LBText.reading(26, c.ink, weight: FontWeight.w700)),
              Text(sub, style: LBText.body(c.inkDim, size: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (spark != null) ...[const SizedBox(height: 6), Sparkline(spark, color: col)],
            ]),
          ),
        );

    Widget panel(String title, Widget child, {Widget? trailing, String? sub}) => LBCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: LBText.body(c.ink, weight: FontWeight.w700)),
                  if (sub != null) Text(sub, style: LBText.body(c.inkDim, size: 11.5)),
                ]),
              ),
              if (trailing != null) trailing,
            ]),
            const SizedBox(height: 14),
            child,
          ]),
        );

    final volume = panel(
      'Samples received',
      BarChart(labels: [for (final m in a.months) m.label], values: [
        for (var i = 0; i < a.months.length; i++) a.samplesPerMonth()[i] - a.exceedingPerMonth()[i],
      ], stacked: a.exceedingPerMonth(), color: c.accent, stackColor: c.poor),
      sub: 'Blue: all within limits · red: at least one exceedance',
    );
    final comp = panel(
      'Compliance rate',
      LineChart(
        labels: [for (final m in a.months) m.label],
        series: [LineSeries(a.compliancePerMonth(), c.good, '% of results within limits')],
        minY: 0,
        maxY: 100,
        format: (v) => '${v.round()}%',
        refLines: [(90, c.fair.withOpacity(0.8), '90% target')],
      ),
    );
    final tatPanel = panel(
      'Turnaround time',
      LineChart(
        labels: [for (final m in a.months) m.label],
        series: [LineSeries(a.turnaroundPerMonth(), TLBlue.blue, 'Mean days, receipt → report')],
        minY: 0,
        format: (v) => v.toStringAsFixed(1),
        refLines: [(10, c.poor.withOpacity(0.7), '10-day target')],
      ),
    );
    final mix = a.byMatrix();
    final matrixColors = [c.accent, c.good, c.fair, c.poor, TLBlue.blue, TLBlue.violet, TLBlue.teal, c.inkDim, TLBlue.pink];
    final mixPanel = panel(
      'Sample matrix',
      DonutChart(
        segments: [for (final m in Matrix.values) if ((mix[m] ?? 0) > 0) (m.label, (mix[m] ?? 0).toDouble(), matrixColors[m.index % matrixColors.length])],
        centre: '${app.samples.length}',
        centreSub: 'samples',
        size: 140,
      ),
    );
    final top = a.topExceeded();
    final exPanel = panel(
      'Most frequent exceedances',
      top.isEmpty ? Text('No exceedances recorded.', style: LBText.body(c.inkDim, size: 13)) : HBarList(items: [for (final t in top) (t.$1, t.$2.toDouble(), '${t.$2}')], color: c.poor),
    );
    final revenue = panel(
      'Revenue',
      BarChart(
        labels: [for (final m in a.months) m.label],
        values: collected,
        color: c.good,
        format: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.round().toString(),
      ),
      sub: 'Payments received per month · invoiced ${money(a.invoicedPerMonth().fold(0.0, (x, y) => x + y), cur)} in the period',
    );
    final clientsTop = a.topClients();
    final clientPanel = panel(
      'Top clients (invoiced)',
      clientsTop.isEmpty ? Text('No invoices yet.', style: LBText.body(c.inkDim, size: 13)) : HBarList(items: [for (final t in clientsTop) (t.$1, t.$2, money(t.$2, cur))], color: c.accent),
    );

    // Trend explorer.
    final projects = app.samples.map((s) => s.project).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final proj = _trendProject != null && projects.contains(_trendProject) ? _trendProject : (projects.isEmpty ? null : projects.first);
    final params = proj == null ? <String>[] : (app.samples.where((s) => s.project == proj).expand((s) => s.results).map((r) => canonicalParameter(r.parameter)).toSet().toList()..sort());
    final param = _trendParam != null && params.contains(_trendParam) ? _trendParam : (params.contains('Iron (Fe)') ? 'Iron (Fe)' : (params.isEmpty ? null : params.first));
    final trend = proj == null || param == null ? <(Sample, Result)>[] : a.trend(param, project: proj);
    Limit? lim;
    for (final t in trend) {
      final set = app.limitsFor(t.$1);
      if (set != null) lim = findLimit(set, param!);
      if (lim != null) break;
    }
    final trendPanel = panel(
      'Trend explorer',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: 300,
            child: DropdownButtonFormField<String>(
              value: proj,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project', isDense: true),
              items: [for (final p in projects) DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() {
                _trendProject = v;
                _trendParam = null;
              }),
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              value: param,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Parameter', isDense: true),
              items: [for (final p in params) DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _trendParam = v),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (trend.isEmpty)
          Text('No values for this selection.', style: LBText.body(c.inkDim, size: 13))
        else
          LineChart(
            labels: [for (final t in trend) t.$1.code],
            series: [
              LineSeries([for (final t in trend) t.$1.isControl ? null : (t.$2.belowLod ? (t.$2.lod ?? 0) : t.$2.value)], c.accent, '$param (${trend.first.$2.unit})'),
              LineSeries([for (final t in trend) t.$1.isControl ? (t.$2.belowLod ? (t.$2.lod ?? 0) : t.$2.value) : null], c.good, 'control'),
            ],
            refLines: [if (lim?.max != null) (lim!.max!, c.poor, 'limit ${lim.text}'), if (lim?.min != null) (lim!.min!, c.fair, 'minimum')],
            height: 220,
          ),
      ]),
      sub: 'Values of one parameter across the samples of a project, in sampling order',
    );

    // Work queue.
    Widget queueRow(IconData icon, Color col, String title, String sub, VoidCallback onTap) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: col, size: 20),
          title: Text(title, style: LBText.body(c.ink, size: 13, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          subtitle: Text(sub, style: LBText.body(c.inkDim, size: 11.5), overflow: TextOverflow.ellipsis),
          trailing: Icon(Icons.chevron_right_rounded, color: c.inkDim, size: 18),
          onTap: onTap,
        );
    final overdueInv = app.invoices.where((i) => i.status == InvoiceStatus.overdue).toList();
    final queue = panel(
      'Work queue',
      Column(children: [
        for (final s in overdue.take(4))
          queueRow(Icons.timer_off_rounded, c.poor, '${s.code} overdue', 'Due ${shortDate(s.dueDate!)} · ${s.status.label}',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s)))),
        for (final s in toApprove.take(4))
          queueRow(Icons.approval_rounded, c.fair, '${s.code} awaiting approval', '${s.results.where((r) => !r.approved).length} results to review',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s)))),
        for (final i in overdueInv.take(3))
          queueRow(Icons.receipt_long_rounded, c.poor, '${i.number} overdue', '${app.client(i.clientId)?.name ?? ''} · ${money(i.balance, cur)} due', () => _go('invoices')),
        for (final al in app.registerAlerts.take(3)) queueRow(al.$3 == 2 ? Icons.error_rounded : Icons.schedule_rounded, al.$3 == 2 ? c.poor : c.fair, al.$1, al.$2, () => _go('register')),
        if (overdue.isEmpty && toApprove.isEmpty && overdueInv.isEmpty && app.registerAlerts.isEmpty)
          Padding(padding: const EdgeInsets.all(8), child: Text('All clear. Nothing overdue or waiting.', style: LBText.body(c.good, size: 13))),
      ]),
    );

    final recent = [...app.samples]..sort((x, y) => (y.receivedAt ?? y.collectedAt).compareTo(x.receivedAt ?? x.collectedAt));
    final recentPanel = panel(
      'Latest samples',
      Column(children: [
        for (final s in recent.take(6))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s))),
            title: Text(s.code, style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
            subtitle: Text(s.site.isEmpty ? s.matrix.label : s.site, style: LBText.body(c.inkDim, size: 11.5), overflow: TextOverflow.ellipsis),
            trailing: Tag(s.status.label, color: s.status == SampleStatus.reported ? c.good : c.accent),
          ),
      ]),
      trailing: TextButton(onPressed: () => _go('samples'), child: const Text('All samples')),
    );

    final charts = [volume, comp, tatPanel, mixPanel, exPanel, revenue, clientPanel];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greet${app.currentUser == null ? '' : ', ${app.currentUser!.name.split(' ').first}'}', style: LBText.title(c.ink, size: 20)),
          Text('${app.settings.labName} · ${shortDate(now)}', style: LBText.body(c.inkDim, size: 12)),
        ]),
        actions: [
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 6, label: Text('6 mo')), ButtonSegment(value: 12, label: Text('12 mo')), ButtonSegment(value: 24, label: Text('24 mo'))],
            selected: {_months},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (v) => setState(() => _months = v.first),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
        children: [
          if (app.hasDemo)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.accent.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: c.accent),
                const SizedBox(width: 10),
                Expanded(child: Text('Demo data is loaded (samples, clients, invoices). Remove it under Settings & tools.', style: LBText.body(c.ink, size: 13))),
              ]),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (app.canEdit)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SampleFormScreen())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New sample'),
              ),
            if (app.canEdit)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportScreen())),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Import results'),
              ),
            if (app.canEdit)
              OutlinedButton.icon(onPressed: () => openRequestEditor(context, null), icon: const Icon(Icons.request_quote_outlined), label: const Text('New request')),
            if (app.canEdit)
              OutlinedButton.icon(onPressed: () => openInvoiceEditor(context, null), icon: const Icon(Icons.receipt_long_outlined), label: const Text('New invoice')),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            kpi('Samples', '${app.samples.length}', '$thisMonth received this month', Icons.science_rounded, c.accent, spark: a.samplesPerMonth(), onTap: () => _go('samples')),
            kpi('In progress', '${open.length}', '${overdue.length} overdue', Icons.pending_actions_rounded, overdue.isEmpty ? c.fair : c.poor, onTap: () => _go('samples')),
            kpi('Awaiting approval', '${toApprove.length}', app.settings.requireApproval ? 'reviewer sign-off' : 'approval not required', Icons.approval_rounded, c.fair),
            kpi('Compliance', compliance == null ? '—' : '${compliance.toStringAsFixed(0)}%', 'results within limits, 12 mo', Icons.verified_rounded, (compliance ?? 100) >= 90 ? c.good : c.poor,
                spark: a.compliancePerMonth().whereType<double>().toList()),
            kpi('Turnaround', tat == null ? '—' : '${tat.toStringAsFixed(1)} d', 'mean receipt → report', Icons.timer_rounded, TLBlue.blue),
            kpi('Collected', money(collected.isEmpty ? 0 : collected.last, cur), 'payments this month', Icons.payments_rounded, c.good, spark: collected, onTap: () => _go('invoices')),
            kpi('Outstanding', money(app.outstanding, cur), '${overdueInv.length} invoice${overdueInv.length == 1 ? '' : 's'} overdue', Icons.account_balance_wallet_rounded,
                overdueInv.isEmpty ? c.fair : c.poor, onTap: () => _go('invoices')),
          ]),
          const SizedBox(height: 14),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: Column(children: [queue, const SizedBox(height: 12), trendPanel])),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: recentPanel),
            ])
          else ...[
            queue,
            const SizedBox(height: 12),
            recentPanel,
            const SizedBox(height: 12),
            trendPanel,
          ],
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth >= 1000 ? 3 : (box.maxWidth >= 640 ? 2 : 1);
            final w = (box.maxWidth - (cols - 1) * 12) / cols;
            return Wrap(spacing: 12, runSpacing: 12, children: [for (final ch in charts) SizedBox(width: w, child: ch)]);
          }),
          const SizedBox(height: 10),
          Text('Results compared with each sample\'s limit set. ${resultsNote(app)}', style: LBText.body(c.inkDim, size: 11.5)),
        ],
      ),
    );
  }
}

String resultsNote(AppState app) {
  final n = app.samples.fold<int>(0, (a, s) => a + s.results.length);
  return '$n results in ${app.samples.length} samples; ${fmtValue(app.samples.where((s) => s.reportedAt != null).length.toDouble())} reported.';
}

/// Extra fixed hues for charts.
class TLBlue {
  static const blue = Color(0xFF4DA3FF);
  static const violet = Color(0xFFB07CFF);
  static const teal = Color(0xFF00C2C7);
  static const pink = Color(0xFFE91E63);
}
