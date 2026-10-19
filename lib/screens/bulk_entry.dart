import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/panels.dart';

/// Enter a whole parameter panel (field readings, metals suite…) for a sample
/// in one sheet. Each box takes a value, "<LOD", or replicate readings.
Future<void> showBulkEntry(BuildContext context, Sample sample) {
  return openPage(context, _BulkEntryScreen(sample: sample));
}

class _BulkEntryScreen extends StatefulWidget {
  final Sample sample;
  const _BulkEntryScreen({required this.sample});

  @override
  State<_BulkEntryScreen> createState() => _BulkEntryScreenState();
}

class _BulkEntryScreenState extends State<_BulkEntryScreen> {
  int _panel = 0;
  bool _fahrenheit = false;
  final Map<String, TextEditingController> _ctrl = {};
  final _method = TextEditingController();

  TextEditingController _c(String p) => _ctrl.putIfAbsent(p, () {
        final r = _existing(p);
        String text = '';
        if (r != null) {
          if (r.belowLod) {
            text = r.lod != null ? '<${fmtValue(r.lod!)}' : '<';
          } else if (r.replicates.length > 1) {
            text = r.replicates.map(fmtValue).join(' ');
          } else if (r.value != null) {
            text = fmtValue(r.value!);
          }
        }
        return TextEditingController(text: text);
      });

  Result? _existing(String p) {
    final k = paramKey(p);
    for (final r in widget.sample.results) {
      if (paramKey(r.parameter) == k) return r;
    }
    return null;
  }

  String _unitFor(String p) {
    final u = commonParameters[p] ?? 'mg/L';
    if (widget.sample.matrix.isSolid && u == 'mg/L') return 'mg/kg';
    return u;
  }

  int _filled() => _ctrl.values.where((c) => c.text.trim().isNotEmpty).length;

  void _save() {
    final app = AppScope.read(context);
    var n = 0;
    app.update(() {
      for (final e in _ctrl.entries) {
        final text = e.value.text.trim();
        final existing = _existing(e.key);
        if (text.isEmpty) continue;
        final pv = parseResultText(text);
        if (pv.isEmpty) continue;
        var value = pv.value;
        var reps = pv.replicates;
        var unit = _unitFor(e.key);
        if (e.key == 'Temperature' && _fahrenheit && value != null) {
          value = fahrenheitToCelsius(value);
          reps = reps.map(fahrenheitToCelsius).toList();
          unit = '°C';
        }
        final r = existing ?? Result(id: newId(), parameter: e.key);
        r.value = pv.belowLod ? null : value;
        r.belowLod = pv.belowLod;
        r.lod = pv.belowLod ? pv.lod : r.lod;
        r.replicates = pv.belowLod ? [] : reps;
        r.unit = existing?.unit.isNotEmpty == true && e.key != 'Temperature' ? existing!.unit : unit;
        final m = _method.text.trim();
        if (m.isNotEmpty) {
          r.method = m;
        } else if (r.method.isEmpty) {
          r.method = defaultMethods[e.key] ?? '';
        }
        if (r.analyst.isEmpty) r.analyst = app.settings.analyst;
        if (e.key == 'Temperature' && _fahrenheit && !r.note.contains('°F')) {
          r.note = [r.note, 'converted from °F'].where((x) => x.isNotEmpty).join('; ');
        }
        if (existing == null) widget.sample.results.add(r);
        n++;
      }
      if (n > 0 && widget.sample.status.index < SampleStatus.inAnalysis.index) {
        widget.sample.status = SampleStatus.inAnalysis;
      }
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n result${n == 1 ? '' : 's'} saved to ${widget.sample.code}')));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final panel = parameterPanels[_panel];
    final set = app.limitsFor(widget.sample);
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel · ${widget.sample.code}'),
        actions: [TextButton(onPressed: _save, child: Text('Save (${_filled()})'))],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < parameterPanels.length; i++)
                  ChoiceChip(
                    label: Text(parameterPanels[i].name),
                    selected: _panel == i,
                    onSelected: (_) => setState(() => _panel = i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${panel.hint}. Enter a value, "<0.001" for not detected, or triplicate readings separated by spaces.',
                style: LBText.body(c.inkDim, size: 12.5)),
            const SizedBox(height: 10),
            TextField(
              controller: _method,
              decoration: const InputDecoration(
                labelText: 'Method / instrument override (optional)',
                helperText: 'Blank = the standard method for each parameter',
                isDense: true,
              ),
            ),
            if (panel.parameters.contains('Temperature'))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _fahrenheit,
                onChanged: (v) => setState(() => _fahrenheit = v),
                title: const Text('Temperature read in °F'),
                subtitle: const Text('Converted to °C when saved'),
              ),
            const SizedBox(height: 6),
            for (final p in panel.parameters)
              Builder(builder: (context) {
                final ctrl = _c(p);
                final pv = parseResultText(ctrl.text);
                final unit = p == 'Temperature' && _fahrenheit ? '°F' : _unitFor(p);
                var v = pv.value;
                if (p == 'Temperature' && _fahrenheit && v != null) v = fahrenheitToCelsius(v);
                final chk = checkResult(
                    Result(id: 'p', parameter: p, value: v, belowLod: pv.belowLod, unit: p == 'Temperature' ? '°C' : unit), set);
                final lim = set == null ? null : findLimit(set, p);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p, style: LBText.body(c.ink, size: 13.5, weight: FontWeight.w700)),
                            Text(
                              [
                                if (unit.isNotEmpty) unit,
                                if (lim != null) 'limit ${lim.text}',
                                if (pv.replicates.length > 1) 'mean of ${pv.replicates.length}',
                              ].join(' · '),
                              style: LBText.body(c.inkDim, size: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: ctrl,
                          onChanged: (_) => setState(() {}),
                          style: LBText.reading(14.5, c.ink, weight: FontWeight.w600),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '—',
                            suffixIcon: ctrl.text.trim().isEmpty
                                ? null
                                : Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      chk.status == Compliance.exceed || chk.status == Compliance.belowMin
                                          ? Icons.error_rounded
                                          : chk.status == Compliance.pass || chk.status == Compliance.belowLod
                                              ? Icons.check_circle_rounded
                                              : Icons.remove_circle_outline_rounded,
                                      size: 18,
                                      color: chk.status == Compliance.exceed || chk.status == Compliance.belowMin
                                          ? c.poor
                                          : chk.status == Compliance.pass || chk.status == Compliance.belowLod
                                              ? c.good
                                              : c.inkDim,
                                    ),
                                  ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: Text('Save ${_filled()} results')),
            const SizedBox(height: 6),
            Text('Values entered on other panels are kept when you switch.', style: LBText.body(c.inkDim, size: 12)),
          ],
        ),
      ),
    );
  }
}
