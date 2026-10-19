import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/business_docs.dart';
import '../core/docx.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/data_grid.dart';
import '../widgets/inputs.dart';
import '../widgets/share.dart';
import 'sample_detail_screen.dart';

const _tabs = ['Requests & quotes', 'Invoices', 'Clients', 'Price list'];

class BusinessScreen extends StatefulWidget {
  final int tab;
  const BusinessScreen({super.key, this.tab = 0});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  late int _tab = widget.tab;
  final _q = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final q = _q.text.trim().toLowerCase();
    Widget body = switch (_tab) {
      0 => _requests(context, app, q),
      1 => _invoices(context, app, q),
      2 => _clients(context, app, q),
      _ => _prices(context, app, q),
    };
    return Scaffold(
      appBar: AppBar(title: Text(_tabs[_tab])),
      floatingActionButton: !app.canEdit
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                switch (_tab) {
                  case 0:
                    openRequestEditor(context, null);
                    break;
                  case 1:
                    openInvoiceEditor(context, null);
                    break;
                  case 2:
                    openClientEditor(context, null);
                    break;
                  default:
                    _editPrice(context, null);
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(const ['New request', 'New invoice', 'New client', 'New test / package'][_tab]),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Segmented<int>(values: const [0, 1, 2, 3], selected: _tab, label: (i) => _tabs[i], onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 10),
          TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search ${_tabs[_tab].toLowerCase()}',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(_q.clear)),
            ),
          ),
          const SizedBox(height: 12),
          body,
          const SizedBox(height: 6),
          Text('Amounts in ${app.settings.currency}. Change currency, tax and payment terms in Settings & tools.', style: LBText.body(c.inkDim, size: 11.5)),
        ],
      ),
    );
  }

  // ---------------- Requests ----------------
  Widget _requests(BuildContext context, AppState app, String q) {
    final c = context.lb;
    final cur = app.settings.currency;
    final list = app.requests.where((r) {
      if (q.isEmpty) return true;
      return r.number.toLowerCase().contains(q) || r.project.toLowerCase().contains(q) || (app.client(r.clientId)?.name.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    Color stCol(RequestStatus s) => switch (s) {
          RequestStatus.quote => c.inkDim,
          RequestStatus.accepted => c.accent,
          RequestStatus.inProgress => c.fair,
          RequestStatus.completed => c.good,
          RequestStatus.cancelled => c.poor,
        };
    if (isWide(context)) {
      return DataGrid<LabRequest>(
        rows: list,
        onTap: (r) => openRequestEditor(context, r),
        initialSort: 1,
        initialAscending: false,
        empty: 'No requests yet. A request starts as a quotation and becomes a work order when accepted.',
        columns: [
          GridColumn('Number', width: 130, cell: (r) => gridText(context, r.number, mono: true, bold: true), sortKey: (r) => r.number),
          GridColumn('Date', width: 110, cell: (r) => gridText(context, shortDate(r.date)), sortKey: (r) => r.date),
          GridColumn('Client', flex: 2, cell: (r) => gridText(context, app.client(r.clientId)?.name ?? '—'), sortKey: (r) => app.client(r.clientId)?.name ?? ''),
          GridColumn('Project', flex: 2, cell: (r) => gridText(context, r.project), sortKey: (r) => r.project),
          GridColumn('Samples', width: 80, numeric: true, cell: (r) => gridText(context, '${app.samplesForRequest(r.id).length}', mono: true), sortKey: (r) => app.samplesForRequest(r.id).length),
          GridColumn('Due', width: 110, cell: (r) => gridText(context, r.dueDate == null ? '—' : shortDate(r.dueDate!)), sortKey: (r) => r.dueDate ?? DateTime(2100)),
          GridColumn('Status', width: 120, cell: (r) => Tag(r.status.label, color: stCol(r.status)), sortKey: (r) => r.status.index),
          GridColumn('Total', width: 120, numeric: true, cell: (r) => gridText(context, money(r.total, cur), mono: true, bold: true), sortKey: (r) => r.total),
        ],
      );
    }
    if (list.isEmpty) return const EmptyState(icon: Icons.request_quote_outlined, title: 'No requests yet', body: 'Create a quotation for a client, then register samples against it.');
    return Column(children: [
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => openRequestEditor(context, r),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.number, style: LBText.reading(14, c.ink, weight: FontWeight.w700)),
                  Text(app.client(r.clientId)?.name ?? '—', style: LBText.body(c.ink, size: 13)),
                  Text('${shortDate(r.date)}${r.project.isEmpty ? '' : ' · ${r.project}'}', style: LBText.body(c.inkDim, size: 12), overflow: TextOverflow.ellipsis),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money(r.total, cur), style: LBText.reading(14, c.ink, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Tag(r.status.label, color: stCol(r.status)),
              ]),
            ]),
          ),
        ),
    ]);
  }

  // ---------------- Invoices ----------------
  Widget _invoices(BuildContext context, AppState app, String q) {
    final c = context.lb;
    final cur = app.settings.currency;
    final list = app.invoices.where((i) {
      if (q.isEmpty) return true;
      return i.number.toLowerCase().contains(q) || (app.client(i.clientId)?.name.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    Color stCol(InvoiceStatus s) => switch (s) {
          InvoiceStatus.paid => c.good,
          InvoiceStatus.partial => c.fair,
          InvoiceStatus.overdue => c.poor,
          InvoiceStatus.unpaid => c.accent,
          _ => c.inkDim,
        };
    final now = DateTime.now();
    final paidMonth = app.invoices.expand((i) => i.payments).where((p) => p.date.year == now.year && p.date.month == now.month).fold(0.0, (a, p) => a + p.amount);
    final overdue = app.invoices.where((i) => i.status == InvoiceStatus.overdue).toList();
    final summary = Wrap(spacing: 10, runSpacing: 10, children: [
      _stat(context, 'Outstanding', money(app.outstanding, cur), c.fair),
      _stat(context, 'Overdue', '${money(overdue.fold(0.0, (a, i) => a + i.balance), cur)} · ${overdue.length}', c.poor),
      _stat(context, 'Collected this month', money(paidMonth, cur), c.good),
      _stat(context, 'Invoiced this year', money(app.invoices.where((i) => !i.cancelled && i.date.year == now.year).fold(0.0, (a, i) => a + i.total), cur), c.accent),
    ]);
    Widget content;
    if (isWide(context)) {
      content = DataGrid<Invoice>(
        rows: list,
        onTap: (i) => openInvoiceEditor(context, i),
        initialSort: 1,
        initialAscending: false,
        empty: 'No invoices yet.',
        columns: [
          GridColumn('Number', width: 130, cell: (i) => gridText(context, i.number, mono: true, bold: true), sortKey: (i) => i.number),
          GridColumn('Date', width: 110, cell: (i) => gridText(context, shortDate(i.date)), sortKey: (i) => i.date),
          GridColumn('Client', flex: 2, cell: (i) => gridText(context, app.client(i.clientId)?.name ?? '—'), sortKey: (i) => app.client(i.clientId)?.name ?? ''),
          GridColumn('Due', width: 110, cell: (i) => gridText(context, shortDate(i.dueDate), color: i.status == InvoiceStatus.overdue ? c.poor : null), sortKey: (i) => i.dueDate),
          GridColumn('Total', width: 115, numeric: true, cell: (i) => gridText(context, money(i.total, cur), mono: true), sortKey: (i) => i.total),
          GridColumn('Paid', width: 115, numeric: true, cell: (i) => gridText(context, money(i.paid, cur), mono: true, color: c.good), sortKey: (i) => i.paid),
          GridColumn('Balance', width: 115, numeric: true, cell: (i) => gridText(context, money(i.balance, cur), mono: true, bold: true), sortKey: (i) => i.balance),
          GridColumn('Status', width: 110, cell: (i) => Tag(i.status.label, color: stCol(i.status)), sortKey: (i) => i.status.index),
        ],
      );
    } else if (list.isEmpty) {
      content = const EmptyState(icon: Icons.receipt_long_outlined, title: 'No invoices yet', body: 'Invoice a request in one tap, or create a stand-alone invoice.');
    } else {
      content = Column(children: [
        for (final i in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LBCard(
              onTap: () => openInvoiceEditor(context, i),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.number, style: LBText.reading(14, c.ink, weight: FontWeight.w700)),
                    Text(app.client(i.clientId)?.name ?? '—', style: LBText.body(c.ink, size: 13)),
                    Text('${shortDate(i.date)} · due ${shortDate(i.dueDate)}', style: LBText.body(c.inkDim, size: 12)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(i.balance > 0 ? i.balance : i.total, cur), style: LBText.reading(14, c.ink, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Tag(i.status.label, color: stCol(i.status)),
                ]),
              ]),
            ),
          ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [summary, const SizedBox(height: 12), content]);
  }

  Widget _stat(BuildContext context, String l, String v, Color col) {
    final c = context.lb;
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: col.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: col.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        PanelLabel(l),
        const SizedBox(height: 4),
        Text(v, style: LBText.reading(17, c.ink, weight: FontWeight.w700)),
      ]),
    );
  }

  // ---------------- Clients ----------------
  Widget _clients(BuildContext context, AppState app, String q) {
    final c = context.lb;
    final cur = app.settings.currency;
    final list = app.clients.where((x) => q.isEmpty || x.name.toLowerCase().contains(q) || x.contact.toLowerCase().contains(q) || x.phone.contains(q)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    double invoiced(Client cl) => app.invoices.where((i) => i.clientId == cl.id && !i.cancelled).fold(0.0, (a, i) => a + i.total);
    double balance(Client cl) => app.invoices.where((i) => i.clientId == cl.id && !i.cancelled).fold(0.0, (a, i) => a + (i.balance > 0 ? i.balance : 0));
    if (isWide(context)) {
      return DataGrid<Client>(
        rows: list,
        onTap: (x) => openClientEditor(context, x),
        initialSort: 0,
        empty: 'No clients yet.',
        columns: [
          GridColumn('Client', flex: 2.5, cell: (x) => gridText(context, x.name, bold: true), sortKey: (x) => x.name.toLowerCase()),
          GridColumn('Type', width: 120, cell: (x) => gridText(context, x.type.label), sortKey: (x) => x.type.index),
          GridColumn('Contact', flex: 1.5, cell: (x) => gridText(context, [x.contact, x.phone].where((s) => s.isNotEmpty).join('\n')), sortKey: (x) => x.contact),
          GridColumn('Samples', width: 80, numeric: true, cell: (x) => gridText(context, '${app.samples.where((s) => s.clientId == x.id).length}', mono: true),
              sortKey: (x) => app.samples.where((s) => s.clientId == x.id).length),
          GridColumn('Invoiced', width: 120, numeric: true, cell: (x) => gridText(context, money(invoiced(x), cur), mono: true), sortKey: (x) => invoiced(x)),
          GridColumn('Balance', width: 120, numeric: true, cell: (x) => gridText(context, money(balance(x), cur), mono: true, bold: true, color: balance(x) > 0 ? c.fair : null), sortKey: (x) => balance(x)),
        ],
      );
    }
    if (list.isEmpty) return const EmptyState(icon: Icons.business_outlined, title: 'No clients yet', body: 'Companies, ministries, NGOs and individuals you test samples for.');
    return Column(children: [
      for (final x in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => openClientEditor(context, x),
            child: Row(children: [
              CircleAvatar(backgroundColor: c.accent.withOpacity(0.15), child: Icon(Icons.business_rounded, color: c.accent, size: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.name, style: LBText.body(c.ink, weight: FontWeight.w700)),
                  Text([x.type.label, x.contact, x.phone].where((s) => s.isNotEmpty).join(' · '), style: LBText.body(c.inkDim, size: 12), overflow: TextOverflow.ellipsis),
                ]),
              ),
              if (balance(x) > 0) Tag(money(balance(x), cur), color: c.fair),
            ]),
          ),
        ),
    ]);
  }

  // ---------------- Price list ----------------
  Widget _prices(BuildContext context, AppState app, String q) {
    final c = context.lb;
    final cur = app.settings.currency;
    final list = app.prices.where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.code.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    if (isWide(context)) {
      return DataGrid<PriceItem>(
        rows: list,
        onTap: (p) => _editPrice(context, p),
        initialSort: 0,
        empty: 'Your list of tests and packages with prices and turnaround.',
        columns: [
          GridColumn('Code', width: 100, cell: (p) => gridText(context, p.code, mono: true, bold: true), sortKey: (p) => p.code),
          GridColumn('Test / package', flex: 3, cell: (p) => gridText(context, p.name, color: p.active ? null : c.inkDim), sortKey: (p) => p.name),
          GridColumn('Category', width: 130, cell: (p) => gridText(context, p.category), sortKey: (p) => p.category),
          GridColumn('Parameters', width: 100, numeric: true, cell: (p) => gridText(context, p.parameters.isEmpty ? '—' : '${p.parameters.length}', mono: true), sortKey: (p) => p.parameters.length),
          GridColumn('Turnaround', width: 110, numeric: true, cell: (p) => gridText(context, '${p.turnaroundDays} d', mono: true), sortKey: (p) => p.turnaroundDays),
          GridColumn('Price', width: 110, numeric: true, cell: (p) => gridText(context, money(p.price, cur), mono: true, bold: true), sortKey: (p) => p.price),
        ],
      );
    }
    if (list.isEmpty) return const EmptyState(icon: Icons.sell_outlined, title: 'No price list yet', body: 'Add the tests and packages you offer, with price and turnaround.');
    return Column(children: [
      for (final p in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LBCard(
            onTap: () => _editPrice(context, p),
            child: Row(children: [
              SizedBox(width: 70, child: Text(p.code, style: LBText.reading(12.5, c.accent, weight: FontWeight.w700))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: LBText.body(p.active ? c.ink : c.inkDim, weight: FontWeight.w600)),
                  Text('${p.category}${p.category.isEmpty ? '' : ' · '}${p.turnaroundDays} d turnaround', style: LBText.body(c.inkDim, size: 12)),
                ]),
              ),
              Text(money(p.price, cur), style: LBText.reading(14, c.ink, weight: FontWeight.w700)),
            ]),
          ),
        ),
    ]);
  }

  Future<void> _editPrice(BuildContext context, PriceItem? existing) async {
    final app = AppScope.read(context);
    if (!app.canEdit) return;
    final p = existing ?? PriceItem(id: newId(), code: '', name: '');
    final code = TextEditingController(text: p.code);
    final name = TextEditingController(text: p.name);
    final cat = TextEditingController(text: p.category);
    final price = TextEditingController(text: p.price == 0 ? '' : p.price.toStringAsFixed(2));
    final params = TextEditingController(text: p.parameters.join(', '));
    var tat = p.turnaroundDays;
    var active = p.active;
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
              Text(existing == null ? 'New test / package' : 'Edit price item', style: LBText.title(c.ink)),
              const SizedBox(height: 12),
              Row(children: [
                SizedBox(width: 110, child: TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Code'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: cat, decoration: const InputDecoration(labelText: 'Category', hintText: 'Metals, Microbiology…'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name shown on quotes and invoices')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Price (${app.settings.currency})'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Stepper2(label: 'Turnaround (days)', value: tat, min: 0, max: 90, onChanged: (v) => setS(() => tat = v))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: params, maxLines: 2, decoration: const InputDecoration(labelText: 'Parameters covered (optional, comma-separated)')),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setS(() => active = v), title: const Text('Offered (active)')),
              Row(children: [
                if (existing != null && app.isAdmin) IconButton(onPressed: () => Navigator.pop(context, 'delete'), icon: Icon(Icons.delete_outline_rounded, color: c.poor)),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save'))),
              ]),
            ]),
          ),
        );
      }),
    );
    if (res == 'delete') {
      app.update(() {
        app.prices.remove(existing);
        app.log('delete', 'Price item', p.code, p.name);
      });
    }
    if (res == 'save' && name.text.trim().isNotEmpty) {
      app.update(() {
        p
          ..code = code.text.trim().isEmpty ? 'T${app.prices.length + 1}' : code.text.trim().toUpperCase()
          ..name = name.text.trim()
          ..category = cat.text.trim()
          ..price = double.tryParse(price.text.trim()) ?? 0
          ..turnaroundDays = tat
          ..parameters = params.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          ..active = active;
        if (existing == null) app.prices.add(p);
        app.log(existing == null ? 'create' : 'update', 'Price item', p.code, '${p.name} · ${money(p.price, app.settings.currency)}');
      });
    }
  }
}

