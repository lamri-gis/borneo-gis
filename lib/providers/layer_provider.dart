import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/layer_models.dart';

enum HighlightType { pin, track, line, polygon }

class HighlightState {
  final String id;
  final HighlightType type;
  const HighlightState({required this.id, required this.type});
}

class LayerProvider extends ChangeNotifier {
  List<FieldLayer> _layers = [];
  FieldLayer? _activeLayer;
  LayerTrack? _recordingTrack;
  String? _recordingLayerId; // simpan layerId saat start recording
  HighlightState? _highlight;
  AreaUnit _pendingPolygonUnit = AreaUnit.hectare;
  String? _highlightedFileId; // untuk highlight nama file import

  List<FieldLayer> get layers => _layers;
  FieldLayer? get activeLayer => _activeLayer;
  LayerTrack? get recordingTrack => _recordingTrack;
  bool get isRecording => _recordingTrack != null;
  HighlightState? get highlight => _highlight;
  AreaUnit get pendingPolygonUnit => _pendingPolygonUnit;
  String? get highlightedFileId => _highlightedFileId;

  void setPendingPolygonUnit(AreaUnit unit) {
    _pendingPolygonUnit = unit;
  }

  void setHighlightWithFile(String id, HighlightType type, {String? fileId}) {
    _highlight = HighlightState(id: id, type: type);
    _highlightedFileId = fileId;
    notifyListeners();
  }

  LayerProvider() { _load(); }

  void setHighlight(String id, HighlightType type) {
    _highlight = HighlightState(id: id, type: type);
    _highlightedFileId = null;
    notifyListeners();
  }

  void clearHighlight() {
    _highlight = null;
    _highlightedFileId = null;
    notifyListeners();
  }

  // ── LAYER ──────────────────────────────────────────

  void setActiveLayer(FieldLayer? layer) {
    _activeLayer = layer;
    notifyListeners();
  }

  Future<void> addLayer(FieldLayer layer) async {
    _layers.add(layer);
    _activeLayer = layer;
    await _save();
    notifyListeners();
  }

