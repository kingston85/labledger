import 'package:flutter/material.dart';

import '../core/lab_docs.dart';
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

enum RegisterTab { instruments, stock, purchases, log }

extension on RegisterTab {
  String get label => const ['Equipment', 'Reagents & stock', 'Purchase requests', 'Stock movements'][index];
}

Color _dueColor(LBColors c, DateTime? due, {int soon = 14}) {
  if (due == null) return c.inkDim;
  final d = daysUntil(due);
  return d < 0 ? c.poor : (d <= soon ? c.fair : c.good);
}

String _dueText(DateTime? due) {
  if (due == null) return 'not scheduled';
  final d = daysUntil(due);
  if (d < 0) return 'overdue ${-d} d';
  if (d == 0) return 'due today';
  return 'in $d d · ${shortDate(due)}';
}

String _q(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Inventory & equipment: instruments with calibration / maintenance logs,
/// reagents and standards with stock movements, purchase requests.
class RegisterScreen extends StatefulWidget {
  final RegisterTab tab;
  const RegisterScreen({super.key, this.tab = RegisterTab.instruments});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late RegisterTab _tab = widget.tab;
  String _q2 = '';

  bool _hit(List<String> f) => _q2.isEmpty || f.any((x) => x.toLowerCase().contains(_q2));

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final alerts = app.registerAlerts;
    final low = app.reagents.where((r) => r.lowStock).length;
    final expiring = app.reagents.where((r) => r.expiry != null && daysUntil(r.expiry!) <= 30).length;
    final calDue = app.instruments.where((i) => i.inService && i.calibrationDue != null && daysUntil(i.calibrationDue!) <= 14).length;
    final openPr = app.purchases.where((p) => p.status.index < PurchaseStatus.received.index).toList();

    Widget? fab;
    if (app.canEdit) {
      switch (_tab) {
        case RegisterTab.instruments:
          fab = FloatingActionButton.extended(onPressed: () => editInstrument(context, null), icon: const Icon(Icons.add_rounded), label: const Text('Instrument'));
        case RegisterTab.stock:
          fab = FloatingActionButton.extended(onPressed: () => editReagent(context, null), icon: const Icon(Icons.add_rounded), label: const Text('Reagent / standard'));
        case RegisterTab.purchases:
          fab = FloatingActionButton.extended(
            onPressed: () async {
              final v = await showSheet<String>(
                context: context,
                showDragHandle: true,
                builder: (context) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(
                      leading: const Icon(Icons.auto_fix_high_rounded),
                      title: const Text('From low stock and expiring items'),
                      subtitle: Text('${app.reagents.where((r) => r.lowStock || (r.expiry != null && daysUntil(r.expiry!) < 30)).length} items'),
                      onTap: () => Navigator.pop(context, 'auto'),
                    ),
                    ListTile(leading: const Icon(Icons.note_add_outlined), title: const Text('Blank purchase request'), onTap: () => Navigator.pop(context, 'blank')),
                    const SizedBox(height: 10),
                  ]),
                ),
              );
              if (!context.mounted || v == null) return;
              if (v == 'auto') {
                final pr = app.purchaseFromLowStock();
                openPurchaseEditor(context, pr);
              } else {
                openPurchaseEditor(context, null);
              }
            },
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('Purchase request'),
          );
        case RegisterTab.log:
          fab = null;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory & equipment')),
      floatingActionButton: fab,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          StatRow([
            StatTile(label: 'Instruments', value: '${app.instruments.length}', sub: calDue == 0 ? 'calibrations up to date' : '$calDue calibration(s) due', icon: Icons.precision_manufacturing_rounded, color: calDue > 0 ? c.fair : c.accent),
            StatTile(label: 'Low stock', value: '$low', sub: 'at or below reorder level', icon: Icons.inventory_2_rounded, color: low > 0 ? c.fair : c.good),
            StatTile(label: 'Expiring ≤ 30 days', value: '$expiring', sub: 'reagents & standards', icon: Icons.hourglass_bottom_rounded, color: expiring > 0 ? c.poor : c.good),
            StatTile(
                label: 'Open purchases',
                value: '${openPr.length}',
                sub: money(openPr.fold(0.0, (a, p) => a + p.total), app.settings.currency),
                icon: Icons.shopping_cart_rounded,
                color: c.accent),
          ]),
          const SizedBox(height: 14),
          Segmented<RegisterTab>(values: RegisterTab.values, selected: _tab, label: (t) => t.label, onChanged: (t) => setState(() => _tab = t)),
          const SizedBox(height: 12),
          if (alerts.isNotEmpty && (_tab == RegisterTab.instruments || _tab == RegisterTab.stock))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LBCard(
                borderColor: (alerts.first.$3 == 2 ? c.poor : c.fair).withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final a in alerts.take(5))
                    ListTile(
                      dense: true,
                      leading: Icon(a.$3 == 2 ? Icons.error_rounded : Icons.schedule_rounded, color: a.$3 == 2 ? c.poor : c.fair),
                      title: Text(a.$1, style: LBText.body(c.ink, weight: FontWeight.w600)),
                      subtitle: Text(a.$2, style: LBText.body(c.inkDim, size: 12)),
                    ),
                ]),
              ),
            ),
          if (_tab != RegisterTab.log)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search', isDense: true),
                onChanged: (v) => setState(() => _q2 = v.trim().toLowerCase()),
              ),
            ),
          switch (_tab) {
            RegisterTab.instruments => _instruments(context, app),
            RegisterTab.stock => _stock(context, app),
            RegisterTab.purchases => _purchases(context, app),
            RegisterTab.log => _log(context, app),
          },
        ],
      ),
    );
  }

  Widget _instruments(BuildContext context, AppState app) {
    final c = context.lb;
    final list = app.instruments.where((i) => _hit([i.name, i.model, i.serial, i.location])).toList();
    if (list.isEmpty) {
      return const EmptyState(icon: Icons.precision_manufacturing_outlined, title: 'No instruments', body: 'Add balances, meters and analysers with their calibration interval. LabLedger reminds you before they fall due and keeps a full maintenance log.');
    }
    return Column(children: [
      for (final i in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => openInstrumentLog(context, i),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: (i.inService ? c.accent : c.poor).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.precision_manufacturing_rounded, color: i.inService ? c.accent : c.poor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name, style: LBText.body(c.ink, weight: FontWeight.w700)),
                  Text([i.model, if (i.serial.isNotEmpty) 'S/N ${i.serial}', i.location].where((x) => x.isNotEmpty).join(' · '), style: LBText.body(c.inkDim, size: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Tag('Calibration ${_dueText(i.calibrationDue)}', color: _dueColor(c, i.calibrationDue)),
                    if (i.serviceDue != null) Tag('Service ${_dueText(i.serviceDue)}', color: _dueColor(c, i.serviceDue)),
                    if (!i.inService) Tag('OUT OF SERVICE', color: c.poor),
                    Tag('${app.logsFor(i.id).length} log entries', color: c.inkDim, icon: Icons.history_rounded),
                  ]),
                ]),
              ),
              IconButton(
                tooltip: 'Record calibration / maintenance',
                icon: Icon(Icons.add_task_rounded, color: c.good),
                onPressed: () => addMaintenanceDialog(context, i),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _stock(BuildContext context, AppState app) {
    final c = context.lb;
    final list = ([...app.reagents]..sort((a, b) => (a.expiry ?? DateTime(2999)).compareTo(b.expiry ?? DateTime(2999)))).where((r) => _hit([r.name, r.lot, r.supplier, r.location])).toList();
    if (list.isEmpty) {
      return const EmptyState(icon: Icons.science_outlined, title: 'No reagents or standards', body: 'Track lot numbers, expiry dates and stock so expired standards never reach a calibration. Book usage and deliveries to keep quantities right.');
    }
    return Column(children: [
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => editReagent(context, r),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(r.kind == ReagentKind.crm ? Icons.verified_rounded : (r.kind == ReagentKind.standard ? Icons.straighten_rounded : Icons.science_rounded), color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: LBText.body(c.ink, weight: FontWeight.w700)),
                    Text([r.kind.label, if (r.lot.isNotEmpty) 'lot ${r.lot}', r.supplier, r.location].where((x) => x.isNotEmpty).join(' · '), style: LBText.body(c.inkDim, size: 12)),
                  ]),
                ),
                if (r.quantity != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${_q(r.quantity!)} ${r.unit}', style: LBText.reading(15, r.lowStock ? c.fair : c.ink, weight: FontWeight.w700)),
                    if (r.minStock != null) Text('reorder at ${_q(r.minStock!)}', style: LBText.body(c.inkDim, size: 11)),
                  ]),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                    Tag(r.expiry == null ? 'No expiry set' : (daysUntil(r.expiry!) < 0 ? 'EXPIRED ${shortDate(r.expiry!)}' : 'Expires ${_dueText(r.expiry)}'), color: _dueColor(c, r.expiry, soon: 30)),
                    if (r.lowStock) Tag('LOW STOCK', color: c.fair),
                    if (app.monthlyUse(r.id) > 0)
                      Tag('uses ~${_q(app.monthlyUse(r.id))} ${r.unit}/month${r.quantity == null ? '' : ' · ${(r.quantity! / app.monthlyUse(r.id)).toStringAsFixed(1)} months left'}', color: c.inkDim),
                  ]),
                ),
                if (app.canEdit) ...[
                  TextButton.icon(onPressed: () => stockDialog(context, r, StockReason.used), icon: const Icon(Icons.remove_circle_outline_rounded, size: 18), label: const Text('Use')),
                  TextButton.icon(onPressed: () => stockDialog(context, r, StockReason.received), icon: const Icon(Icons.add_circle_outline_rounded, size: 18), label: const Text('Receive')),
                ],
              ]),
            ]),
          ),
        ),
    ]);
  }

  Widget _purchases(BuildContext context, AppState app) {
    final c = context.lb;
    final cur = app.settings.currency;
    final list = app.purchases.where((p) => _hit([p.number, p.supplier, p.requestedBy, ...p.lines.map((l) => l.description)])).toList()..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) {
      return const EmptyState(icon: Icons.shopping_cart_outlined, title: 'No purchase requests', body: 'Create a purchase request straight from low-stock items, get it approved, print it for procurement, and book the delivery into stock when it arrives.');
    }
    Color col(PurchaseStatus s) => switch (s) {
          PurchaseStatus.draft => c.inkDim,
          PurchaseStatus.submitted => c.fair,
          PurchaseStatus.approved => c.accent,
          PurchaseStatus.ordered => c.accent,
          PurchaseStatus.received => c.good,
          PurchaseStatus.cancelled => c.inkDim,
        };
    return Column(children: [
      for (final p in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => openPurchaseEditor(context, p),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: col(p.status).withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.shopping_cart_rounded, color: col(p.status)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p.number}${p.supplier.isEmpty ? '' : ' · ${p.supplier}'}', style: LBText.body(c.ink, weight: FontWeight.w700)),
                  Text('${p.lines.length} item${p.lines.length == 1 ? '' : 's'} · ${shortDate(p.date)} · ${p.requestedBy}', style: LBText.body(c.inkDim, size: 12)),
                  const SizedBox(height: 6),
                  Tag(p.status.label, color: col(p.status)),
                ]),
              ),
              Text(money(p.total, cur), style: LBText.reading(15, c.ink, weight: FontWeight.w700)),
            ]),
          ),
        ),
    ]);
  }

  Widget _log(BuildContext context, AppState app) {
    final c = context.lb;
    if (app.stockMoves.isEmpty) return const EmptyState(icon: Icons.swap_vert_rounded, title: 'No stock movements', body: 'Use and Receive on a reagent record every movement here.');
    return LBCard(
      padding: EdgeInsets.zero,
      child: DataGrid<StockMove>(
        rows: app.stockMoves,
        minWidth: 640,
        columns: [
          GridColumn('Date', width: 110, cell: (m) => gridText(context, shortDate(m.date)), sortKey: (m) => m.date),
          GridColumn('Item', flex: 3, cell: (m) => gridText(context, app.reagent(m.reagentId)?.name ?? '(deleted)'), sortKey: (m) => app.reagent(m.reagentId)?.name ?? ''),
          GridColumn('Movement', flex: 1.4, cell: (m) => gridText(context, m.reason.label)),
          GridColumn('Quantity', width: 110, numeric: true, cell: (m) => gridText(context, '${m.qty >= 0 ? '+' : ''}${_q(m.qty)} ${app.reagent(m.reagentId)?.unit ?? ''}', mono: true, color: m.qty >= 0 ? c.good : c.ink), sortKey: (m) => m.qty),
          GridColumn('By', flex: 1.2, cell: (m) => gridText(context, m.user)),
          GridColumn('Note', flex: 2, cell: (m) => gridText(context, m.note)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock and maintenance dialogs
// ---------------------------------------------------------------------------

Future<void> stockDialog(BuildContext context, Reagent r, StockReason reason) async {
  final app = AppScope.read(context);
  final qty = TextEditingController();
  final note = TextEditingController();
  var why = reason;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setS) {
      return AlertDialog(
        title: Text('${why == StockReason.received ? 'Receive' : 'Book out'} · ${r.name}'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 6, children: [
              for (final s in StockReason.values) ChoiceChip(label: Text(s.label), selected: why == s, onSelected: (_) => setS(() => why = s)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: qty,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: why == StockReason.adjusted ? 'Change (+/−) in ${r.unit}' : 'Quantity (${r.unit})',
                helperText: 'On hand: ${r.quantity == null ? 'not counted' : '${_q(r.quantity!)} ${r.unit}'}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note', hintText: 'Batch, analysis, PR number…', isDense: true)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record')),
        ],
      );
    }),
  );
  final v = double.tryParse(qty.text.trim().replaceAll(',', '.'));
  if (ok == true && v != null && v != 0) app.moveStock(r, v, why, note: note.text.trim());
}

Future<void> addMaintenanceDialog(BuildContext context, Instrument i) async {
  final app = AppScope.read(context);
  var kind = MaintenanceKind.calibration;
  var date = DateTime.now();
  var passed = true;
  final by = TextEditingController(text: app.userName);
  final outcome = TextEditingController();
  final cert = TextEditingController();
  final cost = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setS) {
      return AlertDialog(
        title: Text('Log for ${i.name}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in MaintenanceKind.values) ChoiceChip(label: Text(k.label), selected: kind == k, onSelected: (_) => setS(() => kind = k)),
              ]),
              const SizedBox(height: 12),
              FieldRow([
                DateField(label: 'Date', value: date, clearable: false, onChanged: (d) => setS(() => date = d ?? date)),
                TextField(controller: by, decoration: const InputDecoration(labelText: 'Performed by', isDense: true)),
              ]),
              TextField(controller: outcome, maxLines: 2, decoration: const InputDecoration(labelText: 'Result / findings', hintText: 'Slope 98.7 %, within spec', isDense: true)),
              const SizedBox(height: 10),
              FieldRow([
                TextField(controller: cert, decoration: const InputDecoration(labelText: 'Certificate / job no.', isDense: true)),
                TextField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Cost (${app.settings.currency})', isDense: true)),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: passed,
                onChanged: (v) => setS(() => passed = v),
                title: Text(passed ? 'Passed — fit for use' : 'Failed — take out of service'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      );
    }),
  );
  if (ok != true) return;
  app.addMaintenance(
    i,
    MaintenanceLog(
      id: newId(),
      instrumentId: i.id,
      date: date,
      kind: kind,
      by: by.text.trim(),
      outcome: outcome.text.trim(),
      passed: passed,
      certificate: cert.text.trim(),
      cost: double.tryParse(cost.text.trim()),
    ),
  );
  if (!passed && context.mounted) {
    final raise = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raise a non-conformance?'),
        content: Text('${i.name} failed its ${kind.label.toLowerCase()} and is now out of service. Results produced since the last good check may need review.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Raise NC')),
        ],
      ),
    );
    if (raise == true) {
      app.raiseNc(title: '${i.name} failed ${kind.label.toLowerCase()}', description: outcome.text.trim(), source: NcSource.equipment, severity: NcSeverity.major, reference: '${i.name} ${i.serial}'.trim());
    }
  }
}