// ---------------------------------------------------------------------------
// Shared: line items editor
// ---------------------------------------------------------------------------

class LinesEditor extends StatefulWidget {
  final List<DocLine> lines;
  final VoidCallback onChanged;
  final bool readOnly;
  const LinesEditor({super.key, required this.lines, required this.onChanged, this.readOnly = false});

  @override
  State<LinesEditor> createState() => _LinesEditorState();
}

class _LinesEditorState extends State<LinesEditor> {
  Future<void> _addFromList() async {
    final app = AppScope.read(context);
    final items = app.prices.where((p) => p.active).toList()..sort((a, b) => a.code.compareTo(b.code));
    final picked = await showModalBottomSheet<PriceItem>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final c = context.lb;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
            child: ListView(shrinkWrap: true, children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Add from price list', style: LBText.title(c.ink))),
              if (items.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('The price list is empty. Add tests under Business → Price list.', style: LBText.body(c.inkDim))),
              for (final p in items)
                ListTile(
                  leading: Text(p.code, style: LBText.reading(12, c.accent, weight: FontWeight.w700)),
                  title: Text(p.name, style: LBText.body(c.ink, size: 13.5)),
                  subtitle: Text(p.category, style: LBText.body(c.inkDim, size: 11.5)),
                  trailing: Text(money(p.price, app.settings.currency), style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
                  onTap: () => Navigator.pop(context, p),
                ),
            ]),
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() => widget.lines.add(DocLine(description: '${picked.code} · ${picked.name}', unitPrice: picked.price, priceItemId: picked.id)));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final cur = app.settings.currency;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < widget.lines.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
          child: Row(children: [
            Expanded(
              flex: 5,
              child: TextFormField(
                key: ValueKey('d$i${widget.lines[i].hashCode}'),
                initialValue: widget.lines[i].description,
                readOnly: widget.readOnly,
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, filled: false, hintText: 'Description'),
                style: LBText.body(c.ink, size: 13),
                onChanged: (v) {
                  widget.lines[i].description = v;
                  widget.onChanged();
                },
              ),
            ),
            SizedBox(
              width: 56,
              child: TextFormField(
                key: ValueKey('q$i${widget.lines[i].hashCode}'),
                initialValue: widget.lines[i].qty == widget.lines[i].qty.roundToDouble() ? widget.lines[i].qty.toStringAsFixed(0) : '${widget.lines[i].qty}',
                readOnly: widget.readOnly,
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, labelText: 'Qty'),
                style: LBText.reading(13, c.ink),
                onChanged: (v) {
                  widget.lines[i].qty = double.tryParse(v) ?? 0;
                  setState(() {});
                  widget.onChanged();
                },
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 88,
              child: TextFormField(
                key: ValueKey('p$i${widget.lines[i].hashCode}'),
                initialValue: widget.lines[i].unitPrice.toStringAsFixed(2),
                readOnly: widget.readOnly,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, labelText: 'Unit'),
                style: LBText.reading(13, c.ink),
                onChanged: (v) {
                  widget.lines[i].unitPrice = double.tryParse(v) ?? 0;
                  setState(() {});
                  widget.onChanged();
                },
              ),
            ),
            SizedBox(width: 92, child: Text(money(widget.lines[i].total, cur), textAlign: TextAlign.right, style: LBText.reading(13, c.ink, weight: FontWeight.w700))),
            if (!widget.readOnly)
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: c.inkDim),
                onPressed: () {
                  setState(() => widget.lines.removeAt(i));
                  widget.onChanged();
                },
              ),
          ]),
        ),
      if (!widget.readOnly)
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(onPressed: _addFromList, icon: const Icon(Icons.playlist_add_rounded), label: const Text('From price list')),
          TextButton.icon(
            onPressed: () {
              setState(() => widget.lines.add(DocLine(description: '')));
              widget.onChanged();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Custom line'),
          ),
        ]),
    ]);
  }
}

