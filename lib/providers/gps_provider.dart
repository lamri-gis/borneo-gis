import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../models/gps_data.dart';

class GpsProvider extends ChangeNotifier {
  StreamSubscription<Position>? _locationSub;
  StreamSubscription? _compassSub;

  GpsData? _current;
  double _heading = 0;
  bool _isActive = false;
  bool _hasPermission = false;
  String? _errorMessage;

  GpsData? get current => _current;
  double get heading => _heading;
  bool get isActive => _isActive;
  bool get hasPermission => _hasPermission;
  bool get hasPosition => _current != null;
  String? get errorMessage => _errorMessage;

  Future<void> start() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Layanan lokasi tidak aktif. Nyalakan GPS di pengaturan.';
        notifyListeners();
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _errorMessage = 'Izin lokasi ditolak.';
          notifyListeners();
          return;
        }
      }

      if (perm == LocationPermission.deniedForever) {
        _errorMessage = 'Izin lokasi diblokir. Buka Pengaturan untuk mengaktifkan.';
        notifyListeners();
        return;
      }

      _hasPermission = true;
      _errorMessage = null;

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      );

      _locationSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
        _current = GpsData(
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude,
          accuracy: pos.accuracy,
          speed: pos.speed * 3.6,
          heading: pos.heading,
          timestamp: pos.timestamp,
        );
        _isActive = true;
        _errorMessage = null;
        notifyListeners();
      });

      _compassSub = FlutterCompass.events?.listen((event) {
        _heading = event.heading ?? 0;
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = 'Error GPS: $e';
      notifyListeners();
    }
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
