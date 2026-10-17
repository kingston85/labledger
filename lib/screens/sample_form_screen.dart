import 'package:flutter/material.dart';

import '../core/location_service.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import 'sample_detail_screen.dart';

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
    }
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
      ));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SampleDetailScreen(sample: s)));
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
      });
      Navigator.pop(context);
    }
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
            controller: _code,
            style: LBText.reading(16, c.ink, weight: FontWeight.w700),
            decoration: const InputDecoration(labelText: 'Sample code', helperText: 'Auto-numbered; you can change it'),
          ),
          gap(),
          TextField(controller: _site, decoration: const InputDecoration(labelText: 'Site / location description'), textCapitalization: TextCapitalization.sentences),
          gap(),
          TextField(controller: _project, decoration: const InputDecoration(labelText: 'Project / client'), textCapitalization: TextCapitalization.sentences),
          gap(),
          DropdownButtonFormField<Matrix>(
            value: _matrix,
            decoration: const InputDecoration(labelText: 'Matrix'),
            items: [for (final m in Matrix.values) DropdownMenuItem(value: m, child: Text(m.label))],
            onChanged: (m) => setState(() => _matrix = m ?? _matrix),
          ),
          const SectionHeader('Location'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: LBText.reading(14, c.ink),
                  decoration: const InputDecoration(labelText: 'Latitude', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _lon,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: LBText.reading(14, c.ink),
                  decoration: const InputDecoration(labelText: 'Longitude', isDense: true),
                ),
              ),
            ],
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
