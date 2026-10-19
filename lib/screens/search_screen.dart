import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/lab_models.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/panels.dart';
import 'business_screen.dart';
import 'field_screen.dart';
import 'quality_screen.dart';
import 'register_screen.dart';
import 'sample_detail_screen.dart';

class _Hit {
  final IconData icon;
  final String kind;
  final String title;
  final String sub;
  final void Function(BuildContext) open;
  _Hit(this.icon, this.kind, this.title, this.sub, this.open);
}

/// Search everything (Ctrl+K on a PC): samples, clients, requests, invoices,
/// trips, methods, non-conformances, instruments and reagents.
Future<void> showGlobalSearch(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _SearchDialog(origin: context),
  );
}

class _SearchDialog extends StatefulWidget {
  final BuildContext origin;
  const _SearchDialog({required this.origin});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  String _q = '';
  int _sel = 0;

  List<_Hit> _hits(AppState app) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return const [];
    bool m(Iterable<String> f) => f.any((x) => x.toLowerCase().contains(q));
    final out = <_Hit>[];
    for (final s in app.samples) {
      if (m([s.code, s.site, s.project, s.collector])) {
        out.add(_Hit(Icons.science_rounded, 'Sample', s.code, [s.site, s.project, s.status.label].where((x) => x.isNotEmpty).join(' · '), (c) => openPage(c, SampleDetailScreen(sample: s))));
      }
    }
    for (final cl in app.clients) {
      if (m([cl.name, cl.contact, cl.email, cl.phone])) out.add(_Hit(Icons.business_rounded, 'Client', cl.name, [cl.contact, cl.phone].where((x) => x.isNotEmpty).join(' · '), (c) => openClientEditor(c, cl)));
    }
    for (final r in app.requests) {
      if (m([r.number, r.project, app.client(r.clientId)?.name ?? ''])) {
        out.add(_Hit(Icons.request_quote_rounded, 'Request', r.number, '${app.client(r.clientId)?.name ?? ''} · ${r.status.label}', (c) => openRequestEditor(c, r)));
      }
    }
    for (final i in app.invoices) {
      if (m([i.number, app.client(i.clientId)?.name ?? ''])) {
        out.add(_Hit(Icons.receipt_long_rounded, 'Invoice', i.number, '${app.client(i.clientId)?.name ?? ''} · ${i.status.label} · ${money(i.balance, app.settings.currency)} due', (c) => openInvoiceEditor(c, i)));
      }
    }
    for (final t in app.trips) {
      if (m([t.title, t.project, ...t.team])) out.add(_Hit(Icons.route_rounded, 'Field trip', t.title, '${shortDate(t.date)} · ${t.status.label}', (c) => openTripEditor(c, t)));
    }
    for (final x in app.methods) {
      if (m([x.code, x.title, x.technique, ...x.parameters])) out.add(_Hit(Icons.menu_book_rounded, 'Method', x.code, x.title, (c) => openMethodEditor(c, x)));
    }
    for (final n in app.ncs) {
      if (m([n.number, n.title, n.reference])) out.add(_Hit(Icons.report_problem_rounded, 'Non-conformance', n.number, '${n.title} · ${n.status.label}', (c) => openNcEditor(c, n)));
    }
    for (final i in app.instruments) {
      if (m([i.name, i.model, i.serial])) out.add(_Hit(Icons.precision_manufacturing_rounded, 'Instrument', i.name, [i.model, i.serial].where((x) => x.isNotEmpty).join(' · '), (c) => openInstrumentLog(c, i)));
    }
    for (final r in app.reagents) {
      if (m([r.name, r.lot, r.supplier])) out.add(_Hit(Icons.inventory_2_rounded, 'Reagent', r.name, [r.lot, r.supplier].where((x) => x.isNotEmpty).join(' · '), (c) => editReagent(c, r)));
    }
    for (final p in app.purchases) {
      if (m([p.number, p.supplier, ...p.lines.map((l) => l.description)])) out.add(_Hit(Icons.shopping_cart_rounded, 'Purchase', p.number, '${p.supplier} · ${p.status.label}', (c) => openPurchaseEditor(c, p)));
    }
    return out.take(40).toList();
  }

  void _open(BuildContext context, _Hit h) {
    Navigator.of(context).pop();
    if (widget.origin.mounted) h.open(widget.origin);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final hits = _hits(app);
    if (_sel >= hits.length) _sel = 0;
    return Align(
      alignment: const Alignment(0, -0.6),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 12,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search samples, clients, invoices, methods…'),
                onChanged: (v) => setState(() {
                  _q = v;
                  _sel = 0;
                }),
                onSubmitted: (_) {
                  if (hits.isNotEmpty) _open(context, hits[_sel]);
                },
              ),
            ),
            if (_q.trim().isNotEmpty && hits.isEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), child: Text('No matches.', style: LBText.body(c.inkDim))),
            if (_q.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Text('Tip: press Ctrl + K anywhere to search.', style: LBText.body(c.inkDim, size: 12.5)),
              ),
            if (hits.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: hits.length,
                  itemBuilder: (context, i) {
                    final h = hits[i];
                    return ListTile(
                      dense: true,
                      selected: i == _sel,
                      selectedTileColor: c.accent.withOpacity(0.10),
                      leading: Icon(h.icon, color: c.accent, size: 20),
                      title: Text(h.title, style: LBText.body(c.ink, size: 13.5, weight: FontWeight.w700)),
                      subtitle: Text(h.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: LBText.body(c.inkDim, size: 12)),
                      trailing: Text(h.kind, style: LBText.label(c.inkDim, size: 9.5)),
                      onTap: () => _open(context, h),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
