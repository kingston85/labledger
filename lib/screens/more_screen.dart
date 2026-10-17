import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/share.dart';
import 'stats_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            padding: EdgeInsets.zero,
            onTap: onTap,
            child: ListTile(
              leading: Icon(icon, color: color ?? c.accent),
              title: Text(title, style: LBText.body(c.ink, weight: FontWeight.w700)),
              subtitle: Text(sub, style: LBText.body(c.inkDim, size: 12.5)),
              trailing: Icon(Icons.chevron_right_rounded, color: c.inkDim),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          tile(Icons.functions_rounded, 'Statistics', 'Descriptives, t-tests, ANOVA, Grubbs outlier test',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen()))),
          tile(Icons.rule_folder_outlined, 'Limit sets', 'WHO drinking water and your own standards',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LimitSetsScreen()))),
          tile(Icons.settings_rounded, 'Settings', 'Lab name, analyst, sample IDs, QC acceptance limits',
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          const SectionHeader('Export'),
          tile(Icons.table_chart_rounded, 'All results (CSV)', '${app.samples.length} samples, for Excel',
              () => shareText(context, 'LabLedger_all_results.csv', Reports.resultsCsv(app), 'text/csv', subject: 'LabLedger results')),
          tile(Icons.picture_as_pdf_rounded, 'Reports for open samples (PDF)', 'One page per sample not yet reported', () async {
            final open = app.samples.where((s) => s.status != SampleStatus.reported && s.results.isNotEmpty).toList();
            if (open.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No open samples with results.')));
              return;
            }
            final bytes = await Reports.sampleReport(app, open);
            if (context.mounted) await shareBytes(context, 'LabLedger_reports.pdf', bytes, 'application/pdf');
          }),
          tile(Icons.backup_outlined, 'Back up all data', 'One file with every sample, curve and QC record',
              () => shareBackupFile(context, app.saveNow)),
          if (app.hasDemo)
            tile(Icons.cleaning_services_outlined, 'Remove demo data', 'Clear the example samples, curve and QC', () {
              app.clearDemo();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo data removed.')));
            }, color: c.fair),
          const SizedBox(height: 16),
          Center(child: Text('LabLedger 0.1 · data stays on this phone', style: LBText.body(c.inkDim, size: 12))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class LimitSetsScreen extends StatelessWidget {
  const LimitSetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    return Scaffold(
      appBar: AppBar(title: const Text('Limit sets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final s = LimitSet(id: newId(), name: 'My standards');
          app.update(() => app.limitSets.add(s));
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => LimitSetScreen(set: s)));
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New set'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          for (final s in app.limitSets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LBCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LimitSetScreen(set: s))),
                child: Row(
                  children: [
                    Icon(s.builtIn ? Icons.public_rounded : Icons.edit_note_rounded, color: c.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: LBText.body(c.ink, weight: FontWeight.w700)),
                          Text('${s.limits.length} parameters${s.builtIn ? ' · built in' : ''}', style: LBText.body(c.inkDim, size: 12.5)),
                        ],
                      ),
                    ),
                    if (app.settings.defaultLimitSetId == s.id) Tag('Default', color: c.good),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LimitSetScreen extends StatelessWidget {
  final LimitSet set;
  const LimitSetScreen({super.key, required this.set});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final s = set;
    final entries = s.limits.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Scaffold(
      appBar: AppBar(
        title: Text(s.builtIn ? 'Limits' : 'Edit limits'),
        actions: [
          if (!s.builtIn)
            IconButton(
              tooltip: 'Delete set',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                app.update(() {
                  app.limitSets.remove(s);
                  if (app.settings.defaultLimitSetId == s.id) app.settings.defaultLimitSetId = 'who-dw';
                });
                Navigator.pop(context);
              },
            ),
        ],
      ),
      floatingActionButton: s.builtIn
          ? FloatingActionButton.extended(
              onPressed: () {
                final copy = LimitSet(id: newId(), name: '${s.name} (copy)', note: s.note, limits: {...s.limits});
                app.update(() => app.limitSets.add(copy));
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LimitSetScreen(set: copy)));
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy to edit'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _editLimit(context, app, s),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add limit'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          if (s.builtIn)
            Text(s.name, style: LBText.title(c.ink))
          else
            TextFormField(
              initialValue: s.name,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. EPA Liberia effluent limits'),
              onChanged: (v) => app.update(() => s.name = v),
            ),
          const SizedBox(height: 8),
          if (s.note.isNotEmpty) Text(s.note, style: LBText.body(c.inkDim, size: 12.5)),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: app.settings.defaultLimitSetId == s.id,
            onChanged: (v) => app.update(() => app.settings.defaultLimitSetId = v ? s.id : 'who-dw'),
            title: const Text('Default for new samples'),
          ),
          const SizedBox(height: 4),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: LBCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: s.builtIn ? null : () => _editLimit(context, app, s, name: e.key),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key, style: LBText.body(c.ink, weight: FontWeight.w600, size: 14)),
                          if (e.value.note.isNotEmpty) Text(e.value.note, style: LBText.body(c.inkDim, size: 11.5)),
                        ],
                      ),
                    ),
                    Text(e.value.text, style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _editLimit(BuildContext context, AppState app, LimitSet s, {String? name}) async {
    final existing = name == null ? null : s.limits[name];
    final p = TextEditingController(text: name ?? '');
    final mn = TextEditingController(text: existing?.min?.toString() ?? '');
    final mx = TextEditingController(text: existing?.max?.toString() ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    var unit = existing?.unit ?? 'mg/L';
    final ok = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(name == null ? 'Add limit' : 'Edit limit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: p, decoration: const InputDecoration(labelText: 'Parameter', hintText: 'e.g. Lead (Pb)')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: mn, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Min (optional)'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: mx, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Max'))),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: units.contains(unit) ? unit : 'mg/L',
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u.isEmpty ? '(none)' : u))],
                  onChanged: (u) => setLocal(() => unit = u ?? unit),
                ),
                const SizedBox(height: 10),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note / source')),
              ],
            ),
          ),
          actions: [
            if (name != null) TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: const Text('Delete')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == 'delete' && name != null) {
      app.update(() => s.limits.remove(name));
    } else if (ok == 'save' && p.text.trim().isNotEmpty) {
      app.update(() {
        if (name != null) s.limits.remove(name);
        s.limits[p.text.trim()] = Limit(
          min: double.tryParse(mn.text.trim()),
          max: double.tryParse(mx.text.trim()),
          unit: unit,
          note: note.text.trim(),
        );
      });
    }
  }
}

