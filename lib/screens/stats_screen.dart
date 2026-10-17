import 'package:flutter/material.dart';

import '../core/report.dart';
import '../core/stats.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/plot.dart';

enum StatTest { describe, vsLimit, twoGroups, paired, anova, grubbs }

extension StatTestX on StatTest {
  String get label {
    switch (this) {
      case StatTest.describe:
        return 'Descriptive';
      case StatTest.vsLimit:
        return 'Mean vs limit';
      case StatTest.twoGroups:
        return 'Two groups (Welch t)';
      case StatTest.paired:
        return 'Paired t';
      case StatTest.anova:
        return 'One-way ANOVA';
      case StatTest.grubbs:
        return 'Grubbs outlier';
    }
  }
}

List<double> _nums(String s) => RegExp(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?').allMatches(s).map((m) => double.parse(m.group(0)!)).toList();

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatTest _test = StatTest.describe;
  final List<TextEditingController> _groups = [
    TextEditingController(text: '0.012 0.009 0.011 0.013 0.010'),
    TextEditingController(text: '0.015 0.016 0.0145 0.017'),
    TextEditingController(text: '0.011 0.012 0.0125 0.010'),
  ];
  final _limit = TextEditingController(text: '0.01');
  final _alpha = TextEditingController(text: '0.05');

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final alpha = double.tryParse(_alpha.text) ?? 0.05;
    final g = [for (final t in _groups) _nums(t.text)];
    final needGroups = switch (_test) {
      StatTest.twoGroups || StatTest.paired => 2,
      StatTest.anova => _groups.length,
      _ => 1,
    };

    Widget result;
    try {
      result = _result(context, g, alpha);
    } catch (e) {
      result = ResultCard(label: 'Cannot compute', value: 'Check data', sub: e.toString(), ok: false);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
          children: [
            Segmented<StatTest>(values: StatTest.values, selected: _test, label: (t) => t.label, onChanged: (t) => setState(() => _test = t)),
            const SizedBox(height: 14),
            for (var i = 0; i < needGroups && i < _groups.length; i++) ...[
              TextField(
                controller: _groups[i],
                onChanged: (_) => setState(() {}),
                minLines: 1,
                maxLines: 4,
                style: LBText.reading(14, c.ink),
                decoration: InputDecoration(
                  labelText: needGroups == 1 ? 'Data' : 'Group ${String.fromCharCode(65 + i)}',
                  helperText: '${g[i].length} values · separate with spaces, commas or new lines',
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_test == StatTest.anova)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _groups.length < 8 ? () => setState(() => _groups.add(TextEditingController())) : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add group'),
                  ),
                  if (_groups.length > 2)
                    TextButton.icon(
                      onPressed: () => setState(() => _groups.removeLast()),
                      icon: const Icon(Icons.remove_rounded),
                      label: const Text('Remove group'),
                    ),
                ],
              ),
            Row(
              children: [
                if (_test == StatTest.vsLimit) ...[
                  Expanded(child: NumField(controller: _limit, label: 'Limit / reference value', onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 10),
                ],
                Expanded(child: NumField(controller: _alpha, label: 'Significance α', onChanged: (_) => setState(() {}))),
              ],
            ),
            const SizedBox(height: 16),
            result,
          ],
        ),
      ),
    );
  }

  Widget _describeTable(BuildContext context, List<List<double>> groups) {
    return ResultTable(
      columns: ['', for (var i = 0; i < groups.length; i++) groups.length == 1 ? 'Data' : String.fromCharCode(65 + i)],
      rows: [
        for (final row in const ['n', 'Mean', 'SD', 'RSD %', 'Median', 'Min', 'Max', '95% CI low', '95% CI high'])
          [
            row,
            for (final gi in groups)
              () {
                final d = Describe.of(gi);
                return switch (row) {
                  'n' => '${d.n}',
                  'Mean' => fmtValue(d.mean),
                  'SD' => fmtValue(d.sd),
                  'RSD %' => d.rsd.isFinite ? d.rsd.toStringAsFixed(2) : '—',
                  'Median' => fmtValue(d.median),
                  'Min' => fmtValue(d.min),
                  'Max' => fmtValue(d.max),
                  '95% CI low' => d.ci95lo.isFinite ? fmtValue(d.ci95lo) : '—',
                  _ => d.ci95hi.isFinite ? fmtValue(d.ci95hi) : '—',
                };
              }(),
          ]
      ],
    );
  }

  String _p(double p) => !p.isFinite ? '—' : (p < 0.0001 ? '< 0.0001' : p.toStringAsFixed(4));

  Widget _result(BuildContext context, List<List<double>> g, double alpha) {
    final c = context.lb;
    switch (_test) {
      case StatTest.describe:
        final d = Describe.of(g[0]);
        if (d.n == 0) throw 'Enter some numbers.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResultCard(label: 'Mean ± SD', value: '${fmtValue(d.mean)} ± ${fmtValue(d.sd)}', sub: 'n = ${d.n}, RSD ${d.rsd.toStringAsFixed(2)}%'),
            Section('Summary', child: _describeTable(context, [g[0]])),
            Section(
              'Values',
              child: PlotView(
                height: 200,
                xLabel: 'index',
                series: [
                  FnSeries((_) => d.mean, c.good, label: 'mean', strokeWidth: 1.4),
                  PointSeries([for (var i = 0; i < g[0].length; i++) Offset(i + 1.0, g[0][i])], c.accent, line: false, dots: true),
                ],
              ),
            ),
          ],
        );
      case StatTest.vsLimit:
        final limit = double.tryParse(_limit.text) ?? 0;
        final r = Stats.oneSample(g[0], limit);
        final pAbove = Stats.pMeanAbove(g[0], limit);
        final d = Describe.of(g[0]);
        if (d.n < 2) throw 'Need at least 2 values.';
        final exceeds = pAbove < alpha;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResultCard(
              label: exceeds ? 'Mean significantly ABOVE the limit' : (d.mean > limit ? 'Mean above limit, not significant' : 'Mean at or below limit'),
              value: 'mean ${fmtValue(d.mean)} vs ${fmtValue(limit)}',
              ok: !exceeds,
              sub: 't = ${r.t.toStringAsFixed(3)}, df = ${r.df.toStringAsFixed(0)}\n'
                  'One-sided p (mean > limit) = ${_p(pAbove)}   Two-sided p = ${_p(r.p)}\n'
                  '95% CI of mean: ${fmtValue(d.ci95lo)} to ${fmtValue(d.ci95hi)}',
            ),
            Section('Summary', child: _describeTable(context, [g[0]])),
          ],
        );
      case StatTest.twoGroups:
      case StatTest.paired:
        final r = _test == StatTest.paired ? Stats.paired(g[0], g[1]) : Stats.welch(g[0], g[1]);
        if (!r.t.isFinite) throw 'Each group needs at least 2 values with some variation.';
        final sig = r.significant(alpha);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResultCard(
              label: sig ? 'Significant difference' : 'No significant difference',
              value: 'p = ${_p(r.p)}',
              ok: true,
              sub: '${r.test}: t = ${r.t.toStringAsFixed(3)}, df = ${r.df.toStringAsFixed(2)}\n'
                  'Mean difference (A − B) = ${fmtValue(r.meanDiff)}   α = $alpha',
            ),
            Section('Summary', child: _describeTable(context, [g[0], g[1]])),
          ],
        );
      case StatTest.anova:
        final groups = g.where((x) => x.isNotEmpty).toList();
        if (groups.length < 2 || groups.any((x) => x.length < 2)) throw 'Need at least 2 groups with 2 or more values each.';
        final a = Stats.anova(groups);
        final sig = a.p < alpha;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResultCard(
              label: sig ? 'Group means differ' : 'No significant difference between groups',
              value: 'F = ${a.f.toStringAsFixed(3)},  p = ${_p(a.p)}',
              sub: 'α = $alpha',
            ),
            Section(
              'ANOVA table',
              child: ResultTable(
                columns: const ['Source', 'SS', 'df', 'MS', 'F', 'p'],
                rows: [
                  ['Between', fmtValue(a.ssBetween), a.dfBetween.toStringAsFixed(0), fmtValue(a.msBetween), a.f.toStringAsFixed(3), _p(a.p)],
                  ['Within', fmtValue(a.ssWithin), a.dfWithin.toStringAsFixed(0), fmtValue(a.msWithin), '', ''],
                  ['Total', fmtValue(a.ssBetween + a.ssWithin), (a.dfBetween + a.dfWithin).toStringAsFixed(0), '', '', ''],
                ],
              ),
            ),
            Section('Group summaries', child: _describeTable(context, groups)),
          ],
        );
      case StatTest.grubbs:
        final r = Stats.grubbs(g[0], alpha: alpha);
        if (r == null) throw 'Need at least 3 values with some variation.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResultCard(
              label: r.isOutlier ? 'Outlier detected' : 'No outlier',
              value: r.isOutlier ? '${fmtValue(r.value)} is an outlier' : 'Most extreme: ${fmtValue(r.value)}',
              ok: !r.isOutlier,
              sub: 'G = ${r.g.toStringAsFixed(3)}, G critical = ${r.gCritical.toStringAsFixed(3)} (α = $alpha, n = ${g[0].length})\n'
                  'Remove only with a documented reason; then re-test the remaining data.',
            ),
            Section('Summary', child: _describeTable(context, [g[0]])),
          ],
        );
    }
  }
}
