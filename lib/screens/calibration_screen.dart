import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/calibration.dart';
import '../core/guidelines.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/plot.dart';

class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final runs = [...app.runs]..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      appBar: AppBar(title: const Text('Calibration')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalibrationEditScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New curve'),
      ),
      body: runs.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.show_chart_rounded,
                title: 'No calibration curves',
                body: 'Enter your standards to get the fitted line, r², LOD and LOQ, then convert instrument readings to concentrations.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: runs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = runs[i];
                CalFit? fit;
                try {
                  fit = fitCalibration(r.standards, throughOrigin: r.throughOrigin);
                } catch (_) {}
                final ok = fit != null && fit.r2 >= app.settings.r2Min;
                return LBCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CalibrationEditScreen(run: r))),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: (ok ? c.good : c.poor).withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                        child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: ok ? c.good : c.poor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.parameter.isEmpty ? 'Unnamed curve' : r.parameter, style: LBText.body(c.ink, size: 15, weight: FontWeight.w700)),
                            Text('${shortDate(r.date)} · ${r.standards.length} standards${r.method.isEmpty ? '' : ' · ${r.method}'}',
                                style: LBText.body(c.inkDim, size: 12.5)),
                          ],
                        ),
                      ),
                      Text(fit == null ? '—' : 'r² ${fit.r2.toStringAsFixed(4)}', style: LBText.reading(13, ok ? c.good : c.poor, weight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class CalibrationEditScreen extends StatefulWidget {
  final CalibrationRun? run;
  const CalibrationEditScreen({super.key, this.run});

  @override
  State<CalibrationEditScreen> createState() => _CalibrationEditScreenState();
}

class _CalibrationEditScreenState extends State<CalibrationEditScreen> {
  late CalibrationRun _run;
  late bool _isNew;
  final _param = TextEditingController();
  final _method = TextEditingController();
  final _instrument = TextEditingController();
  final _analyst = TextEditingController();
  final _stds = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.read(context);
    _isNew = widget.run == null;
    _run = widget.run ??
        CalibrationRun(
          id: newId(),
          parameter: '',
          analyst: app.settings.analyst,
          standards: [
            [0, 0],
            [0.5, 0.0],
            [1, 0.0],
            [2, 0.0],
            [4, 0.0],
          ],
        );
    _param.text = _run.parameter;
    _method.text = _run.method;
    _instrument.text = _run.instrument;
    _analyst.text = _run.analyst;
    _stds.text = _isNew && widget.run == null
        ? ''
        : [for (final s in _run.standards) '${_num(s[0])}  ${_num(s[1])}'].join('\n');
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _sync() {
    final p = parseXY(_stds.text);
    _run.standards = [for (var i = 0; i < p.x.length; i++) [p.x[i], p.y[i]]];
    _run.parameter = _param.text.trim();
    _run.method = _method.text.trim();
    _run.instrument = _instrument.text.trim();
    _run.analyst = _analyst.text.trim();
  }

  void _save() {
    final app = AppScope.read(context);
    _sync();
    app.update(() {
      if (_isNew) {
        app.runs.add(_run);
        _isNew = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calibration saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    _sync();
    CalFit? fit;
    String? error;
    try {
      fit = fitCalibration(_run.standards, throughOrigin: _run.throughOrigin);
    } on CalError catch (e) {
      error = e.message;
    }
    final ok = fit != null && fit.r2 >= app.settings.r2Min;
    final xs = _run.standards.map((s) => s[0]).toList();
    final maxStd = xs.isEmpty ? 0.0 : xs.reduce(math.max);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New calibration' : 'Calibration'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                app.update(() => app.runs.remove(_run));
                Navigator.pop(context);
              },
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
          children: [
            TextField(
              controller: _param,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Parameter', hintText: 'e.g. Lead (Pb)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: units.contains(_run.unit) ? _run.unit : 'mg/L',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Concentration unit', isDense: true),
                    items: [for (final u in units.where((u) => u.isNotEmpty)) DropdownMenuItem(value: u, child: Text(u))],
                    onChanged: (u) => setState(() => _run.unit = u ?? _run.unit),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _instrument, decoration: const InputDecoration(labelText: 'Instrument', isDense: true))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _method, decoration: const InputDecoration(labelText: 'Method / wavelength', isDense: true))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _analyst, decoration: const InputDecoration(labelText: 'Analyst', isDense: true))),
              ],
            ),
            const SectionHeader('Standards'),
            TextField(
              controller: _stds,
              onChanged: (_) => setState(() {}),
              minLines: 5,
              maxLines: 12,
              style: LBText.reading(14, c.ink),
              decoration: InputDecoration(
                hintText: '0  0.001\n0.5  0.021\n1  0.043\n2  0.085\n4  0.170',
                helperText: 'One standard per line: concentration (${_run.unit})  then  response (absorbance, counts…)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _run.throughOrigin,
              onChanged: (v) => setState(() => _run.throughOrigin = v),
              title: const Text('Force through origin'),
              subtitle: const Text('Use only if the blank is subtracted and the method is known to be proportional.'),
            ),
            const SizedBox(height: 8),
            if (error != null)
              ResultCard(label: 'Curve', value: 'Not enough data', sub: error, ok: false)
            else if (fit != null) ...[
              ResultCard(
                label: ok ? 'Calibration accepted' : 'Calibration rejected',
                value: fit.equation,
                ok: ok,
                sub: 'r² = ${fit.r2.toStringAsFixed(5)}  (accept ≥ ${app.settings.r2Min})   r = ${fit.r.toStringAsFixed(5)}\n'
                    'sy/x = ${fmtValue(fit.syx)}   LOD = ${fmtValue(fit.lod)} ${_run.unit}   LOQ = ${fmtValue(fit.loq)} ${_run.unit}',
              ),
              Section(
                'Curve',
                child: PlotView(
                  xMin: 0,
                  xMax: maxStd * 1.1 + 1e-9,
                  xLabel: 'concentration (${_run.unit})',
                  series: [
                    FnSeries(fit.response, c.accent, label: 'fit'),
                    PointSeries([for (final s in _run.standards) Offset(s[0], s[1])], seriesColors[1], line: false, dots: true, label: 'standards'),
                    if (_run.readings.isNotEmpty)
                      MarkerSeries([for (final r in _run.readings) Offset(fit.conc(r.response), r.response)], seriesColors[3]),
                  ],
                ),
              ),
              Section(
                'Back-calculated standards',
                child: ResultTable(
                  columns: const ['Std', 'Response', 'Found', 'Deviation %'],
                  rows: [
                    for (final s in _run.standards)
                      [
                        fmtValue(s[0]),
                        fmtValue(s[1]),
                        fmtValue(fit.conc(s[1])),
                        s[0] == 0 ? '—' : ((fit.conc(s[1]) - s[0]) / s[0] * 100).toStringAsFixed(1),
                      ]
                  ],
                ),
              ),
              _Unknowns(run: _run, fit: fit, maxStd: maxStd, onChanged: () => setState(() {})),
            ],
          ],
        ),
      ),
    );
  }
}

