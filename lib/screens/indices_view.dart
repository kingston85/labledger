import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/indices.dart';
import '../core/investigation.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';

/// Pollution-index tables for one investigation group.
class IndicesView extends StatelessWidget {
  final InvestigationGroup group;
  const IndicesView({super.key, required this.group});

  Color _tone(LBColors c, int sev) => switch (sev) { 0 => c.good, 1 => c.good.withOpacity(0.7), 2 => c.fair, 3 => Color.lerp(c.fair, c.poor, 0.5)!, _ => c.poor };

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final g = group;
    final idx = computeIndices(g);
    const cw = 92.0, sw = 120.0, rh = 44.0;
    Widget cell(Widget child, {double w = cw, Color? bg, Alignment align = Alignment.center}) => Container(
          width: w,
          height: rh,
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: c.line, width: 0.6))),
          child: child,
        );
    Widget head(String t, {double w = cw}) => cell(Text(t, textAlign: TextAlign.center, style: LBText.label(c.inkDim, size: 10)), w: w, bg: c.surface2);
    Widget val(Indexed? x) {
      if (x == null) return cell(Text('—', style: LBText.reading(12, c.inkDim)));
      final col = _tone(c, x.severity);
      return cell(
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(x.value.toStringAsFixed(x.value.abs() >= 100 ? 0 : 1), style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
          Text(x.cls, maxLines: 1, overflow: TextOverflow.ellipsis, style: LBText.body(col, size: 9.5, weight: FontWeight.w700)),
        ]),
        bg: col.withOpacity(0.12),
      );
    }

    Widget sampleCell(SampleIndices e) => cell(
          Text('${e.sample.code}${e.sample.isControl ? '\n(control)' : ''}', style: LBText.reading(11.5, e.sample.isControl ? c.good : c.accent, weight: FontWeight.w700)),
          w: sw,
          align: Alignment.centerLeft,
        );

    Widget scroll(List<Widget> rows) => LBCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows)),
        );

    if (!g.solid) {
      final any = idx.any((e) => e.wqi != null || e.hpi != null || e.nemerow != null);
      if (!any) {
        return LBCard(child: Text('Indices need results with limits in the selected standard (at least 3 parameters for WQI).', style: LBText.body(c.inkDim, size: 13)));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        scroll([
          Row(children: [head('SAMPLE', w: sw), head('WQI'), head('HPI'), head('HEI'), head('Cd'), head('NEMEROW')]),
          for (final e in idx) Row(children: [sampleCell(e), val(e.wqi), val(e.hpi), val(e.hei), val(e.cd), val(e.nemerow)]),
        ]),
        const SizedBox(height: 12),
        _Explain(lines: const [
          ('WQI', 'Weighted arithmetic water quality index (Brown et al. 1972). Wi = K/Si, Qi = 100·(Vi−V0)/(Si−V0); V0 = 7 for pH, 0 otherwise. ≤25 excellent · 26–50 good · 51–75 poor · 76–100 very poor · >100 unsuitable for drinking.'),
          ('HPI', 'Heavy-metal pollution index (Mohan et al. 1996) over metals with a limit, Wi = 1/Si, Qi = 100·Mi/Si. Critical value 100.'),
          ('HEI', 'Heavy-metal evaluation index = Σ Mi/Si (Edet & Offiong 2002). <10 low · 10–20 medium · >20 high.'),
          ('Cd', 'Contamination index = Σ (Mi/Si − 1) (Backman et al. 1998). <1 low · 1–3 medium · >3 high.'),
          ('Nemerow', '√((Pmax² + Pmean²)/2), Pi = Ci/Si over all limited parameters except pH. ≤0.7 clean · ≤1 warning · ≤2 slight · ≤3 moderate · >3 heavy.'),
          ('Note', 'Non-detects are taken as half the detection limit. Indices use the limits of the selected standard.'),
        ]),
      ]);
    }

    // Soil / sediment.
    if (g.controls.isEmpty) {
      return LBCard(child: Text('Soil indices compare with a background. Mark an off-site sample as the control (Edit sample → Control).', style: LBText.body(c.inkDim, size: 13)));
    }
    final metals = g.parameters.where((p) => idx.any((e) => e.igeo.containsKey(p))).toList();
    final erParams = g.parameters.where((p) => idx.any((e) => e.er.containsKey(p))).toList();
    final imp = idx.where((e) => !e.sample.isControl).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      scroll([
        Row(children: [head('SAMPLE', w: sw), head('PLI'), head('Cdeg'), head('RI')]),
        for (final e in imp) Row(children: [sampleCell(e), val(e.pli), val(e.cdeg), val(e.ri)]),
      ]),
      const SectionHeader('Geo-accumulation index (Igeo)'),
      scroll([
        Row(children: [head('PARAMETER', w: sw), for (final e in imp) head(e.sample.code)]),
        for (final p in metals)
          Row(children: [
            cell(Text(p, style: LBText.body(c.ink, size: 12), maxLines: 2), w: sw, align: Alignment.centerLeft),
            for (final e in imp)
              () {
                final v = e.igeo[p];
                if (v == null) return cell(Text('—', style: LBText.reading(12, c.inkDim)));
                final col = _tone(c, igeoSeverity(v));
                return cell(
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(v.toStringAsFixed(2), style: LBText.reading(12.5, c.ink, weight: FontWeight.w700)),
                    Text(igeoClass(v).split(' · ').first, style: LBText.body(col, size: 9.5, weight: FontWeight.w700)),
                  ]),
                  bg: col.withOpacity(0.12),
                );
              }(),
          ]),
      ]),
      if (erParams.isNotEmpty) ...[
        const SectionHeader('Ecological risk factor (Er)'),
        scroll([
          Row(children: [head('PARAMETER', w: sw), for (final e in imp) head(e.sample.code)]),
          for (final p in erParams)
            Row(children: [
              cell(Text('$p · Tr ${toxicResponse[paramKey(p)]?.toStringAsFixed(0) ?? ''}', style: LBText.body(c.ink, size: 12), maxLines: 2), w: sw, align: Alignment.centerLeft),
              for (final e in imp) e.er[p] == null ? cell(Text('—', style: LBText.reading(12, c.inkDim))) : val(erClass(e.er[p]!)),
            ]),
        ]),
      ],
      const SizedBox(height: 12),
      _Explain(lines: [
        ('Background', 'Control sample${g.controls.length == 1 ? '' : 's'} ${g.controls.map((s) => s.code).join(', ')} (mean). Crustal averages can be used instead in formal studies.'),
        ('Igeo', 'log2(Cn / 1.5·Bn) (Müller 1969). Class 0 ≤0 unpolluted · 1 ≤1 · 2 ≤2 moderate · 3 ≤3 · 4 ≤4 heavy · 5 ≤5 · 6 >5 extreme.'),
        ('Er / RI', 'Er = Tr × CF, RI = Σ Er (Håkanson 1980). Tr: Hg 40, Cd 30, As 10, Pb/Cu/Ni 5, Cr 2, Zn/Mn 1. RI <150 low · 150–300 moderate · 300–600 considerable · ≥600 very high.'),
        ('Cdeg / PLI', 'Cdeg = Σ CF (bands scaled to the number of metals). PLI = geometric mean of CF; >1 polluted.'),
      ]),
    ]);
  }

}

class _Explain extends StatelessWidget {
  final List<(String, String)> lines;
  const _Explain({required this.lines});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return LBCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: RichText(
              text: TextSpan(style: LBText.body(c.inkDim, size: 12), children: [
                TextSpan(text: '${l.$1}  ', style: LBText.body(c.ink, size: 12, weight: FontWeight.w700)),
                TextSpan(text: l.$2),
              ]),
            ),
          ),
      ]),
    );
  }
}