  Future<void> updateLayerRadius(String layerId, double newRadius) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    // Buat layer baru dengan radius berbeda karena field final
    final updated = FieldLayer(
      id: layer.id,
      name: layer.name,
      createdAt: layer.createdAt,
      latitude: layer.latitude,
      longitude: layer.longitude,
      radius: newRadius,
      color: layer.color,
      tracks: layer.tracks,
      pins: layer.pins,
      lines: layer.lines,
      polygons: layer.polygons,
      imports: layer.imports,
    );
    final idx = _layers.indexWhere((l) => l.id == layerId);
    _layers[idx] = updated;
    if (_activeLayer?.id == layerId) _activeLayer = updated;
    await _save();
    notifyListeners();
  }

  Future<void> removeLayer(String id) async {
    final layer = _layers.firstWhere((l) => l.id == id);
    if (!layer.isEmpty) return;
    _layers.removeWhere((l) => l.id == id);
    if (_activeLayer?.id == id) _activeLayer = null;
    await _save();
    notifyListeners();
  }

  int todayLayerAutoIndex(DateTime dt) {
    final yy = dt.year.toString().substring(2);
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final prefix = 'LAYER$yy$mm$dd[';
    int max = 0;
    for (final l in _layers) {
      if (l.name.startsWith(prefix)) {
        final inner = l.name.substring(prefix.length, l.name.length - 1);
        final n = int.tryParse(inner);
        if (n != null && n > max) max = n;
      }
    }
    return max + 1;
  }

  // ── PIN ────────────────────────────────────────────

  Future<bool> addPin(LayerPin pin) async {
    if (_activeLayer == null) return false;
    if (!_activeLayer!.containsPoint(pin.latitude, pin.longitude)) return false;
    _activeLayer!.pins.add(pin);
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> removePin(String layerId, String pinId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.pins.removeWhere((p) => p.id == pinId);
    if (_highlight?.id == pinId) _highlight = null;
    await _save();
    notifyListeners();
  }

  Future<void> removePins(String layerId, List<String> pinIds) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.pins.removeWhere((p) => pinIds.contains(p.id));
    await _save();
    notifyListeners();
  }

  Future<void> removeAllPins(String layerId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.pins.clear();
    _highlight = null;
    await _save();
    notifyListeners();
  }

  Future<void> renamePin(String layerId, String pinId, String newName) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final pin = layer.pins.firstWhere((p) => p.id == pinId);
    pin.name = newName;
    await _save();
    notifyListeners();
  }

  Future<void> updatePinColor(String layerId, String pinId, Color color) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final pin = layer.pins.firstWhere((p) => p.id == pinId);
    pin.color = color;
    await _save();
    notifyListeners();
  }

  // ── TRACK ──────────────────────────────────────────

  void startRecording(String? name) {
    if (_activeLayer == null) return;
    final now = DateTime.now();
    _recordingLayerId = _activeLayer!.id;
    _recordingTrack = LayerTrack(
      name: name ?? defaultName('track', now),
      isRecording: true,
    );
    _startForegroundService();
    notifyListeners();
  }

  void _startForegroundService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'borneogis_track',
        channelName: 'BorneoGIS Track Recording',
        channelDescription: 'Notifikasi saat merekam track GPS',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
    FlutterForegroundTask.startService(
      notificationTitle: 'BorneoGIS Navigator',
      notificationText: 'Merekam track GPS...',
    );
  }

  void addTrackPoint(LayerTrackPoint point) {
    if (_recordingTrack == null) return;

    // Filter 1 -- Accuracy filter: skip kalau akurasi > 15 meter
    if (point.accuracy > 15 && point.accuracy > 0) return;

    final points = _recordingTrack!.points;

    if (points.isNotEmpty) {
      final last = points.last;

      // Filter 2 -- Distance filter: skip kalau jarak < 2 meter
      final dist = _haversinePoint(last, point);
      if (dist < 2.0) return;

      // Filter 3 -- Speed filter: skip kalau kecepatan > 50 km/h (tidak masuk akal jalan kaki)
      final timeDiff = point.timestamp.difference(last.timestamp).inMilliseconds / 1000.0;
      if (timeDiff > 0) {
        final speedMs = dist / timeDiff;
        final speedKmh = speedMs * 3.6;
        if (speedKmh > 50) return;
      }
    }

    _recordingTrack!.points.add(point);
    notifyListeners();
  }

  static double _haversinePoint(LayerTrackPoint a, LayerTrackPoint b) {
    const R = 6371000.0;
    const pi = 3.14159265358979;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final sa = _sin2(dLat/2) + _cos(lat1) * _cos(lat2) * _sin2(dLon/2);
    return R * 2 * _atan2(sa);
  }

  static double _sin2(double x) { final s = _sin(x); return s * s; }
  static double _sin(double x) => x - x*x*x/6 + x*x*x*x*x/120;
  static double _cos(double x) => 1 - x*x/2 + x*x*x*x/24;
  static double _atan2(double a) { return 2 * (a < 0.5 ? _sqrt(a) : 3.14159265358979/2 - _sqrt(1-a)); }
  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 10; i++) r = (r + x/r) / 2;
    return r;
  }

  Future<void> stopRecording() async {
    if (_recordingTrack == null) return;
    _recordingTrack!.isRecording = false;
    // Cari layer berdasarkan _recordingLayerId, bukan _activeLayer
    final layerId = _recordingLayerId;
    if (layerId != null) {
      try {
        final layer = _layers.firstWhere((l) => l.id == layerId);
        if (_recordingTrack!.points.isNotEmpty) {
          layer.tracks.add(_recordingTrack!);
        }
      } catch (_) {}
    }
    _recordingTrack = null;
    _recordingLayerId = null;
    FlutterForegroundTask.stopService();
    await _save();
    notifyListeners();
  }

  Future<void> autoSaveTrack() async {
    if (_recordingTrack == null) return;
    if (_recordingTrack!.points.isEmpty) {
      _recordingTrack = null;
      _recordingLayerId = null;
      return;
    }
    _recordingTrack!.isRecording = false;
    final layerId = _recordingLayerId;
    if (layerId != null) {
      try {
        final layer = _layers.firstWhere((l) => l.id == layerId);
        layer.tracks.add(_recordingTrack!);
      } catch (_) {}
    }
    _recordingTrack = null;
    _recordingLayerId = null;
    FlutterForegroundTask.stopService();
    await _save();
    notifyListeners();
  }

  Future<void> removeTrack(String layerId, String trackId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.tracks.removeWhere((t) => t.id == trackId);
    if (_highlight?.id == trackId) _highlight = null;
    await _save();
    notifyListeners();
  }

  Future<void> removeTracks(String layerId, List<String> trackIds) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.tracks.removeWhere((t) => trackIds.contains(t.id));
    await _save();
    notifyListeners();
  }

  Future<void> removeAllTracks(String layerId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.tracks.clear();
    _highlight = null;
    await _save();
    notifyListeners();
  }

  Future<void> renameTrack(String layerId, String trackId, String newName) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final track = layer.tracks.firstWhere((t) => t.id == trackId);
    track.name = newName;
    await _save();
    notifyListeners();
  }

  Future<void> updateTrackColor(String layerId, String trackId, Color color) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final track = layer.tracks.firstWhere((t) => t.id == trackId);
    track.color = color;
    await _save();
    notifyListeners();
  }

  // ── LINE ───────────────────────────────────────────

  Future<void> addLine(String layerId, LayerLine line) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.lines.add(line);
    await _save();
    notifyListeners();
  }

  Future<void> removeLine(String layerId, String lineId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.lines.removeWhere((l) => l.id == lineId);
    if (_highlight?.id == lineId) _highlight = null;
    await _save();
    notifyListeners();
  }

  Future<void> removeAllLines(String layerId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.lines.clear();
    _highlight = null;
    await _save();
    notifyListeners();
  }

  Future<void> renameLine(String layerId, String lineId, String newName) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final line = layer.lines.firstWhere((l) => l.id == lineId);
    line.name = newName;
    await _save();
    notifyListeners();
  }

  Future<void> updateLineColor(String layerId, String lineId, Color color) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final line = layer.lines.firstWhere((l) => l.id == lineId);
    line.color = color;
    await _save();
    notifyListeners();
  }

  // ── POLIGON ────────────────────────────────────────

  Future<void> addPolygon(String layerId, LayerPolygon polygon) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.polygons.add(polygon);
    await _save();
    notifyListeners();
  }

  Future<void> removePolygon(String layerId, String polygonId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.polygons.removeWhere((p) => p.id == polygonId);
    if (_highlight?.id == polygonId) _highlight = null;
    await _save();
    notifyListeners();
  }

  Future<void> removeAllPolygons(String layerId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.polygons.clear();
    _highlight = null;
    await _save();
    notifyListeners();
  }

  Future<void> renamePolygon(String layerId, String polygonId, String newName) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final polygon = layer.polygons.firstWhere((p) => p.id == polygonId);
    polygon.name = newName;
    await _save();
    notifyListeners();
  }

  Future<void> updatePolygonColor(String layerId, String polygonId, Color color) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final polygon = layer.polygons.firstWhere((p) => p.id == polygonId);
    polygon.color = color;
    await _save();
    notifyListeners();
  }

  // ── IMPORT ─────────────────────────────────────────

  Future<void> addImport(String layerId, ImportedFile file) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.imports.add(file);
    await _save();
    notifyListeners();
  }

  Future<void> removeImport(String layerId, String fileId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.imports.removeWhere((f) => f.id == fileId);
    await _save();
    notifyListeners();
  }

  Future<void> removeAllImports(String layerId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.imports.clear();
    await _save();
    notifyListeners();
  }

  Future<void> renameImport(String layerId, String fileId, String newName) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    final file = layer.imports.firstWhere((f) => f.id == fileId);
    file.name = newName;
    await _save();
    notifyListeners();
  }

  // ── ORIGINAL BULK DELETE ───────────────────────────

  Future<void> removeAllOriginal(String layerId) async {
    final layer = _layers.firstWhere((l) => l.id == layerId);
    layer.tracks.clear();
    layer.pins.clear();
    layer.lines.clear();
    layer.polygons.clear();
    _highlight = null;
    await _save();
    notifyListeners();
  }

  // ── PERSIST ────────────────────────────────────────

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_layers.map((l) => l.toJson()).toList());
      await prefs.setString('field_layers', data);
    } catch (e) {
      debugPrint('LayerProvider._save error: $e');
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('field_layers');
      if (data != null) {
        _layers = (jsonDecode(data) as List).map((j) => FieldLayer.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('LayerProvider._load error: $e');
      _layers = [];
    }
    notifyListeners();
  }
}
