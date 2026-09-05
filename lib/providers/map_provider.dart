import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/map_models.dart';
import '../models/gps_data.dart';

class MapProvider extends ChangeNotifier {
  List<MapPin> _pins = [];
  List<RadiusCircle> _circles = [];
  List<MapOverlay> _overlays = [];

  double _scale = 1.0;
  double _offsetX = 0;
  double _offsetY = 0;

  static const double _baseMetersPerPixel = 10.0;

  List<MapPin> get pins => _pins;
  List<RadiusCircle> get circles => _circles;
  List<MapOverlay> get overlays => _overlays;
  double get scale => _scale;
  double get offsetX => _offsetX;
  double get offsetY => _offsetY;
  double get metersPerPixel => _baseMetersPerPixel / _scale;

  MapProvider() { _load(); }

  Offset latLonToPixel(double lat, double lon, GpsData center, double screenW, double screenH) {
    const metersPerDeg = 111319.9;
    final dLat = lat - center.latitude;
    final dLon = lon - center.longitude;
    final dx = dLon * metersPerDeg * _cosLat(center.latitude);
    final dy = -dLat * metersPerDeg;
    final px = screenW / 2 + (dx / _baseMetersPerPixel) * _scale + _offsetX;
    final py = screenH / 2 + (dy / _baseMetersPerPixel) * _scale + _offsetY;
    return Offset(px, py);
  }

  GpsData pixelToLatLon(double px, double py, GpsData center, double screenW, double screenH) {
    const metersPerDeg = 111319.9;
    final dx = ((px - screenW / 2 - _offsetX) / _scale) * _baseMetersPerPixel;
    final dy = ((py - screenH / 2 - _offsetY) / _scale) * _baseMetersPerPixel;
    final lat = center.latitude - dy / metersPerDeg;
    final lon = center.longitude + dx / (metersPerDeg * _cosLat(center.latitude));
    return GpsData(latitude: lat, longitude: lon, timestamp: DateTime.now());
  }

  double _cosLat(double lat) {
    const pi = 3.14159265358979;
    return math.cos(lat * pi / 180);
  }

  void updateTransform(double scale, double dx, double dy) {
    _scale = scale.clamp(0.1, 50.0);
    _offsetX += dx;
    _offsetY += dy;
    notifyListeners();
  }

  void setScale(double scale) {
    _scale = scale.clamp(0.1, 50.0);
    notifyListeners();
  }

  void resetView() {
    _scale = 1.0;
    _offsetX = 0;
    _offsetY = 0;
    notifyListeners();
  }

  void addPin(MapPin pin) {
    _pins.add(pin);
    _save();
    notifyListeners();
  }

  void removePin(String id) {
    _pins.removeWhere((p) => p.id == id);
    _save();
    notifyListeners();
  }

  void addCircle(RadiusCircle circle) {
    _circles.add(circle);
    _save();
    notifyListeners();
  }

  void removeCircle(String id) {
    _circles.removeWhere((c) => c.id == id);
    _save();
    notifyListeners();
  }

  void updateCircle(RadiusCircle updated) {
    final idx = _circles.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) {
      _circles[idx] = updated;
      _save();
      notifyListeners();
    }
  }

  void addOverlay(MapOverlay overlay) {
    _overlays.add(overlay);
    notifyListeners();
  }

  void removeOverlay(String id) {
    _overlays.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  void toggleOverlay(String id) {
    final idx = _overlays.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      _overlays[idx].visible = !_overlays[idx].visible;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('pins', jsonEncode(_pins.map((p) => p.toJson()).toList()));
    prefs.setString('circles', jsonEncode(_circles.map((c) => c.toJson()).toList()));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final pinsJson = prefs.getString('pins');
    final circlesJson = prefs.getString('circles');
    if (pinsJson != null) {
      _pins = (jsonDecode(pinsJson) as List).map((j) => MapPin.fromJson(j)).toList();
    }
    if (circlesJson != null) {
      _circles = (jsonDecode(circlesJson) as List).map((j) => RadiusCircle.fromJson(j)).toList();
    }
    notifyListeners();
  }
}
