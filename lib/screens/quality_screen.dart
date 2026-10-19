import 'package:flutter/material.dart';

import '../core/lab_docs.dart';
import '../core/quality.dart';
import '../core/report.dart';
import '../data/app_state.dart';
import '../data/lab_models.dart';
import '../data/lab_ops.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/data_grid.dart';
import '../widgets/inputs.dart';
import '../widgets/panels.dart';
import '../widgets/share.dart';

enum QualityTab { methods, pt, nc, verify }

extension on QualityTab {
  String get label => const ['Methods & SOPs', 'Proficiency tests', 'Non-conformances', 'Verify a report'][index];
}

/// Quality system (ISO/IEC 17025 style): method library, proficiency
/// testing, non-conformances with CAPA, and report verification.
class QualityScreen extends StatefulWidget {
  final QualityTab tab;
  const QualityScreen({super.key, this.tab = QualityTab.methods});

  @override
  State<QualityScreen> createState() => _QualityScreenState();
}

class _QualityScreenState extends State<QualityScreen> {
  late QualityTab _tab = widget.tab;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final active = app.methods.where((m) => m.status == MethodStatus.active || m.status == MethodStatus.validated).length;
    final pt = app.ptSuccessRate;
    final open = app.openNcs;
    final overdue = open.where((n) => n.overdue).length;

