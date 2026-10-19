import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/guidelines.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/share.dart';
import '../core/docx.dart';
import '../core/lab_docs.dart';
import '../core/photos.dart';
import '../core/word_reports.dart';
import 'admin_screen.dart';
import 'calendar_screen.dart';
import 'field_screen.dart';
import 'quality_screen.dart';
import 'sample_detail_screen.dart';
import 'business_screen.dart';
import 'calibration_screen.dart';
import 'import_screen.dart';
import 'map_screen.dart';
import 'qc_screen.dart';
import 'investigation_screen.dart';
import 'register_screen.dart';
import 'stats_screen.dart';
import '../widgets/panels.dart';

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
      appBar: AppBar(title: const Text('Settings & tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const SectionHeader('Modules'),
          tile(Icons.route_rounded, 'Field trips', 'Plan sampling trips, checklists, field sheets, holding-time guide',
              () => openPage(context, const FieldScreen())),
          tile(Icons.calendar_month_rounded, 'Lab calendar', 'Due results, trips, calibrations, expiries, invoices, actions',
              () => openPage(context, const CalendarScreen())),
          tile(Icons.verified_user_rounded, 'Quality system', 'Methods & SOPs, proficiency tests, non-conformances (CAPA)',
              () => openPage(context, const QualityScreen())),
          tile(Icons.business_center_rounded, 'Business', 'Requests & quotations, invoices, payments, clients, price list',
              () => openPage(context, const BusinessScreen())),
          tile(Icons.map_rounded, 'Map & GIS', 'Sampling points on a map, KML / GeoJSON export',
              () => openPage(context, const MapScreen())),
          tile(Icons.admin_panel_settings_rounded, 'Users & audit trail', app.usersEnabled ? 'Signed in as ${app.userName} (${app.role.label})' : 'Add users, PIN sign-in, roles, approvals',
              () => openPage(context, const AdminScreen())),
          tile(Icons.science_rounded, 'Calibration & QC', 'Calibration curves, QC checks and control charts', () {
            showSheet(
              context: context,
              showDragHandle: true,
              builder: (sheet) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                    leading: const Icon(Icons.show_chart_rounded),
                    title: const Text('Calibration'),
                    onTap: () {
                      Navigator.pop(sheet);
                      openPage(context, const CalibrationScreen());
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_rounded),
                    title: const Text('Quality control'),
                    onTap: () {
                      Navigator.pop(sheet);
                      openPage(context, const QcScreen());
                    },
                  ),
                  const SizedBox(height: 10),
                ]),
              ),
            );
          }),
          tile(Icons.travel_explore_rounded, 'Investigations', 'Results matrix, standards, control comparison, findings, report',
              () => openPage(context, const InvestigationsScreen())),
          tile(Icons.inventory_2_rounded, 'Inventory & equipment', 'Instruments & maintenance log, stock, purchase requests',
              () => openPage(context, const RegisterScreen())),
          tile(Icons.upload_file_rounded, 'Import results', 'Paste a table or open a CSV from an instrument or report',
              () => openPage(context, const ImportScreen())),
          tile(Icons.functions_rounded, 'Statistics', 'Descriptives, t-tests, ANOVA, Grubbs outlier test',
              () => openPage(context, const StatsScreen())),
          tile(Icons.rule_folder_outlined, 'Limit sets', 'Liberian Class I, WHO drinking water and your own',
              () => openPage(context, const LimitSetsScreen())),
          tile(Icons.settings_rounded, 'Settings', 'Lab name, analyst, sample IDs, QC acceptance limits',
              () => openForm(context, const SettingsScreen(), width: 720)),
          tile(Icons.qr_code_2_rounded, 'Verify a report', 'Check a report number and verification code',
              () => openPage(context, const QualityScreen(tab: QualityTab.verify))),
          const SectionHeader('Export'),
          tile(Icons.grid_on_rounded, 'Everything (Excel workbook)', 'Samples, results, clients, invoices, inventory, methods, PT, NCs, audit', () async {
            await shareBytes(context, 'LabLedger_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.xlsx',
                LabDocs.fullWorkbook(app), 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
            app.log('export', 'Workbook', '', 'full Excel export');
          }),
          tile(Icons.table_chart_rounded, 'All results (CSV)', '${app.samples.length} samples, for Excel',
              () => shareText(context, 'LabLedger_all_results.csv', Reports.resultsCsv(app), 'text/csv', subject: 'LabLedger results')),
          tile(Icons.picture_as_pdf_rounded, 'Reports for open samples (PDF)', 'One page per sample not yet reported', () async {
            final open = app.samples.where((s) => s.status != SampleStatus.reported && s.results.isNotEmpty).toList();
            if (open.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No open samples with results.')));
              return;
            }
            await exportSampleReport(context, open);
          }),
          tile(Icons.description_rounded, 'Reports for open samples (Word)', 'Editable .docx, one section per sample', () async {
            final open = app.samples.where((s) => s.status != SampleStatus.reported && s.results.isNotEmpty).toList();
            if (open.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No open samples with results.')));
              return;
            }
            await shareBytes(context, 'LabLedger_reports.docx', WordReports.samples(app, open), docxMime);
          }),
          tile(Icons.backup_outlined, 'Back up all data', 'One file with every sample, curve and QC record',
              () => shareBackupFile(context, app.saveNow)),
          tile(Icons.settings_backup_restore_rounded, 'Restore from backup', 'Load a backup file from your phone or PC (replaces current data)',
              () async {
            final data = await pickBackup(context);
            if (data == null || !context.mounted) return;
            final n = (data['samples'] as List).length;
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Restore backup?'),
                content: Text('The backup has $n samples. Everything currently in LabLedger on this device will be replaced.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              app.restore(data);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored $n samples.')));
            }
          }),
          if (app.hasDemo)
            tile(Icons.cleaning_services_outlined, 'Remove demo data', 'Clear the example samples, curve and QC', () {
              app.clearDemo();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo data removed.')));
            }, color: c.fair),
          const SizedBox(height: 16),
          Center(child: Text('LabLedger 1.1 · data stays on this device', style: LBText.body(c.inkDim, size: 12))),
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
          openPage(context, LimitSetScreen(set: s));
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
                onTap: () => openPage(context, LimitSetScreen(set: s)),
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
          const SectionHeader('Documents & billing'),
          field('Laboratory address', st.labAddress, (v) => st.labAddress = v),
          Row(children: [
            Expanded(child: field('Phone', st.labPhone, (v) => st.labPhone = v)),
            const SizedBox(width: 10),
            Expanded(child: field('Email', st.labEmail, (v) => st.labEmail = v)),
          ]),
          Row(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  value: const ['USD', 'LRD', 'EUR', 'GBP'].contains(st.currency) ? st.currency : 'USD',
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Currency', isDense: true),
                  items: [for (final cur in const ['USD', 'LRD', 'EUR', 'GBP']) DropdownMenuItem(value: cur, child: Text(cur))],
                  onChanged: (v) => app.update(() => st.currency = v ?? st.currency),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: field('Default tax / GST %', '${st.defaultTaxPct}', (v) => st.defaultTaxPct = n(v, st.defaultTaxPct), number: true)),
            const SizedBox(width: 10),
            Expanded(child: field('Payment terms (days)', '${st.paymentTermsDays}', (v) => st.paymentTermsDays = int.tryParse(v) ?? st.paymentTermsDays, number: true)),
          ]),
          field('Bank / mobile-money details (printed on invoices)', st.bankDetails, (v) => st.bankDetails = v),
          const SectionHeader('Reports'),
          LBCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 120,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.line)),
                child: st.logoB64.isEmpty
                    ? Text('No logo', style: LBText.body(const Color(0xFF8C96A8), size: 12))
                    : Padding(padding: const EdgeInsets.all(6), child: Image.memory(base64Decode(st.logoB64), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Laboratory logo', style: LBText.body(c.ink, weight: FontWeight.w700)),
                  Text('Printed on test reports, quotations, invoices and forms. PNG or JPG under 600 KB.', style: LBText.body(c.inkDim, size: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final b = await pickImageB64();
                          if (b != null) app.update(() => st.logoB64 = b);
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
                        }
                      },
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(st.logoB64.isEmpty ? 'Choose logo' : 'Change'),
                    ),
                    if (st.logoB64.isNotEmpty) TextButton(onPressed: () => app.update(() => st.logoB64 = ''), child: const Text('Remove')),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          field('Accreditation / status line', st.accreditation, (v) => st.accreditation = v, hint: 'e.g. Working towards ISO/IEC 17025:2017'),
          field('Note printed at the end of every report', st.reportNote, (v) => st.reportNote = v, hint: 'Opinions and interpretations are outside the scope of accreditation…'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: st.qrOnReports,
            onChanged: (v) => app.update(() => st.qrOnReports = v),
            title: const Text('QR verification code on final reports'),
            subtitle: const Text('Each issued report gets a number and a code that can be checked under Quality → Verify a report.'),
          ),
          const SectionHeader('QC acceptance limits'),
          field('Calibration r² minimum', '${st.r2Min}', (v) => st.r2Min = n(v, st.r2Min), number: true),
          field('Duplicate RPD maximum (%)', '${st.rpdMax}', (v) => st.rpdMax = n(v, st.rpdMax), number: true),
          field('Replicate RSD maximum (%)', '${st.replicateRsdMax}', (v) => st.replicateRsdMax = n(v, st.replicateRsdMax), number: true),
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
