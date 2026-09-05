import 'dart:io';
import 'package:xml/xml.dart';
import '../models/map_models.dart';

class KmlGpxParser {
  static Future<ParsedOverlay?> parse(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final lower = filePath.toLowerCase();
    try {
      if (lower.endsWith('.gpx')) return _parseGpx(content, filePath);
      if (lower.endsWith('.kml')) return _parseKml(content, filePath);
    } catch (e) {
      return null;
    }
    return null;
  }

  static ParsedOverlay _parseGpx(String content, String path) {
    final doc = XmlDocument.parse(content);
    final pins = <MapPin>[];
    final tracks = <MapTrack>[];

    // Waypoints
    for (final wpt in doc.findAllElements('wpt')) {
      final lat = double.tryParse(wpt.getAttribute('lat') ?? '') ?? 0;
      final lon = double.tryParse(wpt.getAttribute('lon') ?? '') ?? 0;
      final name = wpt.findElements('name').firstOrNull?.innerText ?? '';
      pins.add(MapPin(latitude: lat, longitude: lon, label: name));
    }

    // Tracks
    for (final trk in doc.findAllElements('trk')) {
      final name = trk.findElements('name').firstOrNull?.innerText ?? 'Track';
      final points = <TrackPoint>[];
      for (final trkpt in trk.findAllElements('trkpt')) {
        final lat = double.tryParse(trkpt.getAttribute('lat') ?? '') ?? 0;
        final lon = double.tryParse(trkpt.getAttribute('lon') ?? '') ?? 0;
        final ele = double.tryParse(trkpt.findElements('ele').firstOrNull?.innerText ?? '') ?? 0;
        final timeStr = trkpt.findElements('time').firstOrNull?.innerText;
        final time = timeStr != null ? DateTime.tryParse(timeStr) ?? DateTime.now() : DateTime.now();
        points.add(TrackPoint(latitude: lat, longitude: lon, altitude: ele, timestamp: time));
      }
      tracks.add(MapTrack(name: name, points: points));
    }

    return ParsedOverlay(pins: pins, tracks: tracks, filePath: path, type: OverlayType.gpx);
  }

  static ParsedOverlay _parseKml(String content, String path) {
    final doc = XmlDocument.parse(content);
    final pins = <MapPin>[];
    final tracks = <MapTrack>[];

    for (final pm in doc.findAllElements('Placemark')) {
      final name = pm.findElements('name').firstOrNull?.innerText ?? '';
      final point = pm.findElements('Point').firstOrNull;
      if (point != null) {
        final coords = point.findElements('coordinates').firstOrNull?.innerText.trim() ?? '';
        final parts = coords.split(',');
        if (parts.length >= 2) {
          final lon = double.tryParse(parts[0].trim()) ?? 0;
          final lat = double.tryParse(parts[1].trim()) ?? 0;
          pins.add(MapPin(latitude: lat, longitude: lon, label: name));
        }
        continue;
      }
      final ls = pm.findElements('LineString').firstOrNull;
      if (ls != null) {
        final coordsStr = ls.findElements('coordinates').firstOrNull?.innerText.trim() ?? '';
        final points = <TrackPoint>[];
        for (final line in coordsStr.split(RegExp(r'\s+'))) {
          final parts = line.split(',');
          if (parts.length >= 2) {
            final lon = double.tryParse(parts[0]) ?? 0;
            final lat = double.tryParse(parts[1]) ?? 0;
            final alt = parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0.0;
            points.add(TrackPoint(latitude: lat, longitude: lon, altitude: alt, timestamp: DateTime.now()));
          }
        }
        if (points.isNotEmpty) tracks.add(MapTrack(name: name, points: points));
      }
    }

    return ParsedOverlay(pins: pins, tracks: tracks, filePath: path, type: OverlayType.kml);
  }
}

class ParsedOverlay {
  final List<MapPin> pins;
  final List<MapTrack> tracks;
  final String filePath;
  final OverlayType type;

  const ParsedOverlay({
    required this.pins,
    required this.tracks,
    required this.filePath,
    required this.type,
  });
}
