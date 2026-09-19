import 'dart:io';
import 'package:xml/xml.dart';
import '../models/layer_models.dart';

class KmlImporter {
  static Future<ImportedFile?> parse(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final name = filePath.split('/').last
        .replaceAll('.kml', '').replaceAll('.KML', '');

    try {
      final doc = XmlDocument.parse(content);
      final pins = <LayerPin>[];
      final tracks = <LayerTrack>[];
      final lines = <LayerLine>[];
      final polygons = <LayerPolygon>[];

      // ── 1. Placemark (Pin, LineString, Polygon) ─────────────────────────
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
            pins.add(LayerPin(
              name: pmName.isEmpty ? defaultName('pin', DateTime.now()) : pmName,
              latitude: lat, longitude: lon, altitude: alt,
            ));
          }
          continue;
        }

        // LineString → Line atau Track (cek timestamp)
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

          final hasTime = pm.findAllElements('TimeStamp').isNotEmpty ||
              pm.findAllElements('TimeSpan').isNotEmpty ||
              pm.findAllElements('when').isNotEmpty;

          if (hasTime && trackPoints.isNotEmpty) {
            tracks.add(LayerTrack(name: pmName.isEmpty ? defaultName('track', DateTime.now()) : pmName, points: trackPoints));
          } else if (linePoints.isNotEmpty) {
            lines.add(LayerLine(name: pmName.isEmpty ? defaultName('line', DateTime.now()) : pmName, points: linePoints));
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
          continue;
        }

        // gx:Track di dalam Placemark
        _parseGxTrack(pm, pmName, tracks);
      }

      // ── 2. gx:Track di luar Placemark (format Avenza) ───────────────────
      // Cari semua elemen Track di seluruh dokumen (dengan atau tanpa namespace gx:)
      for (final el in doc.descendants.whereType<XmlElement>()) {
        if (el.localName == 'Track') {
          // Pastikan belum diproses (tidak di dalam Placemark yang sudah ditangani)
          final inPlacemark = el.ancestors.any((a) => a is XmlElement && a.localName == 'Placemark');
          if (inPlacemark) continue;

          final parentName = el.ancestors
              .whereType<XmlElement>()
              .map((e) => e.findElements('name').firstOrNull?.innerText ?? '')
              .firstWhere((s) => s.isNotEmpty, orElse: () => '');

          _parseGxTrackElement(el, parentName, tracks);
        }
      }

      // ── 3. MultiTrack (beberapa track dalam satu element) ───────────────
      for (final el in doc.descendants.whereType<XmlElement>()) {
        if (el.localName == 'MultiTrack') {
          final parentName = el.ancestors
              .whereType<XmlElement>()
              .map((e) => e.findElements('name').firstOrNull?.innerText ?? '')
              .firstWhere((s) => s.isNotEmpty, orElse: () => '');

          for (final track in el.findAllElements('Track')) {
            _parseGxTrackElement(track, parentName, tracks);
          }
        }
      }

      return ImportedFile(
        name: name, filePath: filePath,
        pins: pins, tracks: tracks, lines: lines, polygons: polygons,
      );
    } catch (e) {
      return null;
    }
  }

  static void _parseGxTrack(XmlElement pm, String pmName, List<LayerTrack> tracks) {
    // Cari Track element (gx:Track) di dalam Placemark
    for (final el in pm.descendants.whereType<XmlElement>()) {
      if (el.localName == 'Track') {
        _parseGxTrackElement(el, pmName, tracks);
        return;
      }
    }
  }

  static void _parseGxTrackElement(XmlElement el, String name, List<LayerTrack> tracks) {
    // Format gx:Track: <when>timestamp</when> + <gx:coord>lon lat alt</gx:coord>
    final whens = el.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'when')
        .map((e) => e.innerText)
        .toList();

    final coords = el.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'coord')
        .map((e) => e.innerText)
        .toList();

    if (coords.isEmpty) return;

    final trackPoints = <LayerTrackPoint>[];
    for (int i = 0; i < coords.length; i++) {
      // gx:coord format: "lon lat alt" (spasi sebagai separator)
      final parts = coords[i].trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final lon = double.tryParse(parts[0]) ?? 0;
        final lat = double.tryParse(parts[1]) ?? 0;
        final alt = parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0.0;
        final time = i < whens.length
            ? DateTime.tryParse(whens[i]) ?? DateTime.now()
            : DateTime.now();
        trackPoints.add(LayerTrackPoint(latitude: lat, longitude: lon, altitude: alt, timestamp: time));
      }
    }

    if (trackPoints.isNotEmpty) {
      tracks.add(LayerTrack(
        name: name.isEmpty ? defaultName('track', DateTime.now()) : name,
        points: trackPoints,
      ));
    }
  }
}
