import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/map_models.dart';

class ExportUtils {
  static Future<String> pinsToGpx(List<MapPin> pins, String name) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${name}_pins.gpx');
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<gpx version="1.1" creator="BorneoGIS Navigator">');
    for (final pin in pins) {
      buf.writeln('  <wpt lat="${pin.latitude}" lon="${pin.longitude}">');
      buf.writeln('    <name>${pin.label.isEmpty ? "Pin" : pin.label}</name>');
      buf.writeln('    <time>${pin.createdAt.toUtc().toIso8601String()}</time>');
      buf.writeln('  </wpt>');
    }
    buf.writeln('</gpx>');
    await file.writeAsString(buf.toString());
    return file.path;
  }

  static Future<String> pinsToKml(List<MapPin> pins, String name) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${name}_pins.kml');
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buf.writeln('<Document><name>$name</name>');
    for (final pin in pins) {
      buf.writeln('  <Placemark>');
      buf.writeln('    <name>${pin.label.isEmpty ? "Pin" : pin.label}</name>');
      buf.writeln('    <Point><coordinates>${pin.longitude},${pin.latitude},0</coordinates></Point>');
      buf.writeln('  </Placemark>');
    }
    buf.writeln('</Document></kml>');
    await file.writeAsString(buf.toString());
    return file.path;
  }

  static Future<String> toGeoJson(List<MapPin> pins, List<MapTrack> tracks, String name) async {
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name.geojson');
    final features = <String>[];

    for (final pin in pins) {
      features.add('''{
        "type": "Feature",
        "geometry": {"type": "Point", "coordinates": [${pin.longitude}, ${pin.latitude}]},
        "properties": {"name": "${pin.label}", "type": "pin"}
      }''');
    }

    for (final track in tracks) {
      final coords = track.points.map((p) => '[${p.longitude}, ${p.latitude}]').join(',');
      features.add('''{
        "type": "Feature",
        "geometry": {"type": "LineString", "coordinates": [$coords]},
        "properties": {"name": "${track.name}", "type": "track"}
      }''');
    }

    final geojson = '{"type": "FeatureCollection", "features": [${features.join(',')}]}';
    await file.writeAsString(geojson);
    return file.path;
  }
}