// ---------------------------------------------------------------------------
// Instrument log
// ---------------------------------------------------------------------------

Future<void> openInstrumentLog(BuildContext context, Instrument i) => openForm(context, InstrumentLogScreen(instrument: i), width: 680);

class InstrumentLogScreen extends StatelessWidget {
  final Instrument instrument;
  const InstrumentLogScreen({super.key, required this.instrument});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final i = instrument;
    final logs = app.logsFor(i.id);
    final methods = app.methods.where((m) => m.instrumentId == i.id).toList();
    final spend = logs.fold(0.0, (a, l) => a + (l.cost ?? 0));
    return Scaffold(
      appBar: AppBar(
        title: Text(i.name),
        actions: [
          IconButton(tooltip: 'Edit instrument', icon: const Icon(Icons.edit_rounded), onPressed: () => editInstrument(context, i)),
        ],
      ),
      floatingActionButton: app.canEdit
          ? FloatingActionButton.extended(onPressed: () => addMaintenanceDialog(context, i), icon: const Icon(Icons.add_task_rounded), label: const Text('Log calibration / service'))
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          FormSection('Instrument', icon: Icons.precision_manufacturing_rounded, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              Tag(i.inService ? 'In service' : 'OUT OF SERVICE', color: i.inService ? c.good : c.poor),
              Tag('Calibration ${_dueText(i.calibrationDue)}', color: _dueColor(c, i.calibrationDue)),
              if (i.serviceDue != null) Tag('Service ${_dueText(i.serviceDue)}', color: _dueColor(c, i.serviceDue)),
            ]),
            const SizedBox(height: 10),
            for (final (k, v) in [
              ('Make / model', i.model),
              ('Serial no.', i.serial),
              ('Location', i.location),
              ('Calibration interval', i.calibrationDays <= 0 ? 'not scheduled' : '${i.calibrationDays} days'),
              ('Service interval', i.serviceDays <= 0 ? 'not scheduled' : '${i.serviceDays} days'),
              ('Methods using it', methods.isEmpty ? '—' : methods.map((m) => m.code).join(', ')),
              ('Maintenance spend', spend == 0 ? '—' : money(spend, app.settings.currency)),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 150, child: Text(k, style: LBText.body(c.inkDim, size: 13))),
                  Expanded(child: Text(v.isEmpty ? '—' : v, style: LBText.body(c.ink, size: 13, weight: FontWeight.w600))),
                ]),
              ),
          ]),
          FormSection('Calibration & maintenance log (${logs.length})', icon: Icons.history_rounded, children: [
            if (logs.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('No records yet.', style: LBText.body(c.inkDim, size: 13))),
            for (final l in logs)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: l.passed ? c.good : c.poor, width: 3))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${l.kind.label} · ${shortDate(l.date)}', style: LBText.body(c.ink, size: 13.5, weight: FontWeight.w700)),
                      if (l.outcome.isNotEmpty) Text(l.outcome, style: LBText.body(c.ink, size: 12.5)),
                      Text([l.by, if (l.certificate.isNotEmpty) 'cert. ${l.certificate}', if (l.cost != null) money(l.cost!, app.settings.currency)].where((x) => x.isNotEmpty).join(' · '),
                          style: LBText.body(c.inkDim, size: 12)),
                    ]),
                  ),
                  Tag(l.passed ? 'PASS' : 'FAIL', color: l.passed ? c.good : c.poor),
                  if (app.isAdmin)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.inkDim),
                      onPressed: () => app.update(() => app.maintenance.remove(l)),
                    ),
                ]),
              ),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purchase request editor
