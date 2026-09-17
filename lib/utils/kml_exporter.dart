import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/layer_models.dart';

enum ExportSource { original, import_ }
enum ExportType { all, track, pin, line, polygon }

class KmlExporter {
  // Export original section
  static Future<String?> exportOriginal({
    required FieldLayer layer,
    required ExportType type,
    required String fileName,
  }) async {
    final path = await _pickSavePath(fileName);
    if (path == null) return null;

    final buf = StringBuffer();
    _writeHeader(buf, fileName);

    if (type == ExportType.all || type == ExportType.pin) {
      for (final pin in layer.pins) _writePin(buf, pin.name, pin.latitude, pin.longitude, pin.altitude);
    }
    if (type == ExportType.all || type == ExportType.track) {
      for (final track in layer.tracks) _writeLineString(buf, track.name, track.points.map((p) => _Coord(p.latitude, p.longitude, p.altitude)).toList());
    }
    if (type == ExportType.all || type == ExportType.line) {
      for (final line in layer.lines) _writeLineString(buf, line.name, line.points.map((p) => _Coord(p.latitude, p.longitude, 0)).toList());
    }
    if (type == ExportType.all || type == ExportType.polygon) {
      for (final poly in layer.polygons) _writePolygon(buf, poly.name, poly.points);
    }

    _writeFooter(buf);
    final file = File(path);
    await file.writeAsString(buf.toString());
    return path;
  }

  // Export import section
  static Future<String?> exportImport({
    required ImportedFile importedFile,
    required ExportType type,
    required String fileName,
  }) async {
    final path = await _pickSavePath(fileName);
    if (path == null) return null;

    final buf = StringBuffer();
    _writeHeader(buf, fileName);

    if (type == ExportType.all || type == ExportType.pin) {
      for (final pin in importedFile.pins) _writePin(buf, pin.name, pin.latitude, pin.longitude, pin.altitude);
    }
    if (type == ExportType.all || type == ExportType.track) {
      for (final track in importedFile.tracks) _writeLineString(buf, track.name, track.points.map((p) => _Coord(p.latitude, p.longitude, p.altitude)).toList());
    }
    if (type == ExportType.all || type == ExportType.line) {
      for (final line in importedFile.lines) _writeLineString(buf, line.name, line.points.map((p) => _Coord(p.latitude, p.longitude, 0)).toList());
    }
    if (type == ExportType.all || type == ExportType.polygon) {
      for (final poly in importedFile.polygons) _writePolygon(buf, poly.name, poly.points);
    }

    _writeFooter(buf);
    final file = File(path);
    await file.writeAsString(buf.toString());
    return path;
  }

  // Pilih folder simpan -- pakai FilePicker
  static Future<String?> _pickSavePath(String fileName) async {
    String? dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return null;
    final name = fileName.endsWith('.kml') ? fileName : '$fileName.kml';
    return '$dirPath/$name';
  }

  static void _writeHeader(StringBuffer buf, String name) {
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buf.writeln('<Document>');
    buf.writeln('  <name>$name</name>');
  }

  static void _writeFooter(StringBuffer buf) {
    buf.writeln('</Document>');
    buf.writeln('</kml>');
  }

  static void _writePin(StringBuffer buf, String name, double lat, double lon, double alt) {
    buf.writeln('  <Placemark>');
    buf.writeln('    <name>$name</name>');
    buf.writeln('    <Point>');
    buf.writeln('      <coordinates>$lon,$lat,$alt</coordinates>');
    buf.writeln('    </Point>');
    buf.writeln('  </Placemark>');
  }

  static void _writeLineString(StringBuffer buf, String name, List<_Coord> coords) {
    buf.writeln('  <Placemark>');
    buf.writeln('    <name>$name</name>');
    buf.writeln('    <LineString>');
    buf.writeln('      <coordinates>');
    for (final c in coords) buf.writeln('        ${c.lon},${c.lat},${c.alt}');
    buf.writeln('      </coordinates>');
    buf.writeln('    </LineString>');
    buf.writeln('  </Placemark>');
  }

  static void _writePolygon(StringBuffer buf, String name, List<LinePoint> points) {
    buf.writeln('  <Placemark>');
    buf.writeln('    <name>$name</name>');
    buf.writeln('    <Polygon>');
    buf.writeln('      <outerBoundaryIs>');
    buf.writeln('        <LinearRing>');
    buf.writeln('          <coordinates>');
    for (final p in points) buf.writeln('            ${p.longitude},${p.latitude},0');
    // Tutup poligon ke titik pertama
    if (points.isNotEmpty) buf.writeln('            ${points.first.longitude},${points.first.latitude},0');
    buf.writeln('          </coordinates>');
    buf.writeln('        </LinearRing>');
    buf.writeln('      </outerBoundaryIs>');
    buf.writeln('    </Polygon>');
    buf.writeln('  </Placemark>');
  }
}

class _Coord {
  final double lat, lon, alt;
  const _Coord(this.lat, this.lon, this.alt);
}
