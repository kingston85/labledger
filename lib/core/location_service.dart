import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum GpsStatus { starting, serviceOff, denied, deniedForever, live, error }

/// Streams the phone's GPS position and exposes the latest fix.
class LocationService extends ChangeNotifier {
  GpsStatus status = GpsStatus.starting;
  Position? position;
  String? errorText;
  StreamSubscription<Position>? _sub;

  LatLng? get latLng =>
      position == null ? null : LatLng(position!.latitude, position!.longitude);
  double? get accuracy => position?.accuracy;
  bool get hasFix => position != null && status == GpsStatus.live;

  Future<void> start() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        status = GpsStatus.serviceOff;
        notifyListeners();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        status = GpsStatus.denied;
        notifyListeners();
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        status = GpsStatus.deniedForever;
        notifyListeners();
        return;
      }
      await _sub?.cancel();
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen((p) {
        position = p;
        status = GpsStatus.live;
        notifyListeners();
      }, onError: (Object e) {
        status = GpsStatus.error;
        errorText = e.toString();
        notifyListeners();
      });
      // Show a first fix quickly if one is cached.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && position == null) {
        position = last;
        status = GpsStatus.live;
        notifyListeners();
      }
    } catch (e) {
      status = GpsStatus.error;
      errorText = e.toString();
      notifyListeners();
    }
  }

  Future<void> openSettings() async {
    if (status == GpsStatus.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  String get statusText {
    switch (status) {
      case GpsStatus.starting:
        return 'Finding GPS…';
      case GpsStatus.serviceOff:
        return 'Location is off';
      case GpsStatus.denied:
      case GpsStatus.deniedForever:
        return 'Location permission needed';
      case GpsStatus.live:
        return 'GPS live';
      case GpsStatus.error:
        return 'GPS error';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