// ---------------------------------------------------------------------------

Future<void> openPurchaseEditor(BuildContext context, PurchaseRequest? pr) => openForm(context, PurchaseEditorScreen(purchase: pr), width: 760);

class PurchaseEditorScreen extends StatefulWidget {
  final PurchaseRequest? purchase;
  const PurchaseEditorScreen({super.key, this.purchase});

  @override
  State<PurchaseEditorScreen> createState() => _PurchaseEditorScreenState();
}

class _PurchaseEditorScreenState extends State<PurchaseEditorScreen> {
  late PurchaseRequest p;
  final _supplier = TextEditingController();
  final _just = TextEditingController();
  final _notes = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.read(context);
    p = widget.purchase == null
        ? PurchaseRequest(id: newId(), number: app.nextPurchaseNumber(), requestedBy: app.userName, lines: [PurchaseLine(description: '')])
        : PurchaseRequest.fromJson(widget.purchase!.toJson());
    _supplier.text = p.supplier;
    _just.text = p.justification;
    _notes.text = p.notes;
  }

  void _collect() {
    p
      ..supplier = _supplier.text.trim()
      ..justification = _just.text.trim()
      ..notes = _notes.text.trim();
    p.lines.removeWhere((l) => l.description.trim().isEmpty);
  }

  PurchaseRequest _commit() {
    final app = AppScope.read(context);
    _collect();
    app.update(() {
      final i = app.purchases.indexWhere((x) => x.id == p.id);
      if (i >= 0) {
        app.purchases[i] = p;
        app.log('update', 'Purchase request', p.number, '${p.status.label} · ${money(p.total, app.settings.currency)}');
      } else {
        app.purchases.insert(0, p);
        app.log('create', 'Purchase request', p.number, money(p.total, app.settings.currency));
      }
    });
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final cur = app.settings.currency;
    final locked = p.status == PurchaseStatus.received || p.status == PurchaseStatus.cancelled;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.number),
        actions: [
          IconButton(
            tooltip: 'Print / share (PDF)',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () async {
              _collect();
              final bytes = await LabDocs.purchasePdf(app, p);
              if (context.mounted) await shareBytes(context, '${p.number}.pdf', bytes, 'application/pdf');
            },
          ),
        ],
      ),
      bottomNavigationBar: FormActions(
        onSave: app.canEdit
            ? () {
                _commit();
                Navigator.pop(context);
              }
            : null,
        onDelete: widget.purchase == null || !app.isAdmin
            ? null
            : () {
                app.update(() => app.purchases.removeWhere((x) => x.id == p.id));
                Navigator.pop(context);
              },
        extra: [
          if (!locked && (p.status == PurchaseStatus.approved || p.status == PurchaseStatus.ordered))
            TextButton.icon(
              onPressed: () {
                final stored = _commit();
                app.receivePurchase(stored);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${stored.number} received; quantities booked into stock.')));
              },
              icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
              label: const Text('Receive into stock'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FormSection('Request', icon: Icons.shopping_cart_rounded, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in PurchaseStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: p.status == s,
                  onSelected: (s == PurchaseStatus.approved && !app.canApprove) || s == PurchaseStatus.received
                      ? null
                      : (_) => setState(() {
                            p.status = s;
                            if (s == PurchaseStatus.approved) p.approvedBy = app.userName;
                          }),
                ),
            ]),
            const SizedBox(height: 10),
            FieldRow([
              TextField(controller: _supplier, decoration: const InputDecoration(labelText: 'Supplier', isDense: true)),
              DateField(label: 'Date', value: p.date, clearable: false, onChanged: (d) => setState(() => p.date = d ?? p.date)),
            ]),
            TextField(controller: _just, maxLines: 2, decoration: const InputDecoration(labelText: 'Justification', isDense: true)),
            const SizedBox(height: 8),
            Text('Requested by ${p.requestedBy}${p.approvedBy.isEmpty ? '' : ' · approved by ${p.approvedBy}'}', style: LBText.body(c.inkDim, size: 12)),
            const SizedBox(height: 8),
          ]),
          FormSection(
            'Items',
            icon: Icons.list_alt_rounded,
            trailing: locked ? null : TextButton.icon(onPressed: () => setState(() => p.lines.add(PurchaseLine(description: ''))), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Item')),
            children: [
              for (final l in p.lines)
                Container(
                  key: ObjectKey(l),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 10, 4, 6),
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: l.description,
                          enabled: !locked,
                          decoration: const InputDecoration(labelText: 'Description', isDense: true),
                          onChanged: (v) => l.description = v,
                        ),
                      ),
                      if (!locked) IconButton(onPressed: () => setState(() => p.lines.remove(l)), icon: Icon(Icons.close_rounded, size: 18, color: c.inkDim)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _q(l.qty),
                          enabled: !locked,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                          onChanged: (v) => setState(() => l.qty = double.tryParse(v) ?? l.qty),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(initialValue: l.unit, enabled: !locked, decoration: const InputDecoration(labelText: 'Unit', isDense: true), onChanged: (v) => l.unit = v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: l.unitPrice == 0 ? '' : l.unitPrice.toStringAsFixed(2),
                          enabled: !locked,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'Unit price ($cur)', isDense: true),
                          onChanged: (v) => setState(() => l.unitPrice = double.tryParse(v) ?? 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 96, child: Text(money(l.total, cur), textAlign: TextAlign.right, style: LBText.reading(13, c.ink, weight: FontWeight.w700))),
                      const SizedBox(width: 8),
                    ]),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: app.reagent(l.reagentId) == null ? null : l.reagentId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Books into stock item', isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('— not a stock item —')),
                        for (final r in app.reagents) DropdownMenuItem<String?>(value: r.id, child: Text(r.name, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: locked ? null : (v) => setState(() => l.reagentId = v),
                    ),
                  ]),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10, right: 8),
                  child: Text('Estimated total  ${money(p.total, cur)}', style: LBText.reading(16, c.ink, weight: FontWeight.w700)),
                ),
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
// Instrument and reagent editors
// ---------------------------------------------------------------------------

