import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../models/gps_data.dart';
import '../models/layer_models.dart';
import '../providers/layer_provider.dart';

class GpsProvider extends ChangeNotifier {
  StreamSubscription<Position>? _locationSub;
  StreamSubscription? _compassSub;
  LayerProvider? _layerProvider;

  GpsData? _current;
  GpsData? _firstFix;
  double _heading = 0;
  bool _isActive = false;
  bool _hasPermission = false;
  bool _hasCompass = false;
  String? _errorMessage;

  GpsData? get current => _current;
  GpsData? get firstFix => _firstFix;
  double get heading => _heading;
  bool get isActive => _isActive;
  bool get hasPermission => _hasPermission;
  bool get hasPosition => _current != null;
  bool get hasCompass => _hasCompass;
  String? get errorMessage => _errorMessage;

  // Set LayerProvider untuk addTrackPoint langsung dari GPS stream
  void setLayerProvider(LayerProvider lp) {
    _layerProvider = lp;
  }

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

      final settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: const Duration(milliseconds: 500),
        distanceFilter: 0,
        forceLocationManager: false,
      );

      _locationSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
        final data = GpsData(
          latitude: pos.latitude,
          longitude: pos.longitude,
          altitude: pos.altitude,
          accuracy: pos.accuracy,
          speed: pos.speed * 3.6,
          heading: pos.heading,
          timestamp: pos.timestamp,
        );
        _current = data;
        _firstFix ??= data;
        _isActive = true;
        _errorMessage = null;

        // Rekam track langsung dari GPS stream -- bukan dari widget build()
        if (_layerProvider != null && _layerProvider!.isRecording) {
          _layerProvider!.addTrackPoint(LayerTrackPoint(
            latitude: pos.latitude,
            longitude: pos.longitude,
            altitude: pos.altitude,
            accuracy: pos.accuracy,
            timestamp: pos.timestamp,
          ));
        }

        notifyListeners();
      }, onError: (e) {
        // GPS mati/error -- auto save track
        _isActive = false;
        _layerProvider?.autoSaveTrack();
        notifyListeners();
      });

      // Subscribe kompas
      _compassSub = FlutterCompass.events?.listen((event) {
        if (event.heading != null) {
          if (!_hasCompass) {
            _hasCompass = true;
            notifyListeners();
          }
          _heading = event.heading!;
          notifyListeners();
        }
      });

      await Future.delayed(const Duration(seconds: 2));
      if (!_hasCompass) {
        _compassSub?.cancel();
        _compassSub = null;
      }
    } catch (e) {
      _errorMessage = 'Error GPS: $e';
      _layerProvider?.autoSaveTrack();
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
