import 'package:flutter/material.dart';

import '../core/location_service.dart';
import '../core/utm.dart';
import '../data/app_state.dart';
import '../data/lab_ops.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/panels.dart';
import 'sample_detail_screen.dart';

/// Opens the new-sample form (side panel on a PC) and then the new sample.
Future<void> openNewSample(BuildContext context) async {
  final s = await openForm<Sample>(context, const SampleFormScreen(), width: 720);
  if (s != null && context.mounted) openPage(context, SampleDetailScreen(sample: s));
}

class SampleFormScreen extends StatefulWidget {
  final Sample? sample; // null = new
  const SampleFormScreen({super.key, this.sample});

  @override
  State<SampleFormScreen> createState() => _SampleFormScreenState();
}

class _SampleFormScreenState extends State<SampleFormScreen> {
  final _code = TextEditingController();
  final _site = TextEditingController();
  final _project = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _collector = TextEditingController();
  final _pres = TextEditingController();
  final _notes = TextEditingController();
  final _sitePrefix = TextEditingController();
  final _east = TextEditingController();
  final _north = TextEditingController();
  bool _utm = false;
  bool _control = false;
  String? _clientId;
  String? _requestId;
  String? _tripId;
  final _weather = TextEditingController();
  final _fieldNotes = TextEditingController();
  DateTime? _due;
  Matrix _matrix = Matrix.surfaceWater;
  SampleStatus _status = SampleStatus.collected;
  DateTime _collected = DateTime.now();
  DateTime? _received;
  String? _limitSet;
  bool _locating = false;
  bool _init = false;

  static const _presPresets = ['None', '4 °C', 'HNO3 to pH < 2, 4 °C', 'H2SO4 to pH < 2, 4 °C', 'NaOH to pH > 12 (cyanide)', 'Sterile bottle, 4 °C'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.read(context);
    final s = widget.sample;
    if (s == null) {
      _code.text = app.nextCode();
      _collector.text = app.settings.analyst;
      _limitSet = app.settings.defaultLimitSetId;
    } else {
      _code.text = s.code;
      _site.text = s.site;
      _project.text = s.project;
      _lat.text = s.lat?.toStringAsFixed(6) ?? '';
      _lon.text = s.lon?.toStringAsFixed(6) ?? '';
      _collector.text = s.collector;
      _pres.text = s.preservation;
      _notes.text = s.notes;
      _matrix = s.matrix;
      _status = s.status;
      _collected = s.collectedAt;
      _received = s.receivedAt;
      _limitSet = s.limitSetId ?? app.settings.defaultLimitSetId;
      _control = s.isControl;
      _clientId = s.clientId;
      _requestId = s.requestId;
      _due = s.dueDate;
      _tripId = s.tripId;
      _weather.text = s.weather;
      _fieldNotes.text = s.fieldNotes;
      final m = RegExp(r'^([A-Za-z0-9]+(?:-[A-Za-z])?)-').firstMatch(s.code);
      if (m != null) _sitePrefix.text = m.group(1)!.replaceAll(RegExp(r'-C$'), '');
    }
    _syncUtmFromLatLon();
  }

  void _syncUtmFromLatLon() {
    final lat = double.tryParse(_lat.text.trim()), lon = double.tryParse(_lon.text.trim());
    if (lat == null || lon == null) return;
    final u = toUtm(lat, lon, zone: 29);
    _east.text = u.easting.toStringAsFixed(0);
    _north.text = u.northing.toStringAsFixed(0);
  }

  void _syncLatLonFromUtm() {
    final e = double.tryParse(_east.text.trim()), n = double.tryParse(_north.text.trim());
    if (e == null || n == null) return;
    final p = parseCoordinatePair(e, n);
    if (p == null) return;
    _lat.text = p.$1.toStringAsFixed(6);
    _lon.text = p.$2.toStringAsFixed(6);
  }

  void _generateCode() {
    final app = AppScope.read(context);
    final seq = app.nextProjectSeq(_project.text);
    setState(() => _code.text = buildSampleCode(_sitePrefix.text, _matrix, seq, control: _control));
  }