Future<DateTime?> _pickDate(BuildContext context, DateTime? init) =>
    showDatePicker(context: context, initialDate: init ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));

Future<void> editInstrument(BuildContext context, Instrument? existing) async {
  final app = AppScope.read(context);
  final i = existing ?? Instrument(id: newId(), name: '');
  final name = TextEditingController(text: i.name);
  final model = TextEditingController(text: i.model);
  final serial = TextEditingController(text: i.serial);
  final loc = TextEditingController(text: i.location);
  final notes = TextEditingController(text: i.notes == 'Demo item' ? '' : i.notes);
  var calDays = i.calibrationDays, svcDays = i.serviceDays;
  DateTime? lastCal = i.lastCalibration, lastSvc = i.lastService;
  var inService = i.inService;
  final res = await showSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(builder: (context, setS) {
      final c = context.lb;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(existing == null ? 'New instrument' : 'Edit instrument', style: LBText.title(c.ink)),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'UV-Vis spectrophotometer')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: model, decoration: const InputDecoration(labelText: 'Make / model', isDense: true))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: serial, decoration: const InputDecoration(labelText: 'Serial no.', isDense: true))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: loc, decoration: const InputDecoration(labelText: 'Location', isDense: true)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await _pickDate(context, lastCal);
                if (d != null) setS(() => lastCal = d);
              },
              icon: const Icon(Icons.event_available_rounded),
              label: Text(lastCal == null ? 'Last calibration date' : 'Last calibrated ${shortDate(lastCal!)}'),
            ),
            const SizedBox(height: 8),
            Stepper2(label: 'Calibration every (days)', value: calDays, min: 0, max: 730, onChanged: (v) => setS(() => calDays = v)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              for (final p in const [(1, 'daily'), (7, 'weekly'), (30, 'monthly'), (90, 'quarterly'), (182, '6 months'), (365, 'yearly')])
                ActionChip(label: Text(p.$2), onPressed: () => setS(() => calDays = p.$1), visualDensity: VisualDensity.compact),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await _pickDate(context, lastSvc);
                if (d != null) setS(() => lastSvc = d);
              },
              icon: const Icon(Icons.build_rounded),
              label: Text(lastSvc == null ? 'Last service / maintenance' : 'Last serviced ${shortDate(lastSvc!)}'),
            ),
            const SizedBox(height: 8),
            Stepper2(label: 'Service every (days, 0 = off)', value: svcDays, min: 0, max: 730, onChanged: (v) => setS(() => svcDays = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: inService, onChanged: (v) => setS(() => inService = v), title: const Text('In service')),
            TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes', isDense: true)),
            const SizedBox(height: 14),
            Row(children: [
              if (existing != null) IconButton(onPressed: () => Navigator.pop(context, 'delete'), icon: Icon(Icons.delete_outline_rounded, color: c.poor)),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save'))),
            ]),
          ]),
        ),
      );
    }),
  );
  if (res == 'delete') app.update(() => app.instruments.remove(existing));
  if (res == 'save' && name.text.trim().isNotEmpty) {
    app.update(() {
      i
        ..name = name.text.trim()
        ..model = model.text.trim()
        ..serial = serial.text.trim()
        ..location = loc.text.trim()
        ..lastCalibration = lastCal
        ..calibrationDays = calDays
        ..lastService = lastSvc
        ..serviceDays = svcDays
        ..inService = inService
        ..notes = notes.text.trim();
      if (existing == null) app.instruments.add(i);
    });
  }
}