Widget totalsBox(BuildContext context, Priced d, String cur, {Invoice? inv}) {
  final c = context.lb;
  Widget row(String k, String v, {bool strong = false, Color? col}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: LBText.body(strong ? c.ink : c.inkDim, size: strong ? 15 : 13, weight: strong ? FontWeight.w700 : FontWeight.w400))),
          Text(v, style: LBText.reading(strong ? 18 : 13.5, col ?? c.ink, weight: strong ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );
  return LBCard(
    child: Column(children: [
      row('Subtotal', money(d.subtotal, cur)),
      if (d.discountPct > 0) row('Discount (${_pct(d.discountPct)}%)', '-${money(d.discount, cur)}'),
      if (d.taxPct > 0) row('Tax (${_pct(d.taxPct)}%)', money(d.tax, cur)),
      Divider(color: c.line),
      row('Total', money(d.total, cur), strong: true),
      if (inv != null && inv.paid > 0) ...[
        row('Paid', '-${money(inv.paid, cur)}', col: c.good),
        row('Balance due', money(inv.balance, cur), strong: true, col: inv.balance > 0 ? c.poor : c.good),
      ],
    ]),
  );
}

Future<void> _share(BuildContext context, Future<Uint8List> Function() make, String name, String mime) async {
  final bytes = await make();
  if (context.mounted) await shareBytes(context, name, bytes, mime);
}