    Widget? fab;
    if (app.canEdit) {
      switch (_tab) {
        case QualityTab.methods:
          fab = FloatingActionButton.extended(onPressed: () => openMethodEditor(context, null), icon: const Icon(Icons.add_rounded), label: const Text('Method'));
        case QualityTab.pt:
          fab = FloatingActionButton.extended(onPressed: () => openPtEditor(context, null), icon: const Icon(Icons.add_rounded), label: const Text('PT round'));
        case QualityTab.nc:
          fab = FloatingActionButton.extended(onPressed: () => openNcEditor(context, null), icon: const Icon(Icons.report_gmailerrorred_rounded), label: const Text('Raise NC'));
        case QualityTab.verify:
          fab = null;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quality system')),
      floatingActionButton: fab,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          StatRow([
            StatTile(label: 'Methods in use', value: '$active', sub: '${app.methods.length} in library', icon: Icons.menu_book_rounded),
            StatTile(
                label: 'PT satisfactory',
                value: pt == null ? '—' : '${pt.toStringAsFixed(0)}%',
                sub: '${app.ptRounds.length} rounds',
                icon: Icons.emoji_events_rounded,
                color: pt == null ? c.inkDim : (pt >= 90 ? c.good : (pt >= 75 ? c.fair : c.poor))),
            StatTile(label: 'Open non-conformances', value: '${open.length}', sub: overdue == 0 ? 'none overdue' : '$overdue overdue', icon: Icons.report_problem_rounded, color: overdue > 0 ? c.poor : (open.isEmpty ? c.good : c.fair)),
            StatTile(label: 'Holding-time breaches', value: '${app.holdingBreaches.length}', sub: 'samples', icon: Icons.timer_off_rounded, color: app.holdingBreaches.isEmpty ? c.good : c.fair),
          ]),
          const SizedBox(height: 14),
          Segmented<QualityTab>(values: QualityTab.values, selected: _tab, label: (t) => t.label, onChanged: (t) => setState(() => _tab = t)),
          const SizedBox(height: 12),
          if (_tab != QualityTab.verify)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search', isDense: true),
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              ),
            ),
          switch (_tab) {
            QualityTab.methods => _methods(context, app),
            QualityTab.pt => _pts(context, app),
            QualityTab.nc => _ncList(context, app),
            QualityTab.verify => const _Verify(),
          },
        ],
      ),
    );
  }

  bool _hit(List<String> fields) => _q.isEmpty || fields.any((f) => f.toLowerCase().contains(_q));

  Widget _methods(BuildContext context, AppState app) {
    final c = context.lb;
    final list = app.methods.where((m) => _hit([m.code, m.title, m.technique, m.reference, ...m.parameters])).toList()..sort((a, b) => a.code.compareTo(b.code));
    if (list.isEmpty) {
      return const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'No methods',
          body: 'Build your method library: SOP number, reference method, parameters, MDL / LOQ, measurement uncertainty and review date. Results pick the method up automatically.');
    }
    Color statusCol(MethodStatus s) => switch (s) { MethodStatus.active => c.good, MethodStatus.validated => c.accent, MethodStatus.draft => c.fair, MethodStatus.retired => c.inkDim };
    if (wideLayout(context)) {
      return LBCard(
        padding: EdgeInsets.zero,
        child: DataGrid<LabMethod>(
          rows: list,
          onTap: (m) => openMethodEditor(context, m),
          columns: [
            GridColumn('Code', width: 120, cell: (m) => gridText(context, m.code, bold: true, mono: true), sortKey: (m) => m.code),
            GridColumn('Title', flex: 3, cell: (m) => gridText(context, m.title), sortKey: (m) => m.title),
            GridColumn('Technique', flex: 1.5, cell: (m) => gridText(context, m.technique), sortKey: (m) => m.technique),
            GridColumn('Parameters', flex: 2, cell: (m) => gridText(context, m.parameters.join(', ')), sortKey: (m) => m.parameters.length),
            GridColumn('MDL / LOQ', width: 120, numeric: true, cell: (m) => gridText(context, m.mdl == null ? '—' : '${fmtValue(m.mdl!)} / ${m.loq == null ? '—' : fmtValue(m.loq!)}', mono: true)),
            GridColumn('U (k=2)', width: 80, numeric: true, cell: (m) => gridText(context, m.uncertaintyPct == null ? '—' : '±${m.uncertaintyPct!.toStringAsFixed(0)}%', mono: true)),
            GridColumn('Version', width: 70, cell: (m) => gridText(context, m.version, mono: true)),
            GridColumn('Status', width: 100, cell: (m) => Tag(m.status.label, color: statusCol(m.status)), sortKey: (m) => m.status.index),
            GridColumn('Review', width: 110, cell: (m) {
              if (m.reviewDue == null) return gridText(context, '—');
              final d = daysUntil(m.reviewDue!);
              return gridText(context, shortDate(m.reviewDue!), color: d < 0 ? c.poor : (d <= 30 ? c.fair : null));
            }, sortKey: (m) => m.reviewDue ?? DateTime(2999)),
          ],
        ),
      );
    }
    return Column(children: [
      for (final m in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => openMethodEditor(context, m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(m.code, style: LBText.reading(13, c.accent, weight: FontWeight.w700)),
                const SizedBox(width: 8),
                Tag('v${m.version}', color: c.inkDim),
                const Spacer(),
                Tag(m.status.label, color: statusCol(m.status)),
              ]),
              const SizedBox(height: 4),
              Text(m.title, style: LBText.body(c.ink, weight: FontWeight.w700)),
              Text([m.technique, m.parameters.join(', ')].where((x) => x.isNotEmpty).join(' · '), style: LBText.body(c.inkDim, size: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (m.mdl != null) Tag('MDL ${fmtValue(m.mdl!)} ${m.unit}', color: c.inkDim),
                if (m.loq != null) Tag('LOQ ${fmtValue(m.loq!)}', color: c.inkDim),
                if (m.uncertaintyPct != null) Tag('U ±${m.uncertaintyPct!.toStringAsFixed(0)}%', color: c.inkDim),
                if (m.reviewDue != null && daysUntil(m.reviewDue!) < 31) Tag(daysUntil(m.reviewDue!) < 0 ? 'Review overdue' : 'Review ${shortDate(m.reviewDue!)}', color: daysUntil(m.reviewDue!) < 0 ? c.poor : c.fair),
              ]),
            ]),
          ),
        ),
    ]);
  }

  Widget _pts(BuildContext context, AppState app) {
    final c = context.lb;
    final list = app.ptRounds.where((p) => _hit([p.provider, p.scheme, p.round, ...p.results.map((r) => r.parameter)])).toList()..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) {
      return const EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'No proficiency tests',
          body: 'Record PT and inter-laboratory comparison rounds. LabLedger computes z-scores (ISO 13528) and lets you raise a non-conformance for any unsatisfactory result.');
    }
    return Column(children: [
      for (final p in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => openPtEditor(context, p),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${p.provider} · ${p.round}', style: LBText.body(c.ink, weight: FontWeight.w700))),
                Text(shortDate(p.date), style: LBText.reading(12, c.inkDim)),
              ]),
              Text([p.scheme, p.matrix].where((x) => x.isNotEmpty).join(' · '), style: LBText.body(c.inkDim, size: 12)),
              const SizedBox(height: 8),
              if (p.scored == 0)
                Tag(p.date.isAfter(DateTime.now()) ? 'Samples expected ${shortDate(p.date)}' : 'Awaiting assigned values', color: c.accent)
              else
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final r in p.results.where((r) => r.z != null))
                    Tag('${r.parameter.split(' (').first} z=${r.z!.toStringAsFixed(1)}',
                        color: switch (ptVerdict(r.z)!) { PtVerdict.satisfactory => c.good, PtVerdict.questionable => c.fair, PtVerdict.unsatisfactory => c.poor }),
                ]),
            ]),
          ),
        ),
    ]);
  }

  Widget _ncList(BuildContext context, AppState app) {
    final c = context.lb;
    final list = app.ncs.where((n) => _hit([n.number, n.title, n.description, n.reference, n.owner])).toList()
      ..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return b.date.compareTo(a.date);
      });
    if (list.isEmpty) {
      return const EmptyState(
          icon: Icons.verified_user_outlined,
          title: 'No non-conformances',
          body: 'Record QC failures, PT problems, complaints and audit findings with root cause, corrective and preventive action, owner and due date.');
    }
    Color sevCol(NcSeverity s) => switch (s) { NcSeverity.minor => c.fair, NcSeverity.major => c.poor, NcSeverity.critical => c.poor };
    if (wideLayout(context)) {
      return LBCard(
        padding: EdgeInsets.zero,
        child: DataGrid<NonConformance>(
          rows: list,
          onTap: (n) => openNcEditor(context, n),
          columns: [
            GridColumn('Number', width: 120, cell: (n) => gridText(context, n.number, mono: true, bold: true), sortKey: (n) => n.number),
            GridColumn('Raised', width: 100, cell: (n) => gridText(context, shortDate(n.date)), sortKey: (n) => n.date),
            GridColumn('Title', flex: 3, cell: (n) => gridText(context, n.title), sortKey: (n) => n.title),
            GridColumn('Source', flex: 1.3, cell: (n) => gridText(context, n.source.label), sortKey: (n) => n.source.index),
            GridColumn('Severity', width: 90, cell: (n) => Tag(n.severity.label, color: sevCol(n.severity)), sortKey: (n) => n.severity.index),
            GridColumn('Owner', flex: 1.2, cell: (n) => gridText(context, n.owner)),
            GridColumn('Due', width: 100, cell: (n) => gridText(context, n.dueDate == null ? '—' : shortDate(n.dueDate!), color: n.overdue ? c.poor : null), sortKey: (n) => n.dueDate ?? DateTime(2999)),
            GridColumn('Status', width: 110, cell: (n) => Tag(n.status.label, color: n.isOpen ? (n.overdue ? c.poor : c.accent) : c.good), sortKey: (n) => n.status.index),
          ],
        ),
      );
    }
    return Column(children: [
      for (final n in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => openNcEditor(context, n),
            borderColor: n.overdue ? c.poor.withOpacity(0.5) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(n.number, style: LBText.reading(12.5, c.accent, weight: FontWeight.w700)),
                const Spacer(),
                Tag(n.status.label, color: n.isOpen ? (n.overdue ? c.poor : c.accent) : c.good),
              ]),
              const SizedBox(height: 4),
              Text(n.title, style: LBText.body(c.ink, weight: FontWeight.w700)),
              Text('${n.source.label} · ${n.owner.isEmpty ? 'no owner' : n.owner}${n.dueDate == null ? '' : ' · due ${shortDate(n.dueDate!)}'}', style: LBText.body(c.inkDim, size: 12)),
              const SizedBox(height: 6),
              Tag(n.severity.label, color: sevCol(n.severity)),
            ]),
          ),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Verify a report
