import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import 'calibration_screen.dart';
import 'qc_screen.dart';
import 'sample_detail_screen.dart';
import 'sample_form_screen.dart';
import 'samples_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final pending = app.samples.where((s) => s.status != SampleStatus.reported).length;
    final exceed = app.exceedances;
    final qcFail = app.qc.where((q) => !app.qcPasses(q)).length;
    final month = DateTime.now();
    final thisMonth = app.samples.where((s) => s.collectedAt.year == month.year && s.collectedAt.month == month.month).length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 128,
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('LAB', style: LBText.label(c.ink, size: 16)),
                  Text('LEDGER', style: LBText.label(c.accent, size: 16)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(app.settings.labName, style: LBText.body(c.inkDim, size: 13)),
                if (app.hasDemo) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.accent.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: c.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Demo data is loaded so you can explore. Remove it any time under More.',
                              style: LBText.body(c.ink, size: 13)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.7,
                  children: [
                    _Kpi(label: 'Samples', value: '${app.samples.length}', sub: '$thisMonth this month', icon: Icons.science_rounded,
                        color: c.accent, onTap: () => _tab(context, 1)),
                    _Kpi(label: 'Open', value: '$pending', sub: 'not yet reported', icon: Icons.pending_actions_rounded,
                        color: c.fair, onTap: () => _tab(context, 1)),
                    _Kpi(label: 'Exceedances', value: '${exceed.length}', sub: 'results over limits', icon: Icons.warning_amber_rounded,
                        color: exceed.isEmpty ? c.good : c.poor),
                    _Kpi(label: 'QC failures', value: '$qcFail', sub: 'of ${app.qc.length} checks', icon: Icons.rule_rounded,
                        color: qcFail == 0 ? c.good : c.poor, onTap: () => _tab(context, 3)),
                  ],
                ),
                const SectionHeader('Quick actions'),
                Row(
                  children: [
                    Expanded(
                      child: _Action(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'New sample',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SampleFormScreen())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Action(
                        icon: Icons.show_chart_rounded,
                        label: 'Calibrate',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalibrationEditScreen())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Action(
                        icon: Icons.verified_outlined,
                        label: 'Record QC',
                        onTap: () => showQcForm(context),
                      ),
                    ),
                  ],
                ),
                const SectionHeader('Sample pipeline'),
                _Pipeline(samples: app.samples),
                if (exceed.isNotEmpty) ...[
                  const SectionHeader('Exceedances'),
                  for (final (s, r, chk) in exceed.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LBCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        borderColor: c.poor.withOpacity(0.4),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s))),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: c.poor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${r.parameter} · ${s.code}', style: LBText.body(c.ink, weight: FontWeight.w700, size: 14)),
                                  Text(s.site, style: LBText.body(c.inkDim, size: 12.5), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${resultText(r)} ${r.unit}', style: LBText.reading(13.5, c.poor, weight: FontWeight.w700)),
                                Text(
                                  chk.factor != null ? '${chk.factor!.toStringAsFixed(1)}× limit' : (chk.limit?.text ?? ''),
                                  style: LBText.body(c.inkDim, size: 11.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SectionHeader('Recent samples'),
                if (app.samples.isEmpty)
                  const EmptyState(
                    icon: Icons.science_outlined,
                    title: 'No samples yet',
                    body: 'Register your first sample to start tracking results and chain of custody.',
                  )
                else
                  for (final s in app.samples.take(5))
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: SampleTile(sample: s)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static void _tab(BuildContext context, int i) => context.findAncestorStateOfType<ShellState>()?.go(i);
}

class _Kpi extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _Kpi({required this.label, required this.value, required this.sub, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return LBCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(child: PanelLabel(label)),
          ]),
          const Spacer(),
          Text(value, style: LBText.reading(26, c.ink, weight: FontWeight.w700)),
          Text(sub, style: LBText.body(c.inkDim, size: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return Material(
      color: c.accent.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: c.accent, size: 26),
              const SizedBox(height: 6),
              Text(label, style: LBText.body(c.ink, size: 13, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pipeline extends StatelessWidget {
  final List<Sample> samples;
  const _Pipeline({required this.samples});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final total = samples.isEmpty ? 1 : samples.length;
    final colors = [c.inkDim, c.accent, c.fair, const Color(0xFFB57BFF), c.good];
    return LBCard(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final st in SampleStatus.values)
                    if (samples.any((s) => s.status == st))
                      Expanded(
                        flex: samples.where((s) => s.status == st).length * 100 ~/ total + 1,
                        child: Container(color: colors[st.index]),
                      ),
                  if (samples.isEmpty) Expanded(child: Container(color: c.surface2)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final st in SampleStatus.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[st.index], shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${st.label} ${samples.where((s) => s.status == st).length}', style: LBText.body(c.inkDim, size: 12.5)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Coloured chip for compliance status.
class ComplianceChip extends StatelessWidget {
  final Compliance status;
  const ComplianceChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final color = switch (status) {
      Compliance.pass => c.good,
      Compliance.exceed || Compliance.belowMin => c.poor,
      Compliance.belowLod => c.accent,
      Compliance.unitMismatch => c.fair,
      _ => c.inkDim,
    };
    return Tag(complianceLabel(status), color: color);
  }
}
