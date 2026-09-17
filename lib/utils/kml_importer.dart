import 'dart:io';
import 'package:xml/xml.dart';
import '../models/layer_models.dart';

class KmlImporter {
  // Parse file KML dan klasifikasi geometri ke 4 tab
  static Future<ImportedFile?> parse(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final name = filePath.split('/').last.replaceAll('.kml', '').replaceAll('.KML', '');

    try {
      final doc = XmlDocument.parse(content);
      final pins = <LayerPin>[];
      final tracks = <LayerTrack>[];
      final lines = <LayerLine>[];
      final polygons = <LayerPolygon>[];

      for (final pm in doc.findAllElements('Placemark')) {
        final pmName = pm.findElements('name').firstOrNull?.innerText ?? '';

        // Point → Pin
        final point = pm.findElements('Point').firstOrNull;
        if (point != null) {
          final coords = point.findElements('coordinates').firstOrNull?.innerText.trim() ?? '';
          final parts = coords.split(',');
          if (parts.length >= 2) {
            final lon = double.tryParse(parts[0].trim()) ?? 0;
            final lat = double.tryParse(parts[1].trim()) ?? 0;
            final alt = parts.length > 2 ? double.tryParse(parts[2].trim()) ?? 0 : 0.0;
            pins.add(LayerPin(name: pmName.isEmpty ? defaultName('pin', DateTime.now()) : pmName, latitude: lat, longitude: lon, altitude: alt));
          }
          continue;
        }

        // LineString → cek apakah Track atau Line
        // Track biasanya ada di dalam gx:Track atau MultiGeometry, atau punya timeStamp
        final ls = pm.findElements('LineString').firstOrNull;
        if (ls != null) {
          final coordsStr = ls.findElements('coordinates').firstOrNull?.innerText.trim() ?? '';
          final linePoints = <LinePoint>[];
          final trackPoints = <LayerTrackPoint>[];

          for (final coord in coordsStr.split(RegExp(r'\s+'))) {
            final parts = coord.split(',');
            if (parts.length >= 2) {
              final lon = double.tryParse(parts[0]) ?? 0;
              final lat = double.tryParse(parts[1]) ?? 0;
              final alt = parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0.0;
              linePoints.add(LinePoint(latitude: lat, longitude: lon));
              trackPoints.add(LayerTrackPoint(latitude: lat, longitude: lon, altitude: alt, timestamp: DateTime.now()));
            }
          }

          // Cek apakah ada TimeStamp/TimeSpan -- kalau ada, ini track GPS
          final hasTime = pm.findAllElements('TimeStamp').isNotEmpty ||
              pm.findAllElements('TimeSpan').isNotEmpty ||
              pm.findAllElements('when').isNotEmpty;

          if (hasTime) {
            if (trackPoints.isNotEmpty) {
              tracks.add(LayerTrack(name: pmName.isEmpty ? defaultName('track', DateTime.now()) : pmName, points: trackPoints));
            }
          } else {
            if (linePoints.isNotEmpty) {
              lines.add(LayerLine(name: pmName.isEmpty ? defaultName('line', DateTime.now()) : pmName, points: linePoints));
            }
          }
          continue;
        }

        // gx:Track → Track GPS
        final gxTrack = pm.findAllElements('Track').firstOrNull;
        if (gxTrack != null) {
          final whens = gxTrack.findElements('when').map((e) => e.innerText).toList();
          final coords = gxTrack.findElements('coord').map((e) => e.innerText).toList();
          final trackPoints = <LayerTrackPoint>[];
          for (int i = 0; i < coords.length; i++) {
            final parts = coords[i].trim().split(' ');
            if (parts.length >= 2) {
              final lon = double.tryParse(parts[0]) ?? 0;
              final lat = double.tryParse(parts[1]) ?? 0;
              final alt = parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0.0;
              final time = i < whens.length ? DateTime.tryParse(whens[i]) ?? DateTime.now() : DateTime.now();
              trackPoints.add(LayerTrackPoint(latitude: lat, longitude: lon, altitude: alt, timestamp: time));
            }
          }
          if (trackPoints.isNotEmpty) {
            tracks.add(LayerTrack(name: pmName.isEmpty ? defaultName('track', DateTime.now()) : pmName, points: trackPoints));
          }
          continue;
        }

        // Polygon → Poligon
        final polygon = pm.findElements('Polygon').firstOrNull;
        if (polygon != null) {
          final outer = polygon.findElements('outerBoundaryIs').firstOrNull;
          final ring = outer?.findElements('LinearRing').firstOrNull;
          final coordsStr = ring?.findElements('coordinates').firstOrNull?.innerText.trim() ?? '';
          final polyPoints = <LinePoint>[];
          for (final coord in coordsStr.split(RegExp(r'\s+'))) {
            final parts = coord.split(',');
            if (parts.length >= 2) {
              final lon = double.tryParse(parts[0]) ?? 0;
              final lat = double.tryParse(parts[1]) ?? 0;
              polyPoints.add(LinePoint(latitude: lat, longitude: lon));
            }
          }
          if (polyPoints.isNotEmpty) {
            polygons.add(LayerPolygon(name: pmName.isEmpty ? defaultName('poly', DateTime.now()) : pmName, points: polyPoints));
          }
        }
      }

      return ImportedFile(
        name: name,
        filePath: filePath,
        pins: pins,
        tracks: tracks,
        lines: lines,
        polygons: polygons,
      );
    } catch (e) {
      return null;
    }
  }
}