Future<void> editReagent(BuildContext context, Reagent? existing) async {
  final app = AppScope.read(context);
  final r = existing ?? Reagent(id: newId(), name: '');
  final name = TextEditingController(text: r.name);
  final lot = TextEditingController(text: r.lot);
  final sup = TextEditingController(text: r.supplier);
  final loc = TextEditingController(text: r.location);
  final qty = TextEditingController(text: r.quantity?.toString() ?? '');
  final unit = TextEditingController(text: r.unit);
  final min = TextEditingController(text: r.minStock?.toString() ?? '');
  final notes = TextEditingController(text: r.notes == 'Demo item' ? '' : r.notes);
  var kind = r.kind;
  DateTime? received = r.received, opened = r.opened, expiry = r.expiry;
  final res = await showSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(builder: (context, setS) {
      final c = context.lb;
      Widget dateBtn(String label, DateTime? v, void Function(DateTime) set) => Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final d = await _pickDate(context, v);
                if (d != null) setS(() => set(d));
              },
              child: Text(v == null ? label : '$label\n${shortDate(v)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ),
          );
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(existing == null ? 'New reagent / standard' : 'Edit item', style: LBText.title(c.ink)),
            const SizedBox(height: 12),
            Segmented<ReagentKind>(values: ReagentKind.values, selected: kind, label: (k) => k.label, onChanged: (k) => setS(() => kind = k)),
            const SizedBox(height: 10),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name', hintText: 'Lead standard 1000 mg/L')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: lot, decoration: const InputDecoration(labelText: 'Lot / batch', isDense: true))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: sup, decoration: const InputDecoration(labelText: 'Supplier', isDense: true))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: loc, decoration: const InputDecoration(labelText: 'Storage location', isDense: true)),
            const SizedBox(height: 10),
            Row(children: [
              dateBtn('Received', received, (d) => received = d),
              const SizedBox(width: 6),
              dateBtn('Opened', opened, (d) => opened = d),
              const SizedBox(width: 6),
              dateBtn('Expiry', expiry, (d) => expiry = d),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit', hintText: 'mL, g, pillows', isDense: true))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: min, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Reorder at', isDense: true))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (certificate, concentration…)', isDense: true)),
            const SizedBox(height: 14),
            Row(children: [
              if (existing != null) IconButton(onPressed: () => Navigator.pop(context, 'delete'), icon: Icon(Icons.delete_outline_rounded, color: c.poor)),
              Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save'))),
            ]),
          ]),
        ),
      );
    }),
  );
  if (res == 'delete') app.update(() => app.reagents.remove(existing));
  if (res == 'save' && name.text.trim().isNotEmpty) {
    app.update(() {
      r
        ..name = name.text.trim()
        ..kind = kind
        ..lot = lot.text.trim()
        ..supplier = sup.text.trim()
        ..location = loc.text.trim()
        ..received = received
        ..opened = opened
        ..expiry = expiry
        ..quantity = double.tryParse(qty.text.trim())
        ..unit = unit.text.trim()
        ..minStock = double.tryParse(min.text.trim())
        ..notes = notes.text.trim();
      if (existing == null) app.reagents.add(r);
    });
  }
}
