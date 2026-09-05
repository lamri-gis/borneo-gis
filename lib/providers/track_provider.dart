import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/map_models.dart';
import '../models/gps_data.dart';

class TrackProvider extends ChangeNotifier {
  bool _isRecording = false;
  MapTrack? _activeTrack;
  List<MapTrack> _savedTracks = [];

  bool get isRecording => _isRecording;
  MapTrack? get activeTrack => _activeTrack;
  List<MapTrack> get savedTracks => _savedTracks;
  List<TrackPoint> get currentPoints => _activeTrack?.points ?? [];

  void startRecording(String name) {
    _activeTrack = MapTrack(name: name);
    _isRecording = true;
    notifyListeners();
  }

  void addPoint(GpsData gps) {
    if (!_isRecording || _activeTrack == null) return;
    _activeTrack!.points.add(TrackPoint(
      latitude: gps.latitude,
      longitude: gps.longitude,
      altitude: gps.altitude,
      timestamp: gps.timestamp,
    ));
    notifyListeners();
  }

  Future<String?> stopAndSave() async {
    if (_activeTrack == null) return null;
    final track = _activeTrack!;
    _isRecording = false;
    _activeTrack = null;
    _savedTracks.add(track);
    final path = await _exportGpx(track);
    notifyListeners();
    return path;
  }

  void discard() {
    _isRecording = false;
    _activeTrack = null;
    notifyListeners();
  }

  Future<String> _exportGpx(MapTrack track) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${track.name.replaceAll(' ', '_')}.gpx');
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="BorneoGIS Navigator">');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${track.name}</name>');
    buffer.writeln('    <trkseg>');
    for (final pt in track.points) {
      buffer.writeln('      <trkpt lat="${pt.latitude}" lon="${pt.longitude}">');
      buffer.writeln('        <ele>${pt.altitude}</ele>');
      buffer.writeln('        <time>${pt.timestamp.toUtc().toIso8601String()}</time>');
      buffer.writeln('      </trkpt>');
    }
    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> exportKml(MapTrack track) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${track.name.replaceAll(' ', '_')}.kml');
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buffer.writeln('<Document>');
    buffer.writeln('  <name>${track.name}</name>');
    buffer.writeln('  <Placemark>');
    buffer.writeln('    <LineString>');
    buffer.writeln('      <coordinates>');
    for (final pt in track.points) {
      buffer.writeln('        ${pt.longitude},${pt.latitude},${pt.altitude}');
    }
    buffer.writeln('      </coordinates>');
    buffer.writeln('    </LineString>');
    buffer.writeln('  </Placemark>');
    buffer.writeln('</Document>');
    buffer.writeln('</kml>');
    await file.writeAsString(buffer.toString());
    return file.path;
  }
}
