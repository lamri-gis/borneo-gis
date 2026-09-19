import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/layer_models.dart';

enum ExportSource { original, import_ }
enum ExportType { all, track, pin, line, polygon }
enum ExportMethod { save, share }

class KmlExporter {
  static Future<String?> exportOriginal({
    required FieldLayer layer,
    required ExportType type,
    required String fileName,
    required ExportMethod method,
    required BuildContext context,
  }) async {
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
    return _handleExport(fileName, buf.toString(), method, context);
  }

  static Future<String?> exportImport({
    required ImportedFile importedFile,
    required ExportType type,
    required String fileName,
    required ExportMethod method,
    required BuildContext context,
  }) async {
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
    return _handleExport(fileName, buf.toString(), method, context);
  }

  static Future<String?> _handleExport(String fileName, String content, ExportMethod method, BuildContext context) async {
    final safeName = fileName.trim().isEmpty ? 'export' : fileName.trim();
    final kmlName = safeName.endsWith('.kml') ? safeName : '$safeName.kml';

    if (method == ExportMethod.share) {
      return _shareFile(kmlName, content);
    } else {
      return _saveToStorage(kmlName, content, context);
    }
  }

  // Share via Android share sheet
  static Future<String?> _shareFile(String fileName, String content) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(content, flush: true);
      await Share.shareXFiles([XFile(tempFile.path)], text: fileName);
      return 'shared';
    } catch (e) {
      return null;
    }
  }

  // Simpan ke storage dengan permission handling
  static Future<String?> _saveToStorage(String fileName, String content, BuildContext context) async {
    try {
      // Android 11+ -- request MANAGE_EXTERNAL_STORAGE
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          final result = await Permission.manageExternalStorage.request();
          if (!result.isGranted) {
            // Fallback ke storage biasa
            final storageStatus = await Permission.storage.request();
            if (!storageStatus.isGranted) return null;
          }
        }
      }

      final dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih folder penyimpanan',
      );
      if (dirPath == null) return null;

      final path = '$dirPath/$fileName';
      final file = File(path);
      await file.writeAsString(content, flush: true);
      return path;
    } catch (e) {
      return null;
    }
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
