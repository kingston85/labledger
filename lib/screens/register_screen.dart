import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';

enum _Tab { instruments, reagents }

/// Instruments (calibration / service due) and reagents & standards (expiry, stock).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  _Tab _tab = _Tab.instruments;

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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final alerts = app.registerAlerts;
    return Scaffold(
      appBar: AppBar(title: const Text('Lab register')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tab == _Tab.instruments ? _editInstrument(context, null) : _editReagent(context, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(_tab == _Tab.instruments ? 'Instrument' : 'Reagent / standard'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Segmented<_Tab>(
            values: _Tab.values,
            selected: _tab,
            label: (t) => t == _Tab.instruments ? 'Instruments (${app.instruments.length})' : 'Reagents & standards (${app.reagents.length})',
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          if (alerts.isNotEmpty)
            LBCard(
              borderColor: (alerts.first.$3 == 2 ? c.poor : c.fair).withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final a in alerts.take(6))
                  ListTile(
                    dense: true,
                    leading: Icon(a.$3 == 2 ? Icons.error_rounded : Icons.schedule_rounded, color: a.$3 == 2 ? c.poor : c.fair),
                    title: Text(a.$1, style: LBText.body(c.ink, weight: FontWeight.w600)),
                    subtitle: Text(a.$2, style: LBText.body(c.inkDim, size: 12)),
                  ),
              ]),
            ),
          if (_tab == _Tab.instruments) ...[
            if (app.instruments.isEmpty)
              const EmptyState(icon: Icons.precision_manufacturing_outlined, title: 'No instruments', body: 'Add balances, meters and analysers with their calibration interval. LabLedger reminds you before they fall due.'),
            for (final i in app.instruments)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LBCard(
                  onTap: () => _editInstrument(context, i),
                  child: Row(children: [
                    Icon(Icons.precision_manufacturing_rounded, color: i.inService ? c.accent : c.inkDim),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i.name, style: LBText.body(c.ink, weight: FontWeight.w700)),
                        Text([i.model, if (i.serial.isNotEmpty) 'S/N ${i.serial}', i.location].where((x) => x.isNotEmpty).join(' · '),
                            style: LBText.body(c.inkDim, size: 12)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Tag('Calibration ${_dueText(i.calibrationDue)}', color: _dueColor(c, i.calibrationDue)),
                          if (i.serviceDue != null) ...[const SizedBox(width: 6), Flexible(child: Tag('Service ${_dueText(i.serviceDue)}', color: _dueColor(c, i.serviceDue)))],
                        ]),
                        if (!i.inService) Padding(padding: const EdgeInsets.only(top: 4), child: Tag('OUT OF SERVICE', color: c.poor)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Calibrated today',
                      icon: Icon(Icons.task_alt_rounded, color: c.good),
                      onPressed: () {
                        app.update(() => i.lastCalibration = DateTime.now());
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${i.name}: calibration recorded today.')));
                      },
                    ),
                  ]),
                ),
              ),
          ] else ...[
            if (app.reagents.isEmpty)
              const EmptyState(icon: Icons.science_outlined, title: 'No reagents or standards', body: 'Track lot numbers, expiry dates and stock so expired standards never reach a calibration.'),
            for (final r in ([...app.reagents]..sort((a, b) => (a.expiry ?? DateTime(2999)).compareTo(b.expiry ?? DateTime(2999)))))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LBCard(
                  onTap: () => _editReagent(context, r),
                  child: Row(children: [
                    Icon(r.kind == ReagentKind.crm ? Icons.verified_rounded : (r.kind == ReagentKind.standard ? Icons.straighten_rounded : Icons.science_rounded), color: c.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name, style: LBText.body(c.ink, weight: FontWeight.w700)),
                        Text([r.kind.label, if (r.lot.isNotEmpty) 'lot ${r.lot}', r.supplier, r.location].where((x) => x.isNotEmpty).join(' · '),
                            style: LBText.body(c.inkDim, size: 12)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          Tag(r.expiry == null ? 'No expiry set' : (daysUntil(r.expiry!) < 0 ? 'EXPIRED ${shortDate(r.expiry!)}' : 'Expires ${_dueText(r.expiry)}'),
                              color: _dueColor(c, r.expiry, soon: 30)),
                          if (r.quantity != null) Tag('${r.quantity!.toStringAsFixed(r.quantity! % 1 == 0 ? 0 : 1)} ${r.unit}', color: r.lowStock ? c.fair : c.inkDim),
                          if (r.opened != null) Tag('opened ${shortDate(r.opened!)}', color: c.inkDim),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? init) =>
      showDatePicker(context: context, initialDate: init ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));

  Future<void> _editInstrument(BuildContext context, Instrument? existing) async {
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
    final res = await showModalBottomSheet<String>(
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

  Future<void> _editReagent(BuildContext context, Reagent? existing) async {
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
    final res = await showModalBottomSheet<String>(
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
}