// ---------------------------------------------------------------------------
// Request editor
// ---------------------------------------------------------------------------

void openRequestEditor(BuildContext context, LabRequest? r) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestEditorScreen(request: r)));

class RequestEditorScreen extends StatefulWidget {
  final LabRequest? request;
  const RequestEditorScreen({super.key, this.request});

  @override
  State<RequestEditorScreen> createState() => _RequestEditorScreenState();
}

class _RequestEditorScreenState extends State<RequestEditorScreen> {
  late LabRequest _r;
  late final TextEditingController _project, _notes;
  bool _isNew = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.read(context);
    if (widget.request == null) {
      _isNew = true;
      _r = LabRequest(id: newId(), number: app.nextRequestNumber(), taxPct: app.settings.defaultTaxPct, dueDate: DateTime.now().add(const Duration(days: 10)));
    } else {
      _r = widget.request!;
    }
    _project = TextEditingController(text: _r.project);
    _notes = TextEditingController(text: _r.notes == 'Demo item' ? '' : _r.notes);
  }

  void _save({bool pop = true}) {
    final app = AppScope.read(context);
    app.update(() {
      _r.project = _project.text.trim();
      if (_r.notes != 'Demo item' || _notes.text.isNotEmpty) _r.notes = _notes.text.trim();
      if (!app.requests.contains(_r)) {
        app.requests.insert(0, _r);
        app.log('create', 'Request', _r.number, '${app.client(_r.clientId)?.name ?? ''} · ${money(_r.total, app.settings.currency)}');
      } else {
        app.log('update', 'Request', _r.number, '${_r.status.label} · ${money(_r.total, app.settings.currency)}');
      }
      for (final s in app.samplesForRequest(_r.id)) {
        s.clientId = _r.clientId;
        s.dueDate ??= _r.dueDate;
      }
    });
    if (pop) Navigator.pop(context);
  }

  Future<void> _registerSamples() async {
    final app = AppScope.read(context);
    final prefix = TextEditingController();
    var n = 1;
    var matrix = Matrix.surfaceWater;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text('Register samples'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Creates samples linked to ${_r.number}, numbered within the project.', style: LBText.body(context.lb.inkDim, size: 12.5)),
            const SizedBox(height: 10),
            Stepper2(label: 'Number of samples', value: n, min: 1, max: 100, onChanged: (v) => setS(() => n = v)),
            const SizedBox(height: 10),
            TextField(controller: prefix, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Site prefix (e.g. KR)', isDense: true)),
            const SizedBox(height: 10),
            DropdownButtonFormField<Matrix>(
              value: matrix,
              decoration: const InputDecoration(labelText: 'Matrix', isDense: true),
              items: [for (final m in Matrix.values) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (m) => setS(() => matrix = m ?? matrix),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    _save(pop: false);
    final project = _r.project.isEmpty ? _r.number : _r.project;
    app.update(() {
      for (var i = 0; i < n; i++) {
        final seq = app.nextProjectSeq(project);
        final s = Sample(
          id: newId(),
          code: prefix.text.trim().isEmpty ? app.nextCode() : buildSampleCode(prefix.text, matrix, seq),
          project: project,
          matrix: matrix,
          clientId: _r.clientId,
          requestId: _r.id,
          dueDate: _r.dueDate,
          receivedAt: DateTime.now(),
          status: SampleStatus.received,
          limitSetId: matrix.isSolid ? null : app.settings.defaultLimitSetId,
          collector: app.userName,
        );
        if (prefix.text.trim().isEmpty) app.settings.nextSeq++;
        app.samples.insert(0, s);
      }
      if (_r.status == RequestStatus.quote || _r.status == RequestStatus.accepted) _r.status = RequestStatus.inProgress;
      app.log('create', 'Sample', project, '$n samples registered for ${_r.number}');
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final cur = app.settings.currency;
    final ro = !app.canEdit;
    final samples = app.samplesForRequest(_r.id);
    final inv = app.invoices.where((i) => i.requestId == _r.id).toList();
    final clientsSorted = [...app.clients]..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(
        title: Text(_r.number),
        actions: [
          IconButton(
            tooltip: 'Quotation PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () => _share(context, () => BusinessDocs.pdf(app, request: _r), '${_r.number}_quotation.pdf', 'application/pdf'),
          ),
          IconButton(
            tooltip: 'Quotation Word',
            icon: const Icon(Icons.description_rounded),
            onPressed: () => _share(context, () async => BusinessDocs.word(app, request: _r), '${_r.number}_quotation.docx', docxMime),
          ),
          if (!ro) TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in RequestStatus.values)
                    ChoiceChip(label: Text(s.label), selected: _r.status == s, onSelected: ro ? null : (_) => setState(() => _r.status = s)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: app.client(_r.clientId) == null ? null : _r.clientId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Client'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('— choose —')),
                        for (final cl in clientsSorted) DropdownMenuItem<String?>(value: cl.id, child: Text(cl.name, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: ro ? null : (v) => setState(() => _r.clientId = v),
                    ),
                  ),
                  if (!ro)
                    IconButton(
                      tooltip: 'New client',
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      onPressed: () async {
                        final cl = await openClientEditor(context, null);
                        if (cl != null) setState(() => _r.clientId = cl.id);
                      },
                    ),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _project, readOnly: ro, decoration: const InputDecoration(labelText: 'Project / reference')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ro
                          ? null
                          : () async {
                              final d = await showDatePicker(context: context, initialDate: _r.date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) setState(() => _r.date = d);
                            },
                      icon: const Icon(Icons.event_rounded),
                      label: Text('Date ${shortDate(_r.date)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ro
                          ? null
                          : () async {
                              final d = await showDatePicker(context: context, initialDate: _r.dueDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) setState(() => _r.dueDate = d);
                            },
                      icon: const Icon(Icons.flag_rounded),
                      label: Text(_r.dueDate == null ? 'Results due' : 'Due ${shortDate(_r.dueDate!)}'),
                    ),
                  ),
                ]),
                const SectionHeader('Tests & services'),
                LinesEditor(lines: _r.lines, readOnly: ro, onChanged: () => setState(() {})),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _pctField('Discount %', _r.discountPct, ro, (v) => setState(() => _r.discountPct = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _pctField('Tax / GST %', _r.taxPct, ro, (v) => setState(() => _r.taxPct = v))),
                ]),
                const SizedBox(height: 12),
                totalsBox(context, _r, cur),
                const SizedBox(height: 12),
                TextField(controller: _notes, readOnly: ro, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes / sampling instructions')),
                SectionHeader('Samples (${samples.length})',
                    trailing: ro ? null : TextButton.icon(onPressed: _registerSamples, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Register'))),
                if (samples.isEmpty)
                  Text('No samples registered against this request yet.', style: LBText.body(c.inkDim, size: 13))
                else
                  LBCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final s in samples)
                        ListTile(
                          dense: true,
                          title: Text(s.code, style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
                          subtitle: Text('${s.matrix.label} · ${s.results.length} results', style: LBText.body(c.inkDim, size: 12)),
                          trailing: Tag(s.status.label, color: s.status == SampleStatus.reported ? c.good : c.accent),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s))),
                        ),
                    ]),
                  ),
                SectionHeader('Invoices (${inv.length})'),
                for (final i in inv)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.receipt_long_rounded, color: c.accent),
                    title: Text(i.number, style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
                    subtitle: Text('${shortDate(i.date)} · ${i.status.label}', style: LBText.body(c.inkDim, size: 12)),
                    trailing: Text(money(i.total, cur), style: LBText.reading(13, c.ink)),
                    onTap: () => openInvoiceEditor(context, i),
                  ),
                if (!ro)
                  FilledButton.tonalIcon(
                    onPressed: _r.lines.isEmpty
                        ? null
                        : () {
                            _save(pop: false);
                            late Invoice created;
                            app.update(() => created = app.invoiceFromRequest(_r));
                            openInvoiceEditor(context, created);
                          },
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('Create invoice from this request'),
                  ),
                if (!ro && !_isNew && app.isAdmin) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await _confirm(context, 'Delete ${_r.number}?', 'Linked samples and invoices are kept.');
                      if (ok && context.mounted) {
                        app.update(() {
                          app.requests.remove(_r);
                          app.log('delete', 'Request', _r.number, '');
                        });
                        Navigator.pop(context);
                      }
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: c.poor),
                    label: Text('Delete request', style: TextStyle(color: c.poor)),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _pctField(String label, double v, bool ro, ValueChanged<double> on) => TextFormField(
      initialValue: v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'),
      readOnly: ro,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true, suffixText: '%'),
      onChanged: (s) => on(double.tryParse(s) ?? 0),
    );

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
      ],
    ),
  );
  return r == true;
}

