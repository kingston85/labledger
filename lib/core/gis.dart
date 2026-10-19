// GIS exports: GeoJSON (QGIS, ArcGIS, web maps) and KML (Google Earth).

import 'dart:convert';

import '../data/app_state.dart';
import '../data/models.dart';
import 'analytics.dart';
import 'guidelines.dart';
import 'report.dart';
import 'utm.dart';

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Status colour class used on the map and in exports.
String sampleClass(AppState app, Sample s) {
  if (s.isControl) return 'control';
  if (s.results.isEmpty) return 'pending';
  return sampleExceeds(app, s) ? 'exceeds' : 'complies';
}

String geoJson(AppState app, List<Sample> samples) {
  final features = <Map<String, dynamic>>[];
  for (final s in samples.where((s) => s.lat != null && s.lon != null)) {
    final set = app.limitsFor(s);
    final props = <String, dynamic>{
      'code': s.code,
      'site': s.site,
      'project': s.project,
      'matrix': s.matrix.label,
      'control': s.isControl,
      'collected': s.collectedAt.toIso8601String(),
      'status': s.status.label,
      'class': sampleClass(app, s),
      'client': app.client(s.clientId)?.name ?? '',
      'utm29n_x': toUtm(s.lat!, s.lon!, zone: 29).easting.round(),
      'utm29n_y': toUtm(s.lat!, s.lon!, zone: 29).northing.round(),
      'exceedances': s.results.where((r) {
        final k = checkResult(r, set).status;
        return k == Compliance.exceed || k == Compliance.belowMin;
      }).length,
    };
    for (final r in s.results) {
      final key = r.unit.isEmpty ? r.parameter : '${r.parameter} [${r.unit}]';
      props[key] = r.belowLod ? '<${r.lod ?? 'LOD'}' : r.value;
    }
    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [s.lon, s.lat],
      },
      'properties': props,
    });
  }
  return const JsonEncoder.withIndent('  ').convert({'type': 'FeatureCollection', 'name': 'LabLedger samples', 'features': features});
}

String kml(AppState app, List<Sample> samples, {String name = 'LabLedger samples'}) {
  const styles = {'complies': 'ff55c22b', 'exceeds': 'ff3a3aff', 'control': 'ffffa34d', 'pending': 'ffa0a0a0'}; // aabbggrr
  final b = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>${_esc(name)}</name>\n');
  for (final e in styles.entries) {
    b.write('<Style id="${e.key}"><IconStyle><color>${e.value}</color><scale>1.1</scale>'
        '<Icon><href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href></Icon></IconStyle></Style>\n');
  }
  final projects = samples.map((s) => s.project.isEmpty ? 'No project' : s.project).toSet().toList()..sort();
  for (final p in projects) {
    b.write('<Folder><name>${_esc(p)}</name>\n');
    for (final s in samples.where((s) => (s.project.isEmpty ? 'No project' : s.project) == p && s.lat != null && s.lon != null)) {
      final set = app.limitsFor(s);
      final rows = StringBuffer();
      for (final r in s.results) {
        final k = checkResult(r, set);
        final bad = k.status == Compliance.exceed || k.status == Compliance.belowMin;
        rows.write('<tr><td>${_esc(r.parameter)}</td><td${bad ? ' style="color:#c62828;font-weight:bold"' : ''}>${_esc(resultText(r))} ${_esc(r.unit)}</td>'
            '<td>${_esc(k.limit?.text ?? '')}</td></tr>');
      }
      final desc = '<b>${_esc(s.site)}</b><br/>${_esc(s.matrix.label)} · ${shortDate(s.collectedAt)} · ${_esc(s.status.label)}'
          '${s.isControl ? '<br/>Control sample' : ''}'
          '${rows.isEmpty ? '' : '<table border="1" cellpadding="2" style="border-collapse:collapse;font-size:11px"><tr><th>Parameter</th><th>Result</th><th>Limit</th></tr>$rows</table>'}';
      b.write('<Placemark><name>${_esc(s.code)}</name><styleUrl>#${sampleClass(app, s)}</styleUrl>'
          '<TimeStamp><when>${s.collectedAt.toIso8601String()}</when></TimeStamp>'
          '<description><![CDATA[$desc]]></description>'
          '<Point><coordinates>${s.lon},${s.lat},0</coordinates></Point></Placemark>\n');
    }
    b.write('</Folder>\n');
  }
  b.write('</Document></kml>\n');
  return b.toString();
}