// ---------------------------------------------------------------------------

class _Verify extends StatefulWidget {
  const _Verify();

  @override
  State<_Verify> createState() => _VerifyState();
}

class _VerifyState extends State<_Verify> {
  final _no = TextEditingController();
  final _code = TextEditingController();
  (IssuedReport?, bool, bool)? _res;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FormSection('Check a report', icon: Icons.qr_code_2_rounded, children: [
        Text('Every final PDF report carries a report number and a verification code (also inside its QR code). Enter both to confirm the report is genuine and the results have not changed since it was issued.',
            style: LBText.body(c.inkDim, size: 12.5)),
        const SizedBox(height: 12),
        FieldRow([
          TextField(controller: _no, decoration: InputDecoration(labelText: 'Report number', hintText: 'RPT-${DateTime.now().year}-0001', isDense: true)),
          TextField(controller: _code, decoration: const InputDecoration(labelText: 'Verification code', hintText: '1A2B-3C4D-5E6F', isDense: true)),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => setState(() => _res = app.verifyReport(_no.text, _code.text)),
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: const Text('Verify'),
          ),
        ),
        const SizedBox(height: 10),
        if (_res != null)
          () {
            final (r, match, unchanged) = _res!;
            final ok = r != null && match && unchanged;
            final col = ok ? c.good : (r != null && match ? c.fair : c.poor);
            final text = r == null
                ? 'No report with that number was issued by this laboratory.'
                : !match
                    ? 'Report ${r.number} exists, but the code does not match. The document may have been altered.'
                    : unchanged
                        ? 'Genuine. Report ${r.number} was issued on ${dateTime(r.issued)} by ${r.issuedBy} for ${r.sampleCodes.join(', ')}. Results are unchanged.'
                        : 'Report ${r.number} is genuine, but results for ${r.sampleCodes.join(', ')} were changed after it was issued. A revised report is needed.';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: col.withOpacity(0.5))),
              child: Row(children: [
                Icon(ok ? Icons.verified_rounded : Icons.gpp_maybe_rounded, color: col),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: LBText.body(c.ink, size: 13, weight: FontWeight.w600))),
              ]),
            );
          }(),
      ]),
      SectionHeader('Issued reports (${app.issuedReports.length})'),
      if (app.issuedReports.isEmpty)
        LBCard(child: Text('Final reports appear here when you export an approved sample report as PDF.', style: LBText.body(c.inkDim, size: 13)))
      else
        LBCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, r) in app.issuedReports.take(100).indexed) ...[
              if (i > 0) Divider(height: 1, color: c.line),
              ListTile(
                dense: true,
                leading: Icon(Icons.description_outlined, color: c.accent),
                title: Text('${r.number} · ${r.sampleCodes.join(', ')}', style: LBText.body(c.ink, size: 13, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${dateTime(r.issued)} · ${r.issuedBy}', style: LBText.body(c.inkDim, size: 12)),
                trailing: Text(groupCode(r.hash), style: LBText.reading(11.5, c.inkDim)),
                onTap: () {
                  _no.text = r.number;
                  _code.text = groupCode(r.hash);
                  setState(() => _res = app.verifyReport(r.number, r.hash));
                },
              ),
            ],
          ]),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Method editor
