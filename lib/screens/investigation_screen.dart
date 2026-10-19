import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/investigation.dart';
import '../core/docx.dart';
import '../core/indices.dart';
import '../core/investigation_report.dart';
import '../core/word_reports.dart';
import '../core/report.dart';
import '../core/utm.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/plot.dart';
import '../widgets/share.dart';
import 'import_screen.dart';
import 'indices_view.dart';
import 'sample_detail_screen.dart';

/// All projects / field investigations.
class InvestigationsScreen extends StatelessWidget {
  const InvestigationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final projects = app.projects;
    return Scaffold(
      appBar: AppBar(title: const Text('Investigations')),
      body: projects.isEmpty
          ? const EmptyState(
              icon: Icons.travel_explore_rounded,
              title: 'No investigations yet',
              body: 'Give samples the same project name to analyse them together.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Text('Samples sharing a project name are analysed together: results matrix, standards, control comparison and findings.',
                    style: LBText.body(c.inkDim, size: 12.5)),
                const SizedBox(height: 12),
                for (final (name, list) in projects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ProjectTile(name: name, samples: list),
                  ),
              ],
            ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final String name;
  final List<Sample> samples;
  const _ProjectTile({required this.name, required this.samples});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    var bad = 0;
    for (final s in samples.where((s) => !s.matrix.isSolid)) {
      final set = app.limitsFor(s);
      for (final r in s.results) {
        final k = checkResult(r, set).status;
        if (k == Compliance.exceed || k == Compliance.belowMin) bad++;
      }
    }
    final ctrl = samples.where((s) => s.isControl).length;
    final dates = samples.map((s) => s.collectedAt).toList()..sort();
    return LBCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvestigationScreen(project: name))),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: c.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.travel_explore_rounded, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: LBText.body(c.ink, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${samples.length} samples · $ctrl control · ${shortDate(dates.first)}',
                    style: LBText.body(c.inkDim, size: 12.5)),
              ],
            ),
          ),
          if (bad > 0) Tag('$bad out', color: c.poor) else Tag('OK', color: c.good),
        ],
      ),
    );
  }
}

enum _View { findings, matrix, profile, control, indices, map }

class InvestigationScreen extends StatefulWidget {
  final String project;
  const InvestigationScreen({super.key, required this.project});

  @override
  State<InvestigationScreen> createState() => _InvestigationScreenState();
}

