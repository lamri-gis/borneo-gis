import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../models/gps_data.dart';

class GpsProvider extends ChangeNotifier {
  final Location _location = Location();
  StreamSubscription? _locationSub;
  StreamSubscription? _compassSub;

  GpsData? _current;
  double _heading = 0;
  bool _isActive = false;
  bool _hasPermission = false;

  GpsData? get current => _current;
  double get heading => _heading;
  bool get isActive => _isActive;
  bool get hasPermission => _hasPermission;
  bool get hasPosition => _current != null;

  Future<void> start() async {
    final perm = await _location.requestPermission();
    if (perm != PermissionStatus.granted) return;
    _hasPermission = true;

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 0.5,
    );

    _locationSub = _location.onLocationChanged.listen((loc) {
      _current = GpsData(
        latitude: loc.latitude ?? 0,
        longitude: loc.longitude ?? 0,
        altitude: loc.altitude ?? 0,
        accuracy: loc.accuracy ?? 0,
        speed: (loc.speed ?? 0) * 3.6, // m/s ke km/h
        heading: loc.heading ?? 0,
        timestamp: DateTime.now(),
      );
      _isActive = true;
      notifyListeners();
    });

    _compassSub = FlutterCompass.events?.listen((event) {
      _heading = event.heading ?? 0;
      notifyListeners();
    });
  }

  void stop() {
    _locationSub?.cancel();
    _compassSub?.cancel();
    _isActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