// ---------------------------------------------------------------------------

Future<void> openMethodEditor(BuildContext context, LabMethod? m) => openForm(context, MethodEditorScreen(method: m), width: 720);

class MethodEditorScreen extends StatefulWidget {
  final LabMethod? method;
  const MethodEditorScreen({super.key, this.method});

  @override
  State<MethodEditorScreen> createState() => _MethodEditorScreenState();
}

class _MethodEditorScreenState extends State<MethodEditorScreen> {
  late LabMethod m;
  final _f = <String, TextEditingController>{};
  final _reps = TextEditingController();
  MdlStudy? _study;

  TextEditingController _c(String k, [String v = '']) => _f.putIfAbsent(k, () => TextEditingController(text: v));
  String _num(double? v) => v == null ? '' : fmtValue(v);

  @override
  void initState() {
    super.initState();
    m = widget.method == null ? LabMethod(id: newId(), code: '', title: '', status: MethodStatus.draft) : LabMethod.fromJson(widget.method!.toJson());
    _c('code', m.code);
    _c('title', m.title);
    _c('version', m.version);
    _c('technique', m.technique);
    _c('reference', m.reference);
    _c('parameters', m.parameters.join(', '));
    _c('matrices', m.matrices);
    _c('unit', m.unit);
    _c('mdl', _num(m.mdl));
    _c('loq', _num(m.loq));
    _c('u', m.uncertaintyPct?.toString() ?? '');
    _c('rlo', m.recoveryLo?.toString() ?? '');
    _c('rhi', m.recoveryHi?.toString() ?? '');
    _c('notes', m.notes);
  }

  double? _d(String k) => double.tryParse(_f[k]!.text.trim());

  void _save() {
    final app = AppScope.read(context);
    if (_f['code']!.text.trim().isEmpty || _f['title']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a method code and title.')));
      return;
    }
    m
      ..code = _f['code']!.text.trim()
      ..title = _f['title']!.text.trim()
      ..version = _f['version']!.text.trim().isEmpty ? '1.0' : _f['version']!.text.trim()
      ..technique = _f['technique']!.text.trim()
      ..reference = _f['reference']!.text.trim()
      ..parameters = _f['parameters']!.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList()
      ..matrices = _f['matrices']!.text.trim()
      ..unit = _f['unit']!.text.trim()
      ..mdl = _d('mdl')
      ..loq = _d('loq')
      ..uncertaintyPct = _d('u')
      ..recoveryLo = _d('rlo')
      ..recoveryHi = _d('rhi')
      ..notes = _f['notes']!.text.trim();
    app.update(() {
      final i = app.methods.indexWhere((x) => x.id == m.id);
      if (i >= 0) {
        app.methods[i] = m;
        app.log('update', 'Method', m.code, 'v${m.version} · ${m.status.label}');
      } else {
        if (m.revisions.isEmpty) m.revisions.add(MethodRevision(version: m.version, change: 'First issue', by: app.userName));
        app.methods.add(m);
        app.log('create', 'Method', m.code, m.title);
      }
    });
    Navigator.pop(context);
  }