class _InvestigationScreenState extends State<InvestigationScreen> {
  _View _view = _View.findings;
  int _group = 0;
  String? _param;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final samples = app.samplesInProject(widget.project);
    final groups = buildInvestigation(samples, app.limitsFor);
    if (groups.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(widget.project)), body: const SizedBox());
    }
    final g = groups[_group.clamp(0, groups.length - 1).toInt()];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Import results',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImportScreen(project: widget.project))),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (v) async {
              final name = safeName(widget.project);
              switch (v) {
                case 'pdf':
                  final bytes = await InvestigationReports.pdf(app, widget.project, samples);
                  if (context.mounted) await shareBytes(context, '${name}_investigation.pdf', bytes, 'application/pdf', subject: 'Investigation report: ${widget.project}');
                  break;
                case 'docx':
                  final bytes = WordReports.investigation(app, widget.project, samples);
                  if (context.mounted) await shareBytes(context, '${name}_investigation.docx', bytes, docxMime, subject: 'Investigation report: ${widget.project}');
                  break;
                case 'csv':
                  shareText(context, '${name}_matrix.csv', InvestigationReports.matrixCsv(app, samples), 'text/csv');
                  break;
                case 'coc':
                  final bytes = await InvestigationReports.cocSheet(app, widget.project, samples);
                  if (context.mounted) await shareBytes(context, '${name}_chain_of_custody.pdf', bytes, 'application/pdf');
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_rounded), title: Text('Report · PDF'), dense: true)),
              PopupMenuItem(value: 'docx', child: ListTile(leading: Icon(Icons.description_rounded), title: Text('Report · Word (.docx)'), dense: true)),
              PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart_rounded), title: Text('Results matrix · CSV'), dense: true)),
              PopupMenuItem(value: 'coc', child: ListTile(leading: Icon(Icons.assignment_rounded), title: Text('Chain-of-custody form · PDF'), dense: true)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (groups.length > 1) ...[
            Segmented<int>(
              values: [for (var i = 0; i < groups.length; i++) i],
              selected: _group,
              label: (i) => groups[i].solid ? 'Soil / sediment' : 'Water',
              onChanged: (i) => setState(() {
                _group = i;
                _param = null;
              }),
            ),
            const SizedBox(height: 10),
          ],
          Segmented<_View>(
            values: _View.values,
            selected: _view,
            label: (v) => switch (v) {
              _View.findings => 'Findings',
              _View.matrix => 'Matrix',
              _View.profile => 'Profile',
              _View.control => 'Control',
              _View.indices => 'Indices',
              _View.map => 'Map',
            },
            onChanged: (v) => setState(() => _view = v),
          ),
          const SizedBox(height: 14),
          switch (_view) {
            _View.findings => _findings(context, g),
            _View.matrix => _matrix(context, g),
            _View.profile => _profile(context, g),
            _View.control => _control(context, g),
            _View.indices => IndicesView(group: g),
            _View.map => _map(context, g),
          },
          const SizedBox(height: 10),
          Text(g.limits == null ? 'No standard selected' : 'Compared with ${g.limits!.name}',
              style: LBText.body(c.inkDim, size: 12)),
        ],
      ),
    );
  }

  // ---------------- Findings ----------------

  Widget _findings(BuildContext context, InvestigationGroup g) {
    final c = context.lb;
    var bad = 0;
    final badParams = <String>{};
    for (final s in g.samples) {
      for (final p in g.parameters) {
        final k = g.check(s, p).status;
        if (!g.solid && (k == Compliance.exceed || k == Compliance.belowMin)) {
          bad++;
          badParams.add(p);
        }
      }
    }
    final lines = allFindings(g);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _kpi(context, 'Samples', '${g.samples.length}', '${g.controls.length} control')),
            const SizedBox(width: 8),
            Expanded(child: _kpi(context, 'Parameters', '${g.parameters.length}', g.solid ? 'vs control' : '${badParams.length} failing')),
            const SizedBox(width: 8),
            Expanded(
              child: _kpi(
                context,
                g.solid ? 'Max PLI' : 'Out of limit',
                g.solid
                    ? (() {
                        final v = [for (final s in g.impacted) g.pli(s)].whereType<double>();
                        return v.isEmpty ? '—' : v.reduce(math.max).toStringAsFixed(2);
                      })()
                    : '$bad',
                g.solid ? 'pollution load' : 'results',
                bad: g.solid ? false : bad > 0,
              ),
            ),
          ],
        ),
        const SectionHeader('Findings (written from the data)'),
        LBCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 10),
                        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                      ),
                      Expanded(child: Text(l, style: LBText.body(c.ink, size: 13.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('The narrative is regenerated from the results every time, so it always matches the tables in the report.',
            style: LBText.body(c.inkDim, size: 12)),
        const SectionHeader('Samples'),
        for (final s in g.samples)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: LBCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.code, style: LBText.reading(14, c.ink, weight: FontWeight.w700)),
                        Text(s.site, style: LBText.body(c.inkDim, size: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (s.isControl) Tag('CONTROL', color: c.good),
                  if (!s.isControl && !g.solid)
                    () {
                      final n = g.parameters.where((p) {
                        final k = g.check(s, p).status;
                        return k == Compliance.exceed || k == Compliance.belowMin;
                      }).length;
                      return Tag(n == 0 ? 'Complies' : '$n out', color: n == 0 ? c.good : c.poor);
                    }(),
                  if (!s.isControl && g.solid && g.pli(s) != null)
                    Tag('PLI ${g.pli(s)!.toStringAsFixed(2)}', color: g.pli(s)! > 1 ? c.poor : c.good),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _kpi(BuildContext context, String label, String value, String sub, {bool bad = false}) {
    final c = context.lb;
    return LBCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelLabel(label),
          const SizedBox(height: 4),
          Text(value, style: LBText.reading(20, bad ? c.poor : c.ink, weight: FontWeight.w700)),
          Text(sub, style: LBText.body(c.inkDim, size: 11.5)),
        ],
      ),
    );
  }

  // ---------------- Matrix ----------------

  Widget _matrix(BuildContext context, InvestigationGroup g) {
    final c = context.lb;
    const cw = 78.0, pw = 150.0, rh = 34.0;
    Widget cell(String t, {Color? bg, Color? fg, bool bold = false, double w = cw, AlignmentGeometry align = Alignment.centerRight}) =>
        Container(
          width: w,
          height: rh,
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: c.line, width: 0.6))),
          child: Text(t,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: LBText.reading(11.5, fg ?? c.ink, weight: bold ? FontWeight.w700 : FontWeight.w400)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LBCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  cell('Parameter', w: pw, bold: true, bg: c.surface2, align: Alignment.centerLeft),
                  for (final s in g.samples)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s))),
                      child: cell(s.code, bold: true, bg: s.isControl ? c.good.withOpacity(0.18) : c.surface2, fg: c.accent),
                    ),
                  if (!g.solid) cell('Standard', bold: true, bg: c.surface2),
                ]),
                for (final p in g.parameters)
                  Row(children: [
                    cell(paramHeader(g, p), w: pw, align: Alignment.centerLeft),
                    for (final s in g.samples)
                      () {
                        final r = g.cell(s, p);
                        final k = g.check(s, p).status;
                        final bad = !g.solid && (k == Compliance.exceed || k == Compliance.belowMin);
                        return cell(cellText(r),
                            bg: bad ? c.poor.withOpacity(0.22) : (s.isControl ? c.good.withOpacity(0.07) : null),
                            fg: bad ? c.poor : (r?.belowLod == true ? c.inkDim : c.ink),
                            bold: bad);
                      }(),
                    if (!g.solid) cell(g.limitFor(p)?.text ?? 'NG', fg: c.inkDim),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Swipe sideways for more samples. Red: outside the standard. Green columns: controls. Tap a code to open the sample.',
            style: LBText.body(c.inkDim, size: 12)),
      ],
    );
  }

  // ---------------- Profile ----------------

  Widget _paramPicker(BuildContext context, InvestigationGroup g, List<String> options) {
    final sel = _param != null && options.contains(_param) ? _param! : options.first;
    return DropdownButtonFormField<String>(
      value: sel,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Parameter', isDense: true),
      items: [for (final p in options) DropdownMenuItem(value: p, child: Text(paramHeader(g, p)))],
      onChanged: (v) => setState(() => _param = v),
    );
  }

  Widget _profile(BuildContext context, InvestigationGroup g) {
    final c = context.lb;
    final options = g.parameters.where((p) => g.samples.any((s) => g.cell(s, p)?.value != null)).toList();
    if (options.isEmpty) return const SizedBox();
    final p = _param != null && options.contains(_param) ? _param! : options.first;
    final lim = g.solid ? null : g.limitFor(p);
    final ref = g.controlRef(p);
    final pts = <Offset>[], bad = <Offset>[], ctrl = <Offset>[];
    for (var i = 0; i < g.samples.length; i++) {
      final s = g.samples[i];
      final r = g.cell(s, p);
      if (r == null) continue;
      final v = r.belowLod ? (r.lod ?? 0) : r.value;
      if (v == null) continue;
      final o = Offset(i + 1.0, v);
      final k = g.check(s, p).status;
      if (s.isControl) {
        ctrl.add(o);
      } else if (!g.solid && (k == Compliance.exceed || k == Compliance.belowMin)) {
        bad.add(o);
      } else {
        pts.add(o);
      }
    }
    final series = <Series>[
      if (lim?.max != null) FnSeries((_) => lim!.max!, c.poor, label: 'limit ${lim!.text}', strokeWidth: 1.4),
      if (lim?.min != null) FnSeries((_) => lim!.min!, c.fair, label: 'min ${fmtValue(lim!.min!)}', strokeWidth: 1.4),
      if (ref != null) FnSeries((_) => ref.value, c.good, label: 'control', strokeWidth: 1.2),
      PointSeries([...pts, ...bad]..sort((a, b) => a.dx.compareTo(b.dx)), c.accent.withOpacity(0.5), line: true, dots: false, strokeWidth: 1.2),
      if (pts.isNotEmpty) PointSeries(pts, c.accent, line: false, dots: true, dotRadius: 5, label: 'sample'),
      if (bad.isNotEmpty) PointSeries(bad, c.poor, line: false, dots: true, dotRadius: 5, label: 'out of limit'),
      if (ctrl.isNotEmpty) PointSeries(ctrl, c.good, line: false, dots: true, dotRadius: 5),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _paramPicker(context, g, options),
        const SizedBox(height: 12),
        PlotView(height: 260, xLabel: 'sample (sequence)', yLabel: g.unitFor(p), series: series, xMin: 0.5, xMax: g.samples.length + 0.5),
        const SizedBox(height: 6),
        PlotLegend(series),
        const SizedBox(height: 10),
        ResultTable(
          columns: const ['#', 'Sample', 'Value', 'vs control'],
          rows: [
            for (var i = 0; i < g.samples.length; i++)
              [
                '${i + 1}',
                g.samples[i].code,
                cellText(g.cell(g.samples[i], p)),
                g.samples[i].isControl ? 'control' : (g.factor(g.samples[i], p) == null ? '—' : '${g.factor(g.samples[i], p)!.toStringAsFixed(1)}×'),
              ]
          ],
        ),
      ],
    );
  }

  // ---------------- Control comparison ----------------

  Widget _control(BuildContext context, InvestigationGroup g) {
    final c = context.lb;
    if (g.controls.isEmpty) {
      return LBCard(
        child: Text('No control sample in this group. Open an upstream / off-site sample, tap Edit, and switch on '
            '"Control / background sample".', style: LBText.body(c.inkDim, size: 13)),
      );
    }
    final imp = g.impacted;
    final params = g.parameters.where((p) => imp.any((s) => g.factor(s, p) != null)).toList();
    Color tone(double f) => f >= 6 ? c.poor : (f >= 3 ? c.fair : (f >= 1 ? c.fair.withOpacity(0.55) : c.good));
    const cw = 66.0, pw = 140.0, rh = 32.0;
    Widget cell(String t, {Color? bg, Color? fg, bool bold = false, double w = cw, AlignmentGeometry align = Alignment.centerRight}) =>
        Container(
          width: w,
          height: rh,
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: c.line, width: 0.6))),
          child: Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: LBText.reading(11.5, fg ?? c.ink, weight: bold ? FontWeight.w700 : FontWeight.w400)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(g.solid ? 'Contamination factor CF = sample ÷ control' : 'Enrichment factor = sample ÷ control',
            style: LBText.body(c.ink, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Control: ${g.controls.map((s) => s.code).join(', ')}. Classes: <1 low · 1–3 moderate · 3–6 considerable · ≥6 very high.',
            style: LBText.body(c.inkDim, size: 12)),
        const SizedBox(height: 10),
        LBCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  cell('Parameter', w: pw, bold: true, bg: c.surface2, align: Alignment.centerLeft),
                  cell('Control', bold: true, bg: c.good.withOpacity(0.18)),
                  for (final s in imp) cell(s.code, bold: true, bg: c.surface2, fg: c.accent),
                ]),
                for (final p in params)
                  Row(children: [
                    cell(paramHeader(g, p), w: pw, align: Alignment.centerLeft),
                    cell(() {
                      final ref = g.controlRef(p);
                      return ref == null ? '—' : '${ref.nonDetect ? '<' : ''}${fmtValue(ref.value)}';
                    }(), fg: c.inkDim),
                    for (final s in imp)
                      () {
                        final f = g.factor(s, p);
                        return f == null
                            ? cell('—', fg: c.inkDim)
                            : cell(f.toStringAsFixed(f >= 10 ? 0 : 1), bg: tone(f).withOpacity(0.22), fg: f >= 6 ? c.poor : c.ink, bold: f >= 3);
                      }(),
                  ]),
                if (g.solid)
                  Row(children: [
                    cell('Pollution load index', w: pw, bold: true, align: Alignment.centerLeft),
                    cell(''),
                    for (final s in imp)
                      () {
                        final v = g.pli(s);
                        return cell(v == null ? '—' : v.toStringAsFixed(2), bold: true, fg: v != null && v > 1 ? c.poor : c.good);
                      }(),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
            'A control below detection is replaced by its detection limit, so these factors are conservative (real enrichment may be higher).'
            '${g.solid ? ' PLI is the geometric mean of the CFs; above 1 indicates pollution.' : ''}',
            style: LBText.body(c.inkDim, size: 12)),
      ],
    );
  }

  // ---------------- Map ----------------

  Widget _map(BuildContext context, InvestigationGroup g) {
    final c = context.lb;
    final located = g.samples.where((s) => s.lat != null && s.lon != null).toList();
    if (located.isEmpty) {
      return LBCard(child: Text('No coordinates recorded for these samples.', style: LBText.body(c.inkDim, size: 13)));
    }
    final options = g.parameters.where((p) => g.samples.any((s) => g.cell(s, p)?.value != null)).toList();
    final p = options.isEmpty ? null : (_param != null && options.contains(_param) ? _param! : options.first);
    final ctrl = <Offset>[], bad = <Offset>[], ok = <Offset>[];
    final rows = <List<String>>[];
    for (final s in located) {
      final u = toUtm(s.lat!, s.lon!, zone: 29);
      final o = Offset(u.easting, u.northing);
      final k = p == null ? Compliance.missing : g.check(s, p).status;
      final isBad = !g.solid && (k == Compliance.exceed || k == Compliance.belowMin) ||
          (g.solid && p != null && (g.factor(s, p) ?? 0) >= 3);
      if (s.isControl) {
        ctrl.add(o);
      } else if (isBad) {
        bad.add(o);
      } else {
        ok.add(o);
      }
      rows.add([s.code, u.easting.toStringAsFixed(0), u.northing.toStringAsFixed(0), p == null ? '' : cellText(g.cell(s, p))]);
    }
    final series = <Series>[
      if (ok.isNotEmpty) MarkerSeries(ok, c.accent, label: g.solid ? 'CF < 3' : 'complies'),
      if (bad.isNotEmpty) MarkerSeries(bad, c.poor, label: g.solid ? 'CF ≥ 3' : 'out of limit'),
      if (ctrl.isNotEmpty) MarkerSeries(ctrl, c.good, label: 'control'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p != null) _paramPicker(context, g, options),
        const SizedBox(height: 12),
        PlotView(height: 320, equalAspect: true, xLabel: 'Easting (m)', yLabel: 'Northing (m)', series: series),
        const SizedBox(height: 6),
        PlotLegend(series),
        const SizedBox(height: 10),
        ResultTable(columns: ['Sample', 'X (29N)', 'Y (29N)', if (p != null) p], rows: rows),
      ],
    );
  }
}
