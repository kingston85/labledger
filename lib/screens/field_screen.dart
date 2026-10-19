import 'package:flutter/material.dart';

import '../core/holding.dart';
import '../core/lab_docs.dart';
import '../data/app_state.dart';
import '../data/lab_models.dart';
import '../data/lab_ops.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/inputs.dart';
import '../widgets/panels.dart';
import '../widgets/share.dart';
import 'sample_detail_screen.dart';

enum _FieldTab { trips, guide }

/// Field work: sampling trips (plan, team, sites, checklist, field sheet)
/// and the container / preservation / holding-time guide.
class FieldScreen extends StatefulWidget {
  const FieldScreen({super.key});

  @override
  State<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends State<FieldScreen> {
  _FieldTab _tab = _FieldTab.trips;
  String _q = '';
  bool _solid = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final now = DateTime.now();
    final trips = [...app.trips]..sort((a, b) => b.date.compareTo(a.date));
    final upcoming = trips.where((t) => t.status == TripStatus.planned && !t.date.isBefore(DateTime(now.year, now.month, now.day))).length;
    final inField = trips.where((t) => t.status == TripStatus.inField).length;
    final thisYear = trips.where((t) => t.status == TripStatus.completed && t.date.year == now.year).length;
    final sampled = trips.fold(0, (a, t) => a + t.sitesSampled);

    return Scaffold(
      appBar: AppBar(title: const Text('Field work')),
      floatingActionButton: _tab == _FieldTab.trips && app.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => openTripEditor(context, null),
              icon: const Icon(Icons.add_road_rounded),
              label: const Text('Plan a trip'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          StatRow([
            StatTile(label: 'Upcoming trips', value: '$upcoming', icon: Icons.event_rounded),
            StatTile(label: 'In the field', value: '$inField', icon: Icons.directions_car_rounded, color: c.fair),
            StatTile(label: 'Completed this year', value: '$thisYear', icon: Icons.task_alt_rounded, color: c.good),
            StatTile(label: 'Sites sampled', value: '$sampled', icon: Icons.place_rounded, color: TLColors.violet),
          ]),
          const SizedBox(height: 14),
          Segmented<_FieldTab>(
            values: _FieldTab.values,
            selected: _tab,
            label: (t) => t == _FieldTab.trips ? 'Sampling trips (${trips.length})' : 'Containers & holding times',
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          if (_tab == _FieldTab.trips) ...[
            if (trips.isEmpty)
              const EmptyState(
                icon: Icons.route_rounded,
                title: 'No trips yet',
                body: 'Plan a sampling trip: team, vehicle, sites with coordinates and analyses, and a pre-departure checklist. Print the field sheet and register the samples in one tap.',
              ),
            for (final t in trips) Padding(padding: const EdgeInsets.only(bottom: 8), child: _TripCard(trip: t)),
          ] else ...[
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search analyses (iron, nitrate, E. coli…)', isDense: true),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Water')), ButtonSegment(value: true, label: Text('Soil / sediment'))],
                selected: {_solid},
                onSelectionChanged: (s) => setState(() => _solid = s.first),
              ),
            ]),
            const SizedBox(height: 10),
            _Guide(query: _q, solid: _solid),
          ],
        ],
      ),
    );
  }
}

/// Extra accent colours for charts and tiles.
class TLColors {
  static const violet = Color(0xFF9B7BFF);
  static const teal = Color(0xFF2EC4B6);
  static const pink = Color(0xFFFF6FA8);
}