// ---------------------------------------------------------------------------
// Invoice editor
// ---------------------------------------------------------------------------

void openInvoiceEditor(BuildContext context, Invoice? i) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoiceEditorScreen(invoice: i)));

class InvoiceEditorScreen extends StatefulWidget {
  final Invoice? invoice;
  const InvoiceEditorScreen({super.key, this.invoice});

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  Invoice? _iv;
  late TextEditingController _notes;

  Invoice get _i => _iv!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iv != null) return;
    final app = AppScope.read(context);
    _iv = widget.invoice ??
        Invoice(
          id: newId(),
          number: app.nextInvoiceNumber(),
          taxPct: app.settings.defaultTaxPct,
          dueDate: DateTime.now().add(Duration(days: app.settings.paymentTermsDays)),
          issued: false,
        );
    _notes = TextEditingController(text: _i.notes == 'Demo item' ? '' : _i.notes);
  }

  void _save({bool pop = true}) {
    final app = AppScope.read(context);
    app.update(() {
      if (_i.notes != 'Demo item' || _notes.text.isNotEmpty) _i.notes = _notes.text.trim();
      if (!app.invoices.contains(_i)) {
        app.invoices.insert(0, _i);
        app.log('create', 'Invoice', _i.number, '${app.client(_i.clientId)?.name ?? ''} · ${money(_i.total, app.settings.currency)}');
      } else {
        app.log('update', 'Invoice', _i.number, '${_i.status.label} · ${money(_i.total, app.settings.currency)}');
      }
    });
    if (pop) Navigator.pop(context);
  }

  Future<void> _addPayment() async {
    final app = AppScope.read(context);
    final amount = TextEditingController(text: _i.balance > 0 ? _i.balance.toStringAsFixed(2) : '');
    final ref = TextEditingController();
    var method = 'Cash';
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text('Record payment'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount (${app.settings.currency})'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(labelText: 'Method', isDense: true),
              items: [for (final m in const ['Cash', 'Bank transfer', 'Mobile money', 'Cheque', 'Card']) DropdownMenuItem(value: m, child: Text(m))],
              onChanged: (v) => setS(() => method = v ?? method),
            ),
            const SizedBox(height: 10),
            TextField(controller: ref, decoration: const InputDecoration(labelText: 'Reference (transaction / cheque no.)', isDense: true)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setS(() => date = d);
              },
              icon: const Icon(Icons.event_rounded),
              label: Text(shortDate(date)),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record')),
          ],
        ),
      ),
    );
    final a = double.tryParse(amount.text.trim()) ?? 0;
    if (ok != true || a <= 0) return;
    late Payment p;
    app.update(() {
      p = Payment(id: newId(), amount: a, date: date, method: method, reference: ref.text.trim(), receiptNo: app.nextReceiptNumber());
      _i.payments.add(p);
      _i.issued = true;
      if (!app.invoices.contains(_i)) app.invoices.insert(0, _i);
      app.log('payment', 'Invoice', _i.number, '${money(a, app.settings.currency)} by $method · ${p.receiptNo}');
    });
    setState(() {});
    if (!mounted) return;
    final print = await _confirm(context, 'Payment recorded', 'Receipt ${p.receiptNo} for ${money(a, app.settings.currency)}. Share the receipt now?');
    if (print && mounted) await _share(context, () => BusinessDocs.receipt(app, _i, p), '${p.receiptNo}.pdf', 'application/pdf');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final cur = app.settings.currency;
    final ro = !app.canEdit;
    final clientsSorted = [...app.clients]..sort((a, b) => a.name.compareTo(b.name));
    final st = _i.status;
    return Scaffold(
      appBar: AppBar(
        title: Text(_i.number),
        actions: [
          IconButton(
            tooltip: 'Invoice PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: () => _share(context, () => BusinessDocs.pdf(app, invoice: _i), '${_i.number}.pdf', 'application/pdf'),
          ),
          IconButton(
            tooltip: 'Invoice Word',
            icon: const Icon(Icons.description_rounded),
            onPressed: () => _share(context, () async => BusinessDocs.word(app, invoice: _i), '${_i.number}.docx', docxMime),
          ),
          if (!ro) TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Tag(st.label, color: switch (st) { InvoiceStatus.paid => c.good, InvoiceStatus.overdue => c.poor, InvoiceStatus.partial => c.fair, _ => c.accent }),
                  const Spacer(),
                  if (!ro && !_i.cancelled)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Issued', style: LBText.body(c.inkDim, size: 12.5)),
                      Switch(value: _i.issued, onChanged: (v) => setState(() => _i.issued = v)),
                    ]),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: app.client(_i.clientId) == null ? null : _i.clientId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bill to'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— choose client —')),
                    for (final cl in clientsSorted) DropdownMenuItem<String?>(value: cl.id, child: Text(cl.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: ro ? null : (v) => setState(() => _i.clientId = v),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ro
                          ? null
                          : () async {
                              final d = await showDatePicker(context: context, initialDate: _i.date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) setState(() => _i.date = d);
                            },
                      icon: const Icon(Icons.event_rounded),
                      label: Text('Date ${shortDate(_i.date)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: ro
                          ? null
                          : () async {
                              final d = await showDatePicker(context: context, initialDate: _i.dueDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                              if (d != null) setState(() => _i.dueDate = d);
                            },
                      icon: const Icon(Icons.flag_rounded),
                      label: Text('Due ${shortDate(_i.dueDate)}'),
                    ),
                  ),
                ]),
                if (_i.requestId != null) ...[
                  const SizedBox(height: 8),
                  Text('For request ${app.request(_i.requestId)?.number ?? ''}', style: LBText.body(c.inkDim, size: 12.5)),
                ],
                const SectionHeader('Items'),
                LinesEditor(lines: _i.lines, readOnly: ro || _i.payments.isNotEmpty, onChanged: () => setState(() {})),
                if (_i.payments.isNotEmpty) Text('Items are locked once a payment is recorded.', style: LBText.body(c.inkDim, size: 11.5)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _pctField('Discount %', _i.discountPct, ro || _i.payments.isNotEmpty, (v) => setState(() => _i.discountPct = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _pctField('Tax / GST %', _i.taxPct, ro || _i.payments.isNotEmpty, (v) => setState(() => _i.taxPct = v))),
                ]),
                const SizedBox(height: 12),
                totalsBox(context, _i, cur, inv: _i),
                SectionHeader('Payments (${_i.payments.length})',
                    trailing: ro || _i.cancelled ? null : TextButton.icon(onPressed: _addPayment, icon: const Icon(Icons.add_card_rounded, size: 18), label: const Text('Record payment'))),
                for (final p in _i.payments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.payments_rounded, color: c.good),
                    title: Text('${money(p.amount, cur)} · ${p.method}', style: LBText.body(c.ink, weight: FontWeight.w600)),
                    subtitle: Text('${shortDate(p.date)} · ${p.receiptNo}${p.reference.isEmpty ? '' : ' · ref ${p.reference}'}', style: LBText.body(c.inkDim, size: 12)),
                    trailing: IconButton(
                      tooltip: 'Receipt PDF',
                      icon: const Icon(Icons.receipt_rounded),
                      onPressed: () => _share(context, () => BusinessDocs.receipt(app, _i, p), '${p.receiptNo}.pdf', 'application/pdf'),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(controller: _notes, readOnly: ro, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes on the invoice')),
                if (!ro && app.isAdmin && app.invoices.contains(_i)) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await _confirm(context, _i.cancelled ? 'Reinstate ${_i.number}?' : 'Cancel ${_i.number}?',
                          'Cancelled invoices stay on record (for the audit trail) but are excluded from totals.');
                      if (ok) {
                        app.update(() {
                          _i.cancelled = !_i.cancelled;
                          app.log(_i.cancelled ? 'cancel' : 'reinstate', 'Invoice', _i.number, '');
                        });
                        setState(() {});
                      }
                    },
                    icon: Icon(Icons.block_rounded, color: c.poor),
                    label: Text(_i.cancelled ? 'Reinstate invoice' : 'Cancel invoice', style: TextStyle(color: c.poor)),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Client editor / profile
// ---------------------------------------------------------------------------

Future<Client?> openClientEditor(BuildContext context, Client? cl) =>
    Navigator.of(context).push<Client>(MaterialPageRoute(builder: (_) => ClientScreen(client: cl)));

class ClientScreen extends StatefulWidget {
  final Client? client;
  const ClientScreen({super.key, this.client});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  late final Client _c = widget.client ?? Client(id: newId(), name: '');
  late final _name = TextEditingController(text: _c.name);
  late final _contact = TextEditingController(text: _c.contact);
  late final _phone = TextEditingController(text: _c.phone);
  late final _email = TextEditingController(text: _c.email);
  late final _address = TextEditingController(text: _c.address);
  late final _tax = TextEditingController(text: _c.taxId);
  late final _notes = TextEditingController(text: _c.notes == 'Demo item' ? '' : _c.notes);

  void _save() {
    final app = AppScope.read(context);
    if (_name.text.trim().isEmpty) return;
    app.update(() {
      _c
        ..name = _name.text.trim()
        ..contact = _contact.text.trim()
        ..phone = _phone.text.trim()
        ..email = _email.text.trim()
        ..address = _address.text.trim()
        ..taxId = _tax.text.trim();
      if (_c.notes != 'Demo item' || _notes.text.isNotEmpty) _c.notes = _notes.text.trim();
      if (!app.clients.contains(_c)) {
        app.clients.add(_c);
        app.log('create', 'Client', _c.name, _c.type.label);
      } else {
        app.log('update', 'Client', _c.name, '');
      }
    });
    Navigator.pop(context, _c);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final cur = app.settings.currency;
    final ro = !app.canEdit;
    final reqs = app.requests.where((r) => r.clientId == _c.id).toList();
    final invs = app.invoices.where((i) => i.clientId == _c.id && !i.cancelled).toList();
    final samples = app.samples.where((s) => s.clientId == _c.id).toList();
    final invoiced = invs.fold(0.0, (a, i) => a + i.total);
    final paid = invs.fold(0.0, (a, i) => a + i.paid);
    Widget gap() => const SizedBox(height: 10);
    return Scaffold(
      appBar: AppBar(title: Text(widget.client == null ? 'New client' : _c.name), actions: [if (!ro) TextButton(onPressed: _save, child: const Text('Save'))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (widget.client != null)
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _mini(context, 'Samples', '${samples.length}'),
                    _mini(context, 'Requests', '${reqs.length}'),
                    _mini(context, 'Invoiced', money(invoiced, cur)),
                    _mini(context, 'Balance', money(invoiced - paid, cur), col: invoiced - paid > 0 ? c.fair : c.good),
                  ]),
                gap(),
                TextField(controller: _name, readOnly: ro, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Client / organisation name')),
                gap(),
                Segmented<ClientType>(values: ClientType.values, selected: _c.type, label: (t) => t.label, onChanged: (t) {
                  if (!ro) setState(() => _c.type = t);
                }),
                gap(),
                Row(children: [
                  Expanded(child: TextField(controller: _contact, readOnly: ro, decoration: const InputDecoration(labelText: 'Contact person'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _phone, readOnly: ro, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))),
                ]),
                gap(),
                Row(children: [
                  Expanded(child: TextField(controller: _email, readOnly: ro, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _tax, readOnly: ro, decoration: const InputDecoration(labelText: 'Tax ID (TIN)'))),
                ]),
                gap(),
                TextField(controller: _address, readOnly: ro, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
                gap(),
                TextField(controller: _notes, readOnly: ro, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
                if (reqs.isNotEmpty) ...[
                  const SectionHeader('Requests'),
                  for (final r in reqs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.number, style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
                      subtitle: Text('${shortDate(r.date)} · ${r.status.label}${r.project.isEmpty ? '' : ' · ${r.project}'}', style: LBText.body(c.inkDim, size: 12)),
                      trailing: Text(money(r.total, cur), style: LBText.reading(13, c.ink)),
                      onTap: () => openRequestEditor(context, r),
                    ),
                ],
                if (invs.isNotEmpty) ...[
                  const SectionHeader('Invoices'),
                  for (final i in invs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i.number, style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
                      subtitle: Text('${shortDate(i.date)} · ${i.status.label}', style: LBText.body(c.inkDim, size: 12)),
                      trailing: Text(money(i.balance > 0 ? i.balance : i.total, cur), style: LBText.reading(13, c.ink)),
                      onTap: () => openInvoiceEditor(context, i),
                    ),
                ],
                if (widget.client != null && !ro && app.isAdmin && reqs.isEmpty && invs.isEmpty) ...[
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () {
                      app.update(() {
                        app.clients.remove(_c);
                        app.log('delete', 'Client', _c.name, '');
                      });
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: c.poor),
                    label: Text('Delete client', style: TextStyle(color: c.poor)),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(BuildContext context, String l, String v, {Color? col}) {
    final c = context.lb;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        PanelLabel(l),
        const SizedBox(height: 4),
        Text(v, style: LBText.reading(16, col ?? c.ink, weight: FontWeight.w700)),
      ]),
    );
  }
}

String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