class _Unknowns extends StatefulWidget {
  final CalibrationRun run;
  final CalFit fit;
  final double maxStd;
  final VoidCallback onChanged;
  const _Unknowns({required this.run, required this.fit, required this.maxStd, required this.onChanged});

  @override
  State<_Unknowns> createState() => _UnknownsState();
}

class _UnknownsState extends State<_Unknowns> {
  final _resp = TextEditingController();
  final _dil = TextEditingController(text: '1');
  String _sampleId = '';

  void _add() {
    final r = double.tryParse(_resp.text.trim());
    if (r == null) return;
    final app = AppScope.read(context);
    app.update(() {
      widget.run.readings.add(CalReading(
        sampleId: _sampleId,
        label: app.sampleById(_sampleId)?.code ?? 'Unknown ${widget.run.readings.length + 1}',
        response: r,
        dilution: double.tryParse(_dil.text.trim()) ?? 1,
      ));
    });
    _resp.clear();
    widget.onChanged();
  }

  void _saveToSample(CalReading rd) {
    final app = AppScope.read(context);
    final s = app.sampleById(rd.sampleId);
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a registered sample for this reading first.')));
      return;
    }
    final conc = widget.fit.conc(rd.response) * rd.dilution;
    final lod = widget.fit.lod * rd.dilution;
    final below = conc < lod;
    app.update(() {
      s.results.removeWhere((r) => normKey(r.parameter) == normKey(widget.run.parameter) && r.source == 'calibration');
      s.results.add(Result(
        id: newId(),
        parameter: widget.run.parameter,
        value: below ? null : double.parse(conc.toStringAsPrecision(4)),
        belowLod: below,
        lod: double.parse(lod.toStringAsPrecision(3)),
        unit: widget.run.unit,
        method: [widget.run.instrument, widget.run.method].where((x) => x.isNotEmpty).join(' '),
        analyst: widget.run.analyst,
        dilution: rd.dilution,
        source: 'calibration',
        note: rd.dilution != 1 ? 'Dilution factor ${_trim(rd.dilution)}' : '',
      ));
      if (s.status.index < SampleStatus.inAnalysis.index) s.status = SampleStatus.inAnalysis;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${s.code}.')));
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final fit = widget.fit;
    final topResp = fit.response(widget.maxStd);
    return Section(
      'Samples: response → concentration',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _sampleId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Sample', isDense: true),
            items: [
              const DropdownMenuItem(value: '', child: Text('Unregistered unknown')),
              for (final s in app.samples) DropdownMenuItem(value: s.id, child: Text('${s.code} · ${s.site}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _sampleId = v ?? ''),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _resp,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: LBText.reading(15, c.ink),
                  decoration: const InputDecoration(labelText: 'Instrument response', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _dil,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: LBText.reading(15, c.ink),
                  decoration: const InputDecoration(labelText: 'Dilution ×', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _add, icon: const Icon(Icons.add_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          for (final rd in widget.run.readings)
            () {
              final inSol = fit.conc(rd.response);
              final conc = inSol * rd.dilution;
              final above = rd.response > topResp;
              final below = inSol < fit.lod;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LBCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rd.label, style: LBText.body(c.ink, weight: FontWeight.w700, size: 14)),
                            Text('response ${fmtValue(rd.response)} · ×${_trim(rd.dilution)}', style: LBText.reading(11.5, c.inkDim)),
                            if (above)
                              Text('Above the top standard: dilute and re-run', style: LBText.body(c.fair, size: 11.5)),
                            if (below) Text('Below LOD', style: LBText.body(c.accent, size: 11.5)),
                          ],
                        ),
                      ),
                      Text(below ? '< ${fmtValue(fit.lod * rd.dilution)}' : fmtValue(conc),
                          style: LBText.reading(15, c.ink, weight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Text(widget.run.unit, style: LBText.body(c.inkDim, size: 12)),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'save') _saveToSample(rd);
                          if (v == 'del') {
                            app.update(() => widget.run.readings.remove(rd));
                            widget.onChanged();
                          }
                        },
                        itemBuilder: (_) => [
                          if (rd.sampleId.isNotEmpty) const PopupMenuItem(value: 'save', child: Text('Save result to sample')),
                          const PopupMenuItem(value: 'del', child: Text('Remove')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }(),
          if (widget.run.readings.isNotEmpty)
            Text('Concentration = (response − intercept) / slope × dilution. Save the run to keep these readings.',
                style: LBText.body(c.inkDim, size: 12)),
        ],
      ),
    );
  }
}