class _TripCard extends StatelessWidget {
  final FieldTrip trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final t = trip;
    final col = switch (t.status) { TripStatus.planned => c.accent, TripStatus.inField => c.fair, TripStatus.completed => c.good, TripStatus.cancelled => c.inkDim };
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final linked = app.samplesOnTrip(t.id).length;
    return LBCard(
      onTap: () => openTripEditor(context, t),
      child: Row(children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: col.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(months[t.date.month - 1], style: LBText.label(col, size: 10)),
            Text('${t.date.day}', style: LBText.reading(22, col, weight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: LBText.body(c.ink, size: 15, weight: FontWeight.w700)),
            Text([t.project, if (t.team.isNotEmpty) t.team.join(', ')].where((x) => x.isNotEmpty).join(' · '),
                style: LBText.body(c.inkDim, size: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              Tag(t.status.label, color: col),
              Tag('${t.sitesSampled}/${t.sites.length} sites sampled', color: c.inkDim, icon: Icons.place_rounded),
              if (linked > 0) Tag('$linked samples', color: c.accent, icon: Icons.science_rounded),
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: t.checklistProgress, strokeWidth: 5, backgroundColor: c.surface2, color: t.checklistProgress >= 1 ? c.good : c.accent),
            Text('${(t.checklistProgress * 100).round()}%', style: LBText.reading(11, c.ink, weight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

class _Guide extends StatelessWidget {
  final String query;
  final bool solid;
  const _Guide({required this.query, required this.solid});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    final rules = holdingRules.where((r) => r.solid == solid && (query.isEmpty || r.keys.any((k) => k.contains(query)) || r.group.toLowerCase().contains(query))).toList();
    final groups = <String>[];
    for (final r in rules) {
      if (!groups.contains(r.group)) groups.add(r.group);
    }
    if (rules.isEmpty) return const EmptyState(icon: Icons.search_off_rounded, title: 'Nothing found', body: 'Try another analysis name.');
    String name(HoldingRule r) {
      if (r.group == 'Metals' && r.keys.length > 5) return 'Metals (Fe, Mn, Pb, Cd, Cu, Zn, As, Ni, Cr, Al…)';
      if (r.group == 'Soil & sediment' && r.keys.length > 5) return 'Metals in soil / sediment';
      final k = r.keys.first.trim();
      return k.length <= 3 ? k.toUpperCase() : k[0].toUpperCase() + k.substring(1);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final g in groups) ...[
        Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 6), child: PanelLabel(g)),
        LBCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, r) in rules.where((r) => r.group == g).indexed) ...[
              if (i > 0) Divider(height: 1, color: c.line),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: Text(name(r), style: LBText.body(c.ink, size: 13.5, weight: FontWeight.w700))),
                  Expanded(
                    flex: 5,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r.container} · ${r.volume}', style: LBText.body(c.ink, size: 12.5)),
                      Text(r.preservation, style: LBText.body(c.inkDim, size: 12)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Tag(r.holdText.split(' (').first, color: r.hold.inHours <= 48 ? c.fair : c.good, icon: Icons.timer_outlined),
                ]),
              ),
            ],
          ]),
        ),
      ],
      const SizedBox(height: 10),
      Text('Sources: US EPA 40 CFR 136 Table II; Standard Methods 1060; US EPA SW-846. Holding time counts from collection to start of analysis.',
          style: LBText.body(c.inkDim, size: 11.5)),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Trip editor
// ---------------------------------------------------------------------------

Future<void> openTripEditor(BuildContext context, FieldTrip? trip) => openForm(context, TripEditorScreen(trip: trip), width: 760);

class TripEditorScreen extends StatefulWidget {
  final FieldTrip? trip;
  const TripEditorScreen({super.key, this.trip});

  @override
  State<TripEditorScreen> createState() => _TripEditorScreenState();
}

class _TripEditorScreenState extends State<TripEditorScreen> {
  late FieldTrip t;
  final _title = TextEditingController();
  final _project = TextEditingController();
  final _vehicle = TextEditingController();
  final _team = TextEditingController();
  final _objective = TextEditingController();
  final _notes = TextEditingController();
  bool _init = false;