  Future<void> _newRevision() async {
    final app = AppScope.read(context);
    final v = TextEditingController(text: _bump(_f['version']!.text.trim()));
    final ch = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New revision'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: v, decoration: const InputDecoration(labelText: 'New version')),
            const SizedBox(height: 10),
            TextField(controller: ch, autofocus: true, maxLines: 3, decoration: const InputDecoration(labelText: 'What changed and why')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add revision')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        m.revisions.add(MethodRevision(version: v.text.trim(), change: ch.text.trim(), by: app.userName));
        _f['version']!.text = v.text.trim();
        m.effective = DateTime.now();
        m.reviewDue = DateTime.now().add(const Duration(days: 365));
      });
    }
  }

  String _bump(String v) {
    final p = v.split('.');
    final last = int.tryParse(p.last);
    if (last == null) return '$v.1';
    p[p.length - 1] = '${last + 1}';
    return p.join('.');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    Widget tf(String k, String label, {String? hint, bool number = false, int lines = 1}) => TextField(
          controller: _f[k],
          maxLines: lines,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
          decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
        );
    return Scaffold(
      appBar: AppBar(title: Text(widget.method == null ? 'New method' : m.code)),
      bottomNavigationBar: FormActions(
        onSave: app.canEdit ? _save : null,
        onDelete: widget.method == null || !app.isAdmin
            ? null
            : () {
                app.update(() {
                  app.methods.removeWhere((x) => x.id == m.id);
                  app.log('delete', 'Method', m.code, '');
                });
                Navigator.pop(context);
              },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FormSection('Method', icon: Icons.menu_book_rounded, children: [
            FieldRow([tf('code', 'SOP / method code', hint: 'SOP-MET-01'), tf('version', 'Version')]),
            tf('title', 'Title', hint: 'Iron in water by UV-Vis'),
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              for (final s in MethodStatus.values) ChoiceChip(label: Text(s.label), selected: m.status == s, onSelected: (_) => setState(() => m.status = s)),
            ]),
            const SizedBox(height: 10),
            FieldRow([tf('technique', 'Technique', hint: 'Flame AAS'), tf('reference', 'Reference method', hint: 'APHA 3111 B')]),
            tf('parameters', 'Parameters (comma separated)', hint: 'Lead (Pb), Cadmium (Cd)'),
            const SizedBox(height: 10),
            FieldRow([tf('matrices', 'Matrices', hint: 'Drinking and surface water'), tf('unit', 'Reporting unit')]),
            DropdownButtonFormField<String?>(
              value: app.instrument(m.instrumentId) == null ? null : m.instrumentId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Instrument', isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
                for (final i in app.instruments) DropdownMenuItem<String?>(value: i.id, child: Text(i.name)),
              ],
              onChanged: (v) => setState(() => m.instrumentId = v),
            ),
            const SizedBox(height: 10),
            FieldRow([
              DateField(label: 'Effective from', value: m.effective, onChanged: (d) => setState(() => m.effective = d)),
              DateField(label: 'Next review', value: m.reviewDue, onChanged: (d) => setState(() => m.reviewDue = d)),
            ]),
          ]),
          FormSection('Performance characteristics', icon: Icons.speed_rounded, children: [
            FieldRow([tf('mdl', 'MDL', number: true), tf('loq', 'LOQ', number: true), tf('u', 'Uncertainty U (k=2) %', number: true)]),
            FieldRow([tf('rlo', 'Spike recovery from %', number: true), tf('rhi', 'to %', number: true)]),
          ]),
          FormSection('MDL study (40 CFR 136 App. B)', icon: Icons.calculate_rounded, children: [
            Text('Paste 7 or more replicate results of a low-level spike. MDL = t(n−1, 0.99) × s; LOQ = 10 × s.', style: LBText.body(c.inkDim, size: 12.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _reps,
              maxLines: 2,
              decoration: const InputDecoration(hintText: '0.021 0.018 0.024 0.020 0.019 0.023 0.022', isDense: true),
              onChanged: (v) => setState(() {
                final vals = RegExp(r'-?\d+(?:\.\d+)?(?:[eE]-?\d+)?').allMatches(v).map((x) => double.parse(x.group(0)!)).toList();
                _study = mdlStudy(vals);
              }),
            ),
            if (_study != null) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                Tag('n = ${_study!.n}', color: _study!.n >= 7 ? c.good : c.fair),
                Tag('mean ${fmtValue(_study!.mean)}', color: c.inkDim),
                Tag('s ${fmtValue(_study!.sd)}', color: c.inkDim),
                Tag('t ${_study!.t.toStringAsFixed(3)}', color: c.inkDim),
                Tag('MDL ${fmtValue(_study!.mdl)}', color: c.accent),
                Tag('LOQ ${fmtValue(_study!.loq)}', color: c.accent),
                Tag('RSD ${_study!.rsd.toStringAsFixed(1)}%', color: c.inkDim),
              ]),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _f['mdl']!.text = fmtValue(_study!.mdl);
                    _f['loq']!.text = fmtValue(_study!.loq);
                  }),
                  icon: const Icon(Icons.download_done_rounded, size: 18),
                  label: const Text('Use these values'),
                ),
              ),
            ],
            const SizedBox(height: 6),
          ]),
          FormSection(
            'Revision history',
            icon: Icons.history_rounded,
            trailing: widget.method == null ? null : TextButton.icon(onPressed: _newRevision, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New revision')),
            children: [
              if (m.revisions.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('First issue is recorded when you save.', style: LBText.body(c.inkDim, size: 12.5))),
              for (final r in m.revisions.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(radius: 16, backgroundColor: c.accent.withOpacity(0.14), child: Text(r.version, style: LBText.reading(10, c.accent, weight: FontWeight.w700))),
                  title: Text(r.change.isEmpty ? 'Revision ${r.version}' : r.change, style: LBText.body(c.ink, size: 13)),
                  subtitle: Text('${shortDate(r.date)}${r.by.isEmpty ? '' : ' · ${r.by}'}', style: LBText.body(c.inkDim, size: 12)),
                ),
            ],
          ),
          FormSection('Notes', icon: Icons.notes_rounded, children: [tf('notes', 'Scope, interferences, QC requirements', lines: 3), const SizedBox(height: 8)]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Proficiency-test editor
// ---------------------------------------------------------------------------

Future<void> openPtEditor(BuildContext context, PtRound? r) => openForm(context, PtEditorScreen(round: r), width: 780);

class PtEditorScreen extends StatefulWidget {
  final PtRound? round;
  const PtEditorScreen({super.key, this.round});

  @override
  State<PtEditorScreen> createState() => _PtEditorScreenState();
}

class _PtEditorScreenState extends State<PtEditorScreen> {
  late PtRound p;
  late final _provider = TextEditingController(text: p.provider);
  late final _scheme = TextEditingController(text: p.scheme);
  late final _round = TextEditingController(text: p.round);
  late final _matrix = TextEditingController(text: p.matrix);
  late final _notes = TextEditingController(text: p.notes);

  @override
  void initState() {
    super.initState();
    p = widget.round == null ? PtRound(id: newId(), provider: '', results: [PtResult(parameter: '')]) : PtRound.fromJson(widget.round!.toJson());
  }

  void _save() {
    final app = AppScope.read(context);
    p
      ..provider = _provider.text.trim()
      ..scheme = _scheme.text.trim()
      ..round = _round.text.trim()
      ..matrix = _matrix.text.trim()
      ..notes = _notes.text.trim();
    p.results.removeWhere((r) => r.parameter.trim().isEmpty);
    app.update(() {
      final i = app.ptRounds.indexWhere((x) => x.id == p.id);
      if (i >= 0) {
        app.ptRounds[i] = p;
      } else {
        app.ptRounds.add(p);
      }
      app.log(i >= 0 ? 'update' : 'create', 'PT round', '${p.provider} ${p.round}', '${p.scored} scored');
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    Widget numField(double? v, String label, void Function(double?) set) => TextFormField(
          initialValue: v == null ? '' : fmtValue(v),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: LBText.reading(13, c.ink),
          decoration: InputDecoration(labelText: label, isDense: true),
          onChanged: (s) => setState(() => set(double.tryParse(s.trim()))),
        );
    return Scaffold(
      appBar: AppBar(title: Text(widget.round == null ? 'New PT round' : '${p.provider} ${p.round}')),
      bottomNavigationBar: FormActions(
        onSave: app.canEdit ? _save : null,
        onDelete: widget.round == null || !app.isAdmin
            ? null
            : () {
                app.update(() => app.ptRounds.removeWhere((x) => x.id == p.id));
                Navigator.pop(context);
              },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FormSection('Round', icon: Icons.emoji_events_rounded, children: [
            FieldRow([
              TextField(controller: _provider, decoration: const InputDecoration(labelText: 'Provider', hintText: 'ERA, LGC AQUACHECK, inter-lab', isDense: true)),
              TextField(controller: _scheme, decoration: const InputDecoration(labelText: 'Scheme', isDense: true)),
            ]),
            FieldRow([
              TextField(controller: _round, decoration: const InputDecoration(labelText: 'Round', isDense: true)),
              TextField(controller: _matrix, decoration: const InputDecoration(labelText: 'Matrix', isDense: true)),
            ]),
            FieldRow([
              DateField(label: 'Samples received', value: p.date, clearable: false, onChanged: (d) => setState(() => p.date = d ?? p.date)),
              DateField(label: 'Results due to provider', value: p.reportDue, onChanged: (d) => setState(() => p.reportDue = d)),
            ]),
          ]),
          FormSection(
            'Results and z-scores',
            icon: Icons.functions_rounded,
            trailing: TextButton.icon(onPressed: () => setState(() => p.results.add(PtResult(parameter: ''))), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Parameter')),
            children: [
              Text('z = (your result − assigned value) / σpt.   |z| ≤ 2 satisfactory · 2 < |z| < 3 questionable · |z| ≥ 3 unsatisfactory (ISO 13528).',
                  style: LBText.body(c.inkDim, size: 12)),
              const SizedBox(height: 10),
              for (final r in p.results)
                Container(
                  key: ObjectKey(r),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 10, 4, 4),
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: r.parameter,
                          decoration: const InputDecoration(labelText: 'Parameter', isDense: true),
                          onChanged: (s) => r.parameter = s,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(initialValue: r.unit, decoration: const InputDecoration(labelText: 'Unit', isDense: true), onChanged: (s) => r.unit = s),
                      ),
                      IconButton(onPressed: () => setState(() => p.results.remove(r)), icon: Icon(Icons.close_rounded, size: 18, color: c.inkDim)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: numField(r.reported, 'Our result', (v) => r.reported = v)),
                      const SizedBox(width: 8),
                      Expanded(child: numField(r.assigned, 'Assigned', (v) => r.assigned = v)),
                      const SizedBox(width: 8),
                      Expanded(child: numField(r.sigma, 'σpt', (v) => r.sigma = v)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 128,
                        child: r.z == null
                            ? Text('z —', style: LBText.reading(13, c.inkDim))
                            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('z = ${r.z!.toStringAsFixed(2)}', style: LBText.reading(14, c.ink, weight: FontWeight.w700)),
                                Tag(ptVerdict(r.z)!.label,
                                    color: switch (ptVerdict(r.z)!) { PtVerdict.satisfactory => c.good, PtVerdict.questionable => c.fair, PtVerdict.unsatisfactory => c.poor }),
                              ]),
                      ),
                    ]),
                    if (ptVerdict(r.z) == PtVerdict.unsatisfactory || ptVerdict(r.z) == PtVerdict.questionable)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            final nc = app.raiseNc(
                              title: '${r.parameter} PT result ${ptVerdict(r.z)!.label.toLowerCase()} (z = ${r.z!.toStringAsFixed(1)})',
                              description: '${_provider.text} round ${_round.text}: reported ${fmtValue(r.reported!)} ${r.unit}, assigned ${fmtValue(r.assigned!)} ${r.unit}, σpt ${fmtValue(r.sigma!)}.',
                              source: NcSource.proficiencyTest,
                              severity: ptVerdict(r.z) == PtVerdict.unsatisfactory ? NcSeverity.major : NcSeverity.minor,
                              reference: 'PT ${_round.text}',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${nc.number} raised.')));
                          },
                          icon: Icon(Icons.report_gmailerrorred_rounded, size: 18, color: c.poor),
                          label: Text('Raise non-conformance', style: TextStyle(color: c.poor)),
                        ),
                      ),
                  ]),
                ),
            ],
          ),
          FormSection('Notes', icon: Icons.notes_rounded, children: [
            TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(isDense: true)),
            const SizedBox(height: 8),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Non-conformance editor
// ---------------------------------------------------------------------------

Future<void> openNcEditor(BuildContext context, NonConformance? n) => openForm(context, NcEditorScreen(nc: n), width: 720);

class NcEditorScreen extends StatefulWidget {
  final NonConformance? nc;
  const NcEditorScreen({super.key, this.nc});

  @override
  State<NcEditorScreen> createState() => _NcEditorScreenState();
}

class _NcEditorScreenState extends State<NcEditorScreen> {
  late NonConformance n;
  final _f = <String, TextEditingController>{};
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.read(context);
    n = widget.nc == null
        ? NonConformance(id: newId(), number: app.nextNcNumber(), raisedBy: app.userName, dueDate: DateTime.now().add(const Duration(days: 30)))
        : NonConformance.fromJson(widget.nc!.toJson());
    for (final (k, v) in [
      ('title', n.title),
      ('description', n.description),
      ('reference', n.reference),
      ('immediate', n.immediateAction),
      ('root', n.rootCause),
      ('corrective', n.correctiveAction),
      ('preventive', n.preventiveAction),
      ('owner', n.owner),
      ('effect', n.effectiveness),
    ]) {
      _f[k] = TextEditingController(text: v);
    }
  }

  void _collect() {
    n
      ..title = _f['title']!.text.trim()
      ..description = _f['description']!.text.trim()
      ..reference = _f['reference']!.text.trim()
      ..immediateAction = _f['immediate']!.text.trim()
      ..rootCause = _f['root']!.text.trim()
      ..correctiveAction = _f['corrective']!.text.trim()
      ..preventiveAction = _f['preventive']!.text.trim()
      ..owner = _f['owner']!.text.trim()
      ..effectiveness = _f['effect']!.text.trim();
  }

  void _save() {
    final app = AppScope.read(context);
    _collect();
    if (n.title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the non-conformance a short title.')));
      return;
    }
    if (n.status == NcStatus.closed && n.closedAt == null) n.closedAt = DateTime.now();
    if (n.status != NcStatus.closed) n.closedAt = null;
    app.update(() {
      final i = app.ncs.indexWhere((x) => x.id == n.id);
      if (i >= 0) {
        app.ncs[i] = n;
        app.log('update', 'Non-conformance', n.number, n.status.label);
      } else {
        app.ncs.insert(0, n);
        app.log('raise', 'Non-conformance', n.number, n.title);
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    Widget tf(String k, String label, {String? hint, int lines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: _f[k], maxLines: lines, minLines: 1, decoration: InputDecoration(labelText: label, hintText: hint, isDense: true)),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(n.number),
        actions: [
          IconButton(
            tooltip: 'CAPA form (PDF)',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () async {
              _collect();
              final bytes = await LabDocs.ncPdf(app, n);
              if (context.mounted) await shareBytes(context, '${n.number}.pdf', bytes, 'application/pdf');
            },
          ),
        ],
      ),
      bottomNavigationBar: FormActions(
        onSave: app.canEdit ? _save : null,
        saveLabel: widget.nc == null ? 'Raise' : 'Save',
        onDelete: widget.nc == null || !app.isAdmin
            ? null
            : () {
                app.update(() {
                  app.ncs.removeWhere((x) => x.id == n.id);
                  app.log('delete', 'Non-conformance', n.number, '');
                });
                Navigator.pop(context);
              },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FormSection('What happened', icon: Icons.report_problem_rounded, children: [
            tf('title', 'Title', hint: 'Spike recovery outside 80–120 % for Pb'),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in NcStatus.values) ChoiceChip(label: Text(s.label), selected: n.status == s, onSelected: (_) => setState(() => n.status = s)),
              ]),
            ),
            FieldRow([
              DropdownButtonFormField<NcSource>(
                value: n.source,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Source', isDense: true),
                items: [for (final s in NcSource.values) DropdownMenuItem(value: s, child: Text(s.label))],
                onChanged: (v) => setState(() => n.source = v ?? n.source),
              ),
              DropdownButtonFormField<NcSeverity>(
                value: n.severity,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Severity', isDense: true),
                items: [for (final s in NcSeverity.values) DropdownMenuItem(value: s, child: Text(s.label))],
                onChanged: (v) => setState(() => n.severity = v ?? n.severity),
              ),
            ]),
            tf('reference', 'Reference (sample, batch, instrument, PT round)'),
            tf('description', 'Description', lines: 3),
            Text('Raised ${shortDate(n.date)} by ${n.raisedBy}', style: LBText.body(c.inkDim, size: 12)),
            const SizedBox(height: 8),
          ]),
          FormSection('Investigation & action', icon: Icons.build_circle_rounded, children: [
            tf('immediate', 'Immediate action / correction', lines: 2),
            tf('root', 'Root cause', hint: 'Ask "why?" five times', lines: 2),
            tf('corrective', 'Corrective action', lines: 2),
            tf('preventive', 'Preventive action', lines: 2),
            FieldRow([
              TextField(controller: _f['owner'], decoration: const InputDecoration(labelText: 'Action owner', isDense: true)),
              DateField(label: 'Due', value: n.dueDate, onChanged: (d) => setState(() => n.dueDate = d)),
            ]),
          ]),
          FormSection('Close-out', icon: Icons.task_alt_rounded, children: [
            tf('effect', 'Verification of effectiveness', lines: 2),
            if (n.closedAt != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Closed ${shortDate(n.closedAt!)}', style: LBText.body(c.good, size: 12.5, weight: FontWeight.w600))),
          ]),
        ],
      ),
    );
  }
}