// ---------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final st = app.settings;
    Widget field(String label, String value, ValueChanged<String> onChanged, {String? hint, bool number = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            initialValue: value,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
            onChanged: (v) => app.update(() => onChanged(v)),
          ),
        );
    double n(String v, double d) => double.tryParse(v) ?? d;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
        children: [
          const SectionHeader('Laboratory'),
          field('Laboratory name (on reports)', st.labName, (v) => st.labName = v),
          field('Analyst', st.analyst, (v) => st.analyst = v, hint: 'Your name'),
          field('Reviewer / approver', st.reviewer, (v) => st.reviewer = v),
          Row(
            children: [
              Expanded(child: field('Sample ID prefix', st.idPrefix, (v) => st.idPrefix = v.trim().isEmpty ? 'LAB' : v.trim())),
              const SizedBox(width: 10),
              Expanded(child: field('Next number', '${st.nextSeq}', (v) => st.nextSeq = int.tryParse(v) ?? st.nextSeq, number: true)),
            ],
          ),
          Text('Next sample code: ${app.nextCode()}', style: LBText.reading(12.5, c.inkDim)),
          const SectionHeader('QC acceptance limits'),
          field('Calibration r² minimum', '${st.r2Min}', (v) => st.r2Min = n(v, st.r2Min), number: true),
          field('Duplicate RPD maximum (%)', '${st.rpdMax}', (v) => st.rpdMax = n(v, st.rpdMax), number: true),
          Row(children: [
            Expanded(child: field('Spike recovery low %', '${st.spikeLo}', (v) => st.spikeLo = n(v, st.spikeLo), number: true)),
            const SizedBox(width: 10),
            Expanded(child: field('high %', '${st.spikeHi}', (v) => st.spikeHi = n(v, st.spikeHi), number: true)),
          ]),
          Row(children: [
            Expanded(child: field('CRM/CCV recovery low %', '${st.crmLo}', (v) => st.crmLo = n(v, st.crmLo), number: true)),
            const SizedBox(width: 10),
            Expanded(child: field('high %', '${st.crmHi}', (v) => st.crmHi = n(v, st.crmHi), number: true)),
          ]),
          const SectionHeader('Display'),
          LBCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: st.daylight,
              onChanged: (v) => app.update(() => st.daylight = v),
              title: const Text('Daylight theme'),
              subtitle: const Text('High-contrast light colours'),
              secondary: Icon(Icons.wb_sunny_outlined, color: c.accent),
            ),
          ),
        ],
      ),
    );
  }
}