  bool get _isNew => widget.trip == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    t = widget.trip == null ? FieldTrip(id: newId(), title: '', date: DateTime.now().add(const Duration(days: 3))) : FieldTrip.fromJson(widget.trip!.toJson());
    _title.text = t.title;
    _project.text = t.project;
    _vehicle.text = t.vehicle;
    _team.text = t.team.join(', ');
    _objective.text = t.objective;
    _notes.text = t.notes;
  }

  void _collect() {
    t
      ..title = _title.text.trim()
      ..project = _project.text.trim()
      ..vehicle = _vehicle.text.trim()
      ..objective = _objective.text.trim()
      ..notes = _notes.text.trim()
      ..team = _team.text.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
  }

  /// Writes the working copy back into the app and returns the stored trip.
  FieldTrip _commit() {
    final app = AppScope.read(context);
    _collect();
    if (t.title.isEmpty) t.title = t.project.isEmpty ? 'Sampling trip ${shortDate(t.date)}' : t.project;
    late FieldTrip stored;
    app.update(() {
      final i = app.trips.indexWhere((x) => x.id == t.id);
      if (i >= 0) {
        app.trips[i] = t;
        app.log('update', 'Field trip', t.title, '${t.sites.length} sites · ${t.status.label}');
      } else {
        app.trips.add(t);
        app.log('create', 'Field trip', t.title, shortDate(t.date));
      }
      stored = t;
    });
    t = FieldTrip.fromJson(stored.toJson());
    return stored;
  }

  void _save() {
    _commit();
    Navigator.pop(context);
  }

  Future<void> _editSite(PlannedSite? s) async {
    final app = AppScope.read(context);
    final name = TextEditingController(text: s?.name ?? '');
    final code = TextEditingController(text: s?.code ?? '');
    final lat = TextEditingController(text: s?.lat?.toString() ?? '');
    final lon = TextEditingController(text: s?.lon?.toString() ?? '');
    final params = TextEditingController(text: s?.parameters ?? 'Field params, metals');
    var matrix = Matrix.values.firstWhere((m) => m.name == (s?.matrix ?? 'surfaceWater'), orElse: () => Matrix.surfaceWater);
    final res = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setS) {
        return AlertDialog(
          title: Text(s == null ? 'Add sampling site' : 'Edit site'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Site name', hintText: 'Upstream bridge')),
                const SizedBox(height: 10),
                FieldRow([
                  DropdownButtonFormField<Matrix>(
                    value: matrix,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Matrix', isDense: true),
                    items: [for (final m in Matrix.values) DropdownMenuItem(value: m, child: Text(m.label))],
                    onChanged: (m) => setS(() => matrix = m ?? matrix),
                  ),
                  TextField(controller: code, decoration: const InputDecoration(labelText: 'Sample code', hintText: 'MR-SW-001', isDense: true)),
                ]),
                FieldRow([
                  TextField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude', isDense: true)),
                  TextField(controller: lon, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude', isDense: true)),
                ]),
                TextField(controller: params, decoration: const InputDecoration(labelText: 'Analyses', hintText: 'Field params, metals, nutrients, E. coli', isDense: true)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final p = await app.location.current();
                      if (p != null) {
                        setS(() {
                          lat.text = p.latitude.toStringAsFixed(6);
                          lon.text = p.longitude.toStringAsFixed(6);
                        });
                      }
                    },
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Use my GPS position'),
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            if (s != null) TextButton(onPressed: () => Navigator.pop(context, 'delete'), child: Text('Remove', style: TextStyle(color: context.lb.poor))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('Save')),
          ],
        );
      }),
    );
    if (!mounted) return;
    if (res == 'delete' && s != null) setState(() => t.sites.remove(s));
    if (res == 'save' && name.text.trim().isNotEmpty) {
      setState(() {
        final x = s ?? PlannedSite(name: '');
        x
          ..name = name.text.trim()
          ..code = code.text.trim().isNotEmpty ? code.text.trim().toUpperCase() : buildSampleCode(_prefix(), matrix, t.sites.length + 1)
          ..lat = double.tryParse(lat.text.trim())
          ..lon = double.tryParse(lon.text.trim())
          ..matrix = matrix.name
          ..parameters = params.text.trim();
        if (s == null) t.sites.add(x);
      });
    }
  }

  String _prefix() {
    final words = (_project.text.trim().isEmpty ? _title.text : _project.text).trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w[0].toUpperCase() != w[0].toLowerCase()).toList();
    if (words.isEmpty) return 'FS';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  /// Creates a sample for every site not yet sampled, linked to this trip.
  Future<void> _registerSamples() async {
    final app = AppScope.read(context);
    final pending = t.sites.where((s) => !s.sampled).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Every site is already marked as sampled.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Register ${pending.length} sample${pending.length == 1 ? '' : 's'}?'),
        content: Text('A sample record is created for each unsampled site with its code, coordinates and matrix, collected now by ${t.team.isEmpty ? app.userName : t.team.first}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Register')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _collect();
    for (final site in pending) {
      final m = Matrix.values.firstWhere((x) => x.name == site.matrix, orElse: () => Matrix.surfaceWater);
      app.addSample(Sample(
        id: newId(),
        code: site.code.isEmpty ? app.nextCode() : site.code,
        site: site.name,
        project: t.project,
        matrix: m,
        lat: site.lat,
        lon: site.lon,
        collector: t.team.isEmpty ? app.userName : t.team.first,
        isControl: codeLooksControl(site.code),
        clientId: t.clientId,
        requestId: t.requestId,
        tripId: t.id,
        notes: site.parameters.isEmpty ? '' : 'Analyses: ${site.parameters}',
      ));
      site.sampled = true;
    }
    if (t.status == TripStatus.planned) t.status = TripStatus.inField;
    _commit();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${pending.length} samples registered on ${t.title}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final linked = app.samplesOnTrip(t.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Plan a sampling trip' : t.title),
        actions: [
          IconButton(
            tooltip: 'Field sheet (PDF)',
            icon: const Icon(Icons.print_rounded),
            onPressed: () async {
              _collect();
              final bytes = await LabDocs.fieldSheet(app, t);
              if (context.mounted) await shareBytes(context, '${safeName(t.title.isEmpty ? 'field_sheet' : t.title)}_field_sheet.pdf', bytes, 'application/pdf');
            },
          ),
        ],
      ),
      bottomNavigationBar: FormActions(
        onSave: app.canEdit ? _save : null,
        saveLabel: _isNew ? 'Create trip' : 'Save',
        onDelete: _isNew || !app.isAdmin
            ? null
            : () {
                app.update(() {
                  app.trips.removeWhere((x) => x.id == t.id);
                  for (final s in app.samples.where((s) => s.tripId == t.id)) {
                    s.tripId = null;
                  }
                  app.log('delete', 'Field trip', t.title, '');
                });
                Navigator.pop(context);
              },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FormSection('Trip', icon: Icons.route_rounded, children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Trip name', hintText: 'Mano River quarterly monitoring')),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in TripStatus.values)
                ChoiceChip(label: Text(s.label), selected: t.status == s, onSelected: (_) => setState(() => t.status = s)),
            ]),
            const SizedBox(height: 12),
            FieldRow([
              DateField(label: 'Departure', value: t.date, clearable: false, onChanged: (d) => setState(() => t.date = d ?? t.date)),
              DateField(label: 'Return', value: t.returnDate, onChanged: (d) => setState(() => t.returnDate = d)),
            ]),
            FieldRow([
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _project.text),
                optionsBuilder: (v) => app.projects.map((p) => p.$1).where((p) => p != 'Unassigned' && p.toLowerCase().contains(v.text.toLowerCase())).take(8),
                onSelected: (p) => _project.text = p,
                fieldViewBuilder: (context, ctrl, focus, _) => TextField(
                  controller: ctrl,
                  focusNode: focus,
                  onChanged: (v) => _project.text = v,
                  decoration: const InputDecoration(labelText: 'Project', isDense: true),
                ),
              ),
              TextField(controller: _vehicle, decoration: const InputDecoration(labelText: 'Vehicle / driver', isDense: true)),
            ]),
            TextField(controller: _team, decoration: const InputDecoration(labelText: 'Team (comma separated)', hintText: 'S. Emmanuel, J. Cooper', isDense: true)),
            const SizedBox(height: 10),
            FieldRow([
              DropdownButtonFormField<String?>(
                value: app.client(t.clientId) == null ? null : t.clientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Client', isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
                  for (final cl in app.clients) DropdownMenuItem<String?>(value: cl.id, child: Text(cl.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => t.clientId = v),
              ),
              DropdownButtonFormField<String?>(
                value: app.request(t.requestId) == null ? null : t.requestId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Analysis request', isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
                  for (final r in app.requests.where((r) => t.clientId == null || r.clientId == t.clientId)) DropdownMenuItem<String?>(value: r.id, child: Text(r.number)),
                ],
                onChanged: (v) => setState(() {
                  t.requestId = v;
                  final r = app.request(v);
                  if (r != null) {
                    t.clientId = r.clientId;
                    if (_project.text.trim().isEmpty) _project.text = r.project;
                  }
                }),
              ),
            ]),
            TextField(controller: _objective, maxLines: 2, decoration: const InputDecoration(labelText: 'Objective', isDense: true)),
            const SizedBox(height: 8),
          ]),
          FormSection(
            'Sampling sites (${t.sitesSampled}/${t.sites.length} sampled)',
            icon: Icons.place_rounded,
            trailing: TextButton.icon(onPressed: () => _editSite(null), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add site')),
            children: [
              if (t.sites.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Add the stations you will sample. Codes follow the EPA pattern (site-matrix-number) automatically.', style: LBText.body(c.inkDim, size: 12.5)),
                ),
              for (final s in t.sites)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    dense: true,
                    onTap: () => _editSite(s),
                    leading: Checkbox(value: s.sampled, onChanged: (v) => setState(() => s.sampled = v ?? false)),
                    title: Text('${s.code.isEmpty ? '' : '${s.code} · '}${s.name}', style: LBText.body(c.ink, size: 13.5, weight: FontWeight.w700)),
                    subtitle: Text(
                      [s.parameters, if (s.lat != null && s.lon != null) '${s.lat!.toStringAsFixed(4)}, ${s.lon!.toStringAsFixed(4)}'].where((x) => x.isNotEmpty).join(' · '),
                      style: LBText.body(c.inkDim, size: 12),
                    ),
                    trailing: Icon(Icons.edit_outlined, size: 18, color: c.inkDim),
                  ),
                ),
              if (t.sites.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: OutlinedButton.icon(
                    onPressed: app.canEdit ? _registerSamples : null,
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text('Register samples for unsampled sites'),
                  ),
                ),
            ],
          ),
          FormSection(
            'Pre-departure checklist',
            icon: Icons.checklist_rounded,
            trailing: Text('${(t.checklistProgress * 100).round()}%', style: LBText.reading(13, t.checklistProgress >= 1 ? c.good : c.accent, weight: FontWeight.w700)),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: t.checklistProgress, minHeight: 6, backgroundColor: c.surface2, color: t.checklistProgress >= 1 ? c.good : c.accent),
              ),
              const SizedBox(height: 6),
              for (final item in t.checklist)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: item.done,
                  onChanged: (v) => setState(() => item.done = v ?? false),
                  title: Text(item.text, style: LBText.body(item.done ? c.inkDim : c.ink, size: 13).copyWith(decoration: item.done ? TextDecoration.lineThrough : null)),
                  secondary: IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, size: 16, color: c.inkDim),
                    onPressed: () => setState(() => t.checklist.remove(item)),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final ctrl = TextEditingController();
                    final v = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Checklist item'),
                        content: TextField(controller: ctrl, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v)),
                        actions: [FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Add'))],
                      ),
                    );
                    if (v != null && v.trim().isNotEmpty) setState(() => t.checklist.add(CheckItem(v.trim())));
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add item'),
                ),
              ),
            ],
          ),
          if (linked.isNotEmpty)
            FormSection('Samples from this trip (${linked.length})', icon: Icons.science_rounded, children: [
              for (final s in linked)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.science_outlined, color: c.accent, size: 20),
                  title: Text(s.code, style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
                  subtitle: Text('${s.site} · ${s.status.label} · ${s.results.length} results', style: LBText.body(c.inkDim, size: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, SampleDetailScreen(sample: s)),
                ),
            ]),
          FormSection('Notes', icon: Icons.notes_rounded, children: [
            TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(hintText: 'Access, community contacts, hazards…', isDense: true)),
            const SizedBox(height: 8),
          ]),
        ],
      ),
    );
  }
}
