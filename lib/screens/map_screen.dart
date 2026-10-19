import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/gis.dart';
import '../core/guidelines.dart';
import '../core/report.dart';
import '../core/utm.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/share.dart';
import 'sample_detail_screen.dart';
import '../widgets/panels.dart';

const _ua = 'lr.labledger.labledger';

enum _Base { street, satellite }

/// Sampling points on a map, coloured by compliance or by one parameter.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  String? _project; // null = all
  String? _param; // null = overall compliance
  _Base _base = _Base.street;
  List<Sample> _selected = [];

  List<Sample> _visible(AppState app) => app.samples.where((s) => s.lat != null && s.lon != null && (_project == null || s.project == _project)).toList();

  Color _colorFor(AppState app, Sample s, LBColors c) {
    if (_param != null) {
      final r = s.results.where((r) => paramKey(r.parameter) == paramKey(_param!)).firstOrNull;
      if (r == null) return c.inkDim;
      if (r.belowLod) return c.good;
      final set = app.limitsFor(s);
      final chk = checkResult(r, set);
      if (chk.status == Compliance.exceed || chk.status == Compliance.belowMin) return c.poor;
      final f = chk.factor;
      if (f != null && f >= 0.8) return c.fair;
      return s.isControl ? const Color(0xFF4DA3FF) : c.good;
    }
    return switch (sampleClass(app, s)) {
      'control' => const Color(0xFF4DA3FF),
      'exceeds' => c.poor,
      'complies' => c.good,
      _ => c.inkDim,
    };
  }

  void _fit(List<Sample> pts) {
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      _map.move(LatLng(pts.first.lat!, pts.first.lon!), 15);
      return;
    }
    _map.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints([for (final s in pts) LatLng(s.lat!, s.lon!)]), padding: const EdgeInsets.all(60)));
  }

  /// Samples within ~40 m of [s] (repeat visits to the same site).
  List<Sample> _nearby(List<Sample> all, Sample s) {
    const d = Distance();
    return all.where((o) => d.as(LengthUnit.Meter, LatLng(s.lat!, s.lon!), LatLng(o.lat!, o.lon!)) <= 40).toList()
      ..sort((a, b) => b.collectedAt.compareTo(a.collectedAt));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = context.lb;
    final pts = _visible(app);
    final projects = app.samples.where((s) => s.lat != null).map((s) => s.project).where((p) => p.isNotEmpty).toSet().toList()..sort();
    final params = pts.expand((s) => s.results).map((r) => canonicalParameter(r.parameter)).toSet().toList()..sort();
    if (_param != null && !params.contains(_param)) _param = null;
    final center = pts.isEmpty
        ? const LatLng(6.3156, -10.8074)
        : LatLng(pts.map((s) => s.lat!).reduce((a, b) => a + b) / pts.length, pts.map((s) => s.lon!).reduce((a, b) => a + b) / pts.length);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final controls = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(
        width: wide ? 280 : double.infinity,
        child: DropdownButtonFormField<String?>(
          value: _project,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Project', isDense: true),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('All projects')),
            for (final p in projects) DropdownMenuItem<String?>(value: p, child: Text(p, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            setState(() {
              _project = v;
              _selected = [];
            });
            WidgetsBinding.instance.addPostFrameCallback((_) => _fit(_visible(app)));
          },
        ),
      ),
      SizedBox(
        width: wide ? 240 : double.infinity,
        child: DropdownButtonFormField<String?>(
          value: _param,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Colour by', isDense: true),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Overall compliance')),
            for (final p in params) DropdownMenuItem<String?>(value: p, child: Text(p, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _param = v),
        ),
      ),
    ]);

    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: pts.isEmpty ? 11 : 13,
        initialCameraFit: pts.length >= 2
            ? CameraFit.bounds(bounds: LatLngBounds.fromPoints([for (final s in pts) LatLng(s.lat!, s.lon!)]), padding: const EdgeInsets.all(60))
            : null,
        onTap: (_, __) => setState(() => _selected = []),
      ),
      children: [
        TileLayer(
          urlTemplate: _base == _Base.street
              ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
              : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: _ua,
          maxNativeZoom: 19,
          maxZoom: 21,
        ),
        MarkerLayer(markers: [
          for (final s in pts)
            Marker(
              point: LatLng(s.lat!, s.lon!),
              width: 120,
              height: 48,
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () => setState(() => _selected = _nearby(pts, s)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: _selected.contains(s) ? 22 : 16,
                    height: _selected.contains(s) ? 22 : 16,
                    decoration: BoxDecoration(
                      color: _colorFor(app, s, c),
                      shape: s.isControl ? BoxShape.rectangle : BoxShape.circle,
                      borderRadius: s.isControl ? BorderRadius.circular(4) : null,
                      border: Border.all(color: Colors.white, width: 2.4),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                    child: Text(s.code, style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
        ]),
        RichAttributionWidget(attributions: [
          TextSourceAttribution(_base == _Base.street ? 'OpenStreetMap contributors' : 'Esri, Maxar, Earthstar Geographics'),
        ]),
      ],
    );

    final legend = Glass(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        for (final e in _param == null
            ? [(c.good, 'Complies'), (c.poor, 'Exceedance'), (const Color(0xFF4DA3FF), 'Control (square)'), (c.inkDim, 'No results')]
            : [(c.good, '< 80% of limit'), (c.fair, '80–100% of limit'), (c.poor, 'Exceeds'), (c.inkDim, 'Not measured')])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: e.$1, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(e.$2, style: LBText.body(c.ink, size: 11)),
            ]),
          ),
      ]),
    );

    Widget panel() {
      if (_selected.isEmpty) return const SizedBox();
      final s0 = _selected.first;
      final u = toUtm(s0.lat!, s0.lon!, zone: 29);
      return Glass(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text(s0.site.isEmpty ? s0.code : s0.site, style: LBText.body(c.ink, weight: FontWeight.w700), maxLines: 2)),
                IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _selected = []), icon: const Icon(Icons.close_rounded, size: 18)),
              ]),
              Text('${s0.lat!.toStringAsFixed(5)}, ${s0.lon!.toStringAsFixed(5)} · UTM 29N ${u.easting.round()} E ${u.northing.round()} N', style: LBText.reading(11, c.inkDim)),
              if (_selected.length > 1) Text('${_selected.length} samples at this site', style: LBText.body(c.accent, size: 12, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final s in _selected)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: _colorFor(app, s, c), shape: BoxShape.circle)),
                  title: Text(s.code, style: LBText.reading(13, c.ink, weight: FontWeight.w700)),
                  subtitle: Text(
                    _param == null
                        ? '${shortDate(s.collectedAt)} · ${s.results.length} results · ${s.status.label}'
                        : () {
                            final r = s.results.where((r) => paramKey(r.parameter) == paramKey(_param!)).firstOrNull;
                            return '${shortDate(s.collectedAt)} · $_param ${r == null ? 'not measured' : '${resultText(r)} ${r.unit}'}';
                          }(),
                    style: LBText.body(c.inkDim, size: 11.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openPage(context, SampleDetailScreen(sample: s)),
                ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & GIS'),
        actions: [
          IconButton(
            tooltip: _base == _Base.street ? 'Satellite' : 'Street map',
            onPressed: () => setState(() => _base = _base == _Base.street ? _Base.satellite : _Base.street),
            icon: Icon(_base == _Base.street ? Icons.satellite_alt_outlined : Icons.map_outlined),
          ),
          IconButton(tooltip: 'Zoom to samples', onPressed: () => _fit(pts), icon: const Icon(Icons.center_focus_strong_rounded)),
          PopupMenuButton<String>(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onSelected: (v) {
              final name = safeName(_project ?? 'LabLedger_samples');
              if (v == 'kml') {
                shareText(context, '$name.kml', kml(app, pts, name: _project ?? 'LabLedger samples'), 'application/vnd.google-earth.kml+xml');
              } else {
                shareText(context, '$name.geojson', geoJson(app, pts), 'application/geo+json');
              }
              app.log('export', 'Map', _project ?? 'All projects', '${pts.length} points as ${v.toUpperCase()}');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'kml', child: ListTile(dense: true, leading: Icon(Icons.public_rounded), title: Text('KML · Google Earth'))),
              PopupMenuItem(value: 'geojson', child: ListTile(dense: true, leading: Icon(Icons.layers_rounded), title: Text('GeoJSON · QGIS / ArcGIS'))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 10), child: controls),
        Expanded(
          child: pts.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.location_off_outlined,
                    title: 'No coordinates yet',
                    body: 'Samples with latitude/longitude or UTM coordinates appear here. ${app.samples.where((s) => s.lat == null).length} samples have no location.',
                  ),
                )
              : Stack(children: [
                  Positioned.fill(child: map),
                  Positioned(left: 12, top: 12, child: legend),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text('${pts.length} points · ${pts.where((s) => sampleClass(app, s) == 'exceeds').length} with exceedances',
                          style: LBText.body(c.ink, size: 11.5, weight: FontWeight.w600)),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: wide ? null : 12,
                      bottom: 16,
                      child: SizedBox(width: wide ? 380 : null, child: panel()),
                    ),
                ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Text('Map tiles need an internet connection; points and exports work offline. '
              'Export KML for Google Earth or GeoJSON for QGIS.', style: LBText.body(c.inkDim, size: 11)),
        ),
      ]),
    );
  }
}

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180, dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.sqrt(a));
}
