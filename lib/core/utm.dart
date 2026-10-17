// WGS84 <-> UTM conversion (Krüger series, sub-millimetre inside a zone).
// Liberia lies in UTM zone 29N (EPSG:32629), the grid used on EPA field sheets.

import 'dart:math' as math;

class Utm {
  final int zone;
  final bool north;
  final double easting;
  final double northing;
  const Utm(this.zone, this.north, this.easting, this.northing);

  String get zoneLabel => '$zone${north ? 'N' : 'S'}';

  @override
  String toString() => '$zoneLabel ${easting.toStringAsFixed(0)} E ${northing.toStringAsFixed(0)} N';
}

const _a = 6378137.0;
const _f = 1 / 298.257223563;
const _k0 = 0.9996;
const _e0 = 500000.0;

double get _n => _f / (2 - _f);
double get _bigA => _a / (1 + _n) * (1 + _n * _n / 4 + math.pow(_n, 4) / 64);

List<double> get _alpha {
  final n = _n;
  return [
    n / 2 - 2 * n * n / 3 + 5 * n * n * n / 16,
    13 * n * n / 48 - 3 * n * n * n / 5,
    61 * n * n * n / 240,
  ];
}

List<double> get _beta {
  final n = _n;
  return [
    n / 2 - 2 * n * n / 3 + 37 * n * n * n / 96,
    n * n / 48 + n * n * n / 15,
    17 * n * n * n / 480,
  ];
}

List<double> get _delta {
  final n = _n;
  return [
    2 * n - 2 * n * n / 3 - 2 * n * n * n,
    7 * n * n / 3 - 8 * n * n * n / 5,
    56 * n * n * n / 15,
  ];
}

double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));
double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

int utmZoneFor(double lon) => ((lon + 180) / 6).floor().clamp(0, 59).toInt() + 1;

/// Latitude/longitude (degrees) to UTM. [zone] forces a zone (e.g. 29 for Liberia).
Utm toUtm(double lat, double lon, {int? zone}) {
  final z = zone ?? utmZoneFor(lon);
  final lon0 = (z - 1) * 6 - 180 + 3.0;
  final phi = lat * math.pi / 180;
  final lam = (lon - lon0) * math.pi / 180;
  final n = _n;
  final e2n = 2 * math.sqrt(n) / (1 + n);
  final t = _sinh(_atanh(math.sin(phi)) - e2n * _atanh(e2n * math.sin(phi)));
  final xi = math.atan2(t, math.cos(lam));
  final eta = _atanh(math.sin(lam) / math.sqrt(1 + t * t));
  var e = eta, nn = xi;
  final al = _alpha;
  for (var j = 1; j <= 3; j++) {
    e += al[j - 1] * math.cos(2 * j * xi) * _sinh(2 * j * eta);
    nn += al[j - 1] * math.sin(2 * j * xi) * _cosh(2 * j * eta);
  }
  final easting = _e0 + _k0 * _bigA * e;
  var northing = _k0 * _bigA * nn;
  final north = lat >= 0;
  if (!north) northing += 10000000;
  return Utm(z, north, easting, northing);
}

/// UTM to latitude/longitude in degrees, returned as (lat, lon).
(double, double) fromUtm(double easting, double northing, {int zone = 29, bool north = true}) {
  final nVal = north ? northing : northing - 10000000;
  final xi = nVal / (_k0 * _bigA);
  final eta = (easting - _e0) / (_k0 * _bigA);
  var xp = xi, ep = eta;
  final be = _beta;
  for (var j = 1; j <= 3; j++) {
    xp -= be[j - 1] * math.sin(2 * j * xi) * _cosh(2 * j * eta);
    ep -= be[j - 1] * math.cos(2 * j * xi) * _sinh(2 * j * eta);
  }
  final chi = math.asin(math.sin(xp) / _cosh(ep));
  var phi = chi;
  final de = _delta;
  for (var j = 1; j <= 3; j++) {
    phi += de[j - 1] * math.sin(2 * j * chi);
  }
  final lon0 = (zone - 1) * 6 - 180 + 3.0;
  final lam = math.atan2(_sinh(ep), math.cos(xp));
  return (phi * 180 / math.pi, lon0 + lam * 180 / math.pi);
}

/// Interprets a coordinate pair typed by a user. Field sheets sometimes put
/// decimal degrees in "UTM" columns, so small numbers are treated as lat/lon.
/// Returns (lat, lon) or null.
(double, double)? parseCoordinatePair(double a, double b, {int zone = 29, bool north = true}) {
  if (a.abs() <= 90 && b.abs() <= 180) return (a, b);
  if (a.abs() <= 180 && b.abs() <= 90) return (b, a);
  if (a > 100000 && a < 900000 && b >= 0 && b < 10000000) return fromUtm(a, b, zone: zone, north: north);
  return null;
}