  Future<void> _gps() async {
    final loc = AppScope.read(context).location;
    setState(() => _locating = true);
    if (loc.status != GpsStatus.live) await loc.start();
    for (var i = 0; i < 40 && !loc.hasFix; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    setState(() => _locating = false);
    final p = loc.latLng;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.statusText)));
      return;
    }
    setState(() {
      _lat.text = p.latitude.toStringAsFixed(6);
      _lon.text = p.longitude.toStringAsFixed(6);
      _syncUtmFromLatLon();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Position captured (±${(loc.accuracy ?? 0).toStringAsFixed(0)} m)')),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final d = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    return DateTime(d.year, d.month, d.day, t?.hour ?? initial.hour, t?.minute ?? initial.minute);
  }

  void _save() {
    final app = AppScope.read(context);
    if (_code.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a sample code.')));
      return;
    }
    if (_utm) _syncLatLonFromUtm();
    final lat = double.tryParse(_lat.text.trim()), lon = double.tryParse(_lon.text.trim());
    if (widget.sample == null) {
      final s = app.addSample(Sample(
        id: newId(),
        code: _code.text.trim(),
        site: _site.text.trim(),
        project: _project.text.trim(),
        matrix: _matrix,
        lat: lat,
        lon: lon,
        collectedAt: _collected,
        receivedAt: _received,
        collector: _collector.text.trim(),
        preservation: _pres.text.trim(),
        notes: _notes.text.trim(),
        status: _status,
        limitSetId: _limitSet,
        isControl: _control,
        clientId: _clientId,
        requestId: _requestId,
        dueDate: _due,
        tripId: _tripId,
        weather: _weather.text.trim(),
        fieldNotes: _fieldNotes.text.trim(),
      ));
      Navigator.of(context).pop(s);
    } else {
      final s = widget.sample!;
      app.update(() {
        s.code = _code.text.trim();
        s.site = _site.text.trim();
        s.project = _project.text.trim();
        s.matrix = _matrix;
        s.lat = lat;
        s.lon = lon;
        s.collectedAt = _collected;
        s.receivedAt = _received;
        s.collector = _collector.text.trim();
        s.preservation = _pres.text.trim();
        s.notes = _notes.text.trim();
        s.status = _status;
        s.limitSetId = _limitSet;
        s.isControl = _control;
        s.clientId = _clientId;
        s.requestId = _requestId;
        s.dueDate = _due;
        s.tripId = _tripId;
        s.weather = _weather.text.trim();
        s.fieldNotes = _fieldNotes.text.trim();
        app.log('update', 'Sample', s.code, 'details edited');
      });
      Navigator.pop(context);
    }
  }

  String _coordHint() {
    if (_utm) {
      final e = double.tryParse(_east.text.trim()), n = double.tryParse(_north.text.trim());
      if (e == null || n == null) return 'WGS84 / UTM zone 29N (EPSG:32629)';
      final p = parseCoordinatePair(e, n);
      if (p == null) return 'Not a valid zone 29N coordinate';
      final swapped = e.abs() <= 180 && n.abs() <= 180;
      return '${swapped ? 'Looks like decimal degrees, read as lat/lon → ' : '= '}${p.$1.toStringAsFixed(6)}, ${p.$2.toStringAsFixed(6)}';
    }
    final lat = double.tryParse(_lat.text.trim()), lon = double.tryParse(_lon.text.trim());
    if (lat == null || lon == null) return 'Decimal degrees, WGS84';
    return '= UTM ${toUtm(lat, lon, zone: 29)}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    Widget gap() => const SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sample == null ? 'New sample' : 'Edit sample'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
        children: [
          TextField(
            controller: _project,
            decoration: const InputDecoration(labelText: 'Project / investigation', hintText: 'e.g. Bolo Town water investigation'),
            textCapitalization: TextCapitalization.sentences,
          ),
          gap(),
          DropdownButtonFormField<Matrix>(
            value: _matrix,
            decoration: const InputDecoration(labelText: 'Matrix'),
            items: [for (final m in Matrix.values) DropdownMenuItem(value: m, child: Text('${m.label}  ·  ${m.code}'))],
            onChanged: (m) => setState(() => _matrix = m ?? _matrix),
          ),
          gap(),
          LBCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PanelLabel('Sample code'),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  style: LBText.reading(17, c.ink, weight: FontWeight.w700),
                  decoration: const InputDecoration(isDense: true, hintText: 'KR-SW-001'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sitePrefix,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Site prefix', hintText: 'KR, YC, BT…', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: _generateCode,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Build code'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Format SITE-[C-]MATRIX-SEQ, numbered within the project (e.g. KR-C-SW-004).',
                    style: LBText.body(c.inkDim, size: 11.5)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _control,
                  onChanged: (v) => setState(() => _control = v),
                  title: const Text('Control / background sample'),
                  subtitle: const Text('Upstream or off-site point used as the clean baseline'),
                ),
              ],
            ),
          ),
          gap(),
          TextField(controller: _site, decoration: const InputDecoration(labelText: 'Location & description'), textCapitalization: TextCapitalization.sentences, maxLines: 2, minLines: 1),
          SectionHeader(
            'Location',
            trailing: SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('Lat/Lon')), ButtonSegment(value: true, label: Text('UTM 29N'))],
              selected: {_utm},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (v) => setState(() {
                if (_utm) {
                  _syncLatLonFromUtm();
                } else {
                  _syncUtmFromLatLon();
                }
                _utm = v.first;
              }),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _utm ? _east : _lat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: LBText.reading(14, c.ink),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: _utm ? 'Easting X (m)' : 'Latitude', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _utm ? _north : _lon,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: LBText.reading(14, c.ink),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: _utm ? 'Northing Y (m)' : 'Longitude', isDense: true),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_coordHint(), style: LBText.reading(11.5, c.inkDim)),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _locating ? null : _gps,
              icon: _locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(_locating ? 'Finding GPS…' : 'Use my GPS position'),
            ),
          ),
          const SectionHeader('Collection'),
          _DateRow(
            label: 'Collected',
            value: dateTime(_collected),
            onTap: () async {
              final d = await _pickDateTime(_collected);
              if (d != null) setState(() => _collected = d);
            },
          ),
          gap(),
          _DateRow(
            label: 'Received at lab',
            value: _received == null ? 'Not yet — tap to set' : dateTime(_received!),
            onTap: () async {
              final d = await _pickDateTime(_received ?? DateTime.now());
              if (d != null) {
                setState(() {
                  _received = d;
                  if (_status == SampleStatus.collected) _status = SampleStatus.received;
                });
              }
            },
          ),
          gap(),
          TextField(controller: _collector, decoration: const InputDecoration(labelText: 'Collected by'), textCapitalization: TextCapitalization.words),
          gap(),
          TextField(controller: _pres, decoration: const InputDecoration(labelText: 'Preservation / container')),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _presPresets)
                ActionChip(label: Text(p), onPressed: () => setState(() => _pres.text = p), visualDensity: VisualDensity.compact),
            ],
          ),
          const SectionHeader('Field information'),
          DropdownButtonFormField<String?>(
            value: app.trip(_tripId) == null ? null : _tripId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Field trip'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
              for (final t in [...app.trips]..sort((a, b) => b.date.compareTo(a.date)))
                DropdownMenuItem<String?>(value: t.id, child: Text('${t.title} · ${shortDate(t.date)}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _tripId = v;
              final t = app.trip(v);
              if (t != null) {
                if (_project.text.trim().isEmpty) _project.text = t.project;
                _clientId ??= t.clientId;
                _requestId ??= t.requestId;
                if (_collector.text.trim().isEmpty && t.team.isNotEmpty) _collector.text = t.team.first;
              }
            }),
          ),
          gap(),
          TextField(controller: _weather, decoration: const InputDecoration(labelText: 'Weather')),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final w in const ['Sunny, dry', 'Overcast', 'Light rain', 'Heavy rain', 'After heavy rain'])
              ActionChip(label: Text(w), onPressed: () => setState(() => _weather.text = w), visualDensity: VisualDensity.compact),
          ]),
          gap(),
          TextField(
            controller: _fieldNotes,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Field observations', hintText: 'Colour, odour, flow, nearby activities, sample condition'),
          ),
          const SectionHeader('Client & request'),
          DropdownButtonFormField<String?>(
            value: app.client(_clientId) == null ? null : _clientId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Client'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
              for (final cl in [...app.clients]..sort((a, b) => a.name.compareTo(b.name))) DropdownMenuItem<String?>(value: cl.id, child: Text(cl.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _clientId = v;
              if (_requestId != null && app.request(_requestId)?.clientId != v) _requestId = null;
            }),
          ),
          gap(),
          DropdownButtonFormField<String?>(
            value: app.request(_requestId) == null ? null : _requestId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Analysis request'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
              for (final r in app.requests.where((r) => _clientId == null || r.clientId == _clientId))
                DropdownMenuItem<String?>(value: r.id, child: Text('${r.number}${r.project.isEmpty ? '' : ' · ${r.project}'}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() {
              _requestId = v;
              final r = app.request(v);
              if (r != null) {
                _clientId = r.clientId;
                _due ??= r.dueDate;
                if (_project.text.trim().isEmpty) _project.text = r.project;
              }
            }),
          ),
          gap(),
          _DateRow(
            label: 'Results due',
            value: _due == null ? 'No due date — tap to set' : dateTime(_due!),
            onTap: () async {
              final d = await _pickDateTime(_due ?? DateTime.now().add(const Duration(days: 10)));
              if (d != null) setState(() => _due = d);
            },
          ),
          const SectionHeader('Assessment'),
          DropdownButtonFormField<String>(
            value: app.limitSets.any((s) => s.id == _limitSet) ? _limitSet : null,
            decoration: const InputDecoration(labelText: 'Compare results against'),
            items: [for (final s in app.limitSets) DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _limitSet = v),
          ),
          gap(),
          DropdownButtonFormField<SampleStatus>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [for (final s in SampleStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
            onChanged: (s) => setState(() => _status = s ?? _status),
          ),
          gap(),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Remarks'), textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('Save sample')),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.lb;
    return LBCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.event_rounded, color: c.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanelLabel(label),
                const SizedBox(height: 2),
                Text(value, style: LBText.reading(14, c.ink)),
              ],
            ),
          ),
          Icon(Icons.edit_calendar_rounded, color: c.inkDim, size: 18),
        ],
      ),
    );
  }
}
