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

      // Ambil timestamp file dari metadata dokumen
      final fileTime = _extractDocumentTime(doc);

      // ── 1. Placemark ────────────────────────────────────────────────────
      for (final pm in doc.findAllElements('Placemark')) {
        final pmName = pm.findElements('name').firstOrNull?.innerText ?? '';
        final pmTime = _extractPlacemarkTime(pm) ?? fileTime ?? DateTime.now();

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
              name: pmName.isEmpty ? defaultName('pin', pmTime) : pmName,
              latitude: lat, longitude: lon, altitude: alt,
              createdAt: pmTime,
            ));
          }
          continue;
        }

        // LineString → Line atau Track
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
              trackPoints.add(LayerTrackPoint(latitude: lat, longitude: lon, altitude: alt, timestamp: pmTime));
            }
          }

          final hasTime = pm.findAllElements('TimeStamp').isNotEmpty ||
              pm.findAllElements('TimeSpan').isNotEmpty ||
              pm.findAllElements('when').isNotEmpty;

          if (hasTime && trackPoints.isNotEmpty) {
            tracks.add(LayerTrack(
              name: pmName.isEmpty ? defaultName('track', pmTime) : pmName,
              points: trackPoints,
              createdAt: pmTime,
            ));
          } else if (linePoints.isNotEmpty) {
            lines.add(LayerLine(
              name: pmName.isEmpty ? defaultName('line', pmTime) : pmName,
              points: linePoints,
              createdAt: pmTime,
            ));
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
            polygons.add(LayerPolygon(
              name: pmName.isEmpty ? defaultName('poly', pmTime) : pmName,
              points: polyPoints,
              createdAt: pmTime,
            ));
          }
          continue;
        }

        // gx:Track di dalam Placemark
        _parseGxTrack(pm, pmName, pmTime, tracks);
      }

      // ── 2. gx:Track di luar Placemark (format Avenza) ───────────────────
      for (final el in doc.descendants.whereType<XmlElement>()) {
        if (el.localName == 'Track') {
          final inPlacemark = el.ancestors.any((a) => a is XmlElement && a.localName == 'Placemark');
          if (inPlacemark) continue;

          final parentName = el.ancestors
              .whereType<XmlElement>()
              .map((e) => e.findElements('name').firstOrNull?.innerText ?? '')
              .firstWhere((s) => s.isNotEmpty, orElse: () => '');

          _parseGxTrackElement(el, parentName, fileTime ?? DateTime.now(), tracks);
        }
      }

      // ── 3. MultiTrack ────────────────────────────────────────────────────
      for (final el in doc.descendants.whereType<XmlElement>()) {
        if (el.localName == 'MultiTrack') {
          final parentName = el.ancestors
              .whereType<XmlElement>()
              .map((e) => e.findElements('name').firstOrNull?.innerText ?? '')
              .firstWhere((s) => s.isNotEmpty, orElse: () => '');

          for (final track in el.findAllElements('Track')) {
            _parseGxTrackElement(track, parentName, fileTime ?? DateTime.now(), tracks);
          }
        }
      }

      return ImportedFile(
        name: name,
        filePath: filePath,
        importedAt: fileTime ?? DateTime.now(),
        pins: pins, tracks: tracks, lines: lines, polygons: polygons,
      );
    } catch (e) {
      return null;
    }
  }

  // Ambil timestamp dari metadata dokumen KML
  static DateTime? _extractDocumentTime(XmlDocument doc) {
    // Coba atom:updated atau atom:created
    for (final tag in ['updated', 'created', 'modified']) {
      final el = doc.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == tag)
          .firstOrNull;
      if (el != null) {
        final t = DateTime.tryParse(el.innerText.trim());
        if (t != null) return t;
      }
    }

    // Coba TimeStamp di level Document
    final doc_ = doc.findAllElements('Document').firstOrNull;
    if (doc_ != null) {
      final ts = doc_.findElements('TimeStamp').firstOrNull;
      final when = ts?.findElements('when').firstOrNull?.innerText;
      if (when != null) return DateTime.tryParse(when);
    }

    return null;
  }

  // Ambil timestamp dari Placemark
  static DateTime? _extractPlacemarkTime(XmlElement pm) {
    // TimeStamp
    final ts = pm.findElements('TimeStamp').firstOrNull;
    if (ts != null) {
      final when = ts.findElements('when').firstOrNull?.innerText;
      if (when != null) return DateTime.tryParse(when);
    }

    // TimeSpan -- pakai begin
    final tspan = pm.findElements('TimeSpan').firstOrNull;
    if (tspan != null) {
      final begin = tspan.findElements('begin').firstOrNull?.innerText;
      if (begin != null) return DateTime.tryParse(begin);
    }

    // when langsung
    final when = pm.findElements('when').firstOrNull?.innerText;
    if (when != null) return DateTime.tryParse(when);

    return null;
  }

  static void _parseGxTrack(XmlElement pm, String pmName, DateTime pmTime, List<LayerTrack> tracks) {
    for (final el in pm.descendants.whereType<XmlElement>()) {
      if (el.localName == 'Track') {
        _parseGxTrackElement(el, pmName, pmTime, tracks);
        return;
      }
    }
  }

  static void _parseGxTrackElement(XmlElement el, String name, DateTime fallbackTime, List<LayerTrack> tracks) {
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

    // Waktu mulai track dari when pertama
    final trackStartTime = whens.isNotEmpty
        ? DateTime.tryParse(whens[0]) ?? fallbackTime
        : fallbackTime;

    final trackPoints = <LayerTrackPoint>[];
    for (int i = 0; i < coords.length; i++) {
      final parts = coords[i].trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final lon = double.tryParse(parts[0]) ?? 0;
        final lat = double.tryParse(parts[1]) ?? 0;
        final alt = parts.length > 2 ? double.tryParse(parts[2]) ?? 0 : 0.0;
        final time = i < whens.length
            ? DateTime.tryParse(whens[i]) ?? fallbackTime
            : fallbackTime;
        trackPoints.add(LayerTrackPoint(latitude: lat, longitude: lon, altitude: alt, timestamp: time));
      }
    }

    if (trackPoints.isNotEmpty) {
      tracks.add(LayerTrack(
        name: name.isEmpty ? defaultName('track', trackStartTime) : name,
        points: trackPoints,
        createdAt: trackStartTime,
      ));
    }
  }
}
