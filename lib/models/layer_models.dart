import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class LayerColors {
  static const List<Color> options = [
    Color(0xFFFF5252),
    Color(0xFF00C853),
    Color(0xFF2196F3),
    Color(0xFFFFD600),
    Color(0xFFFF6D00),
    Color(0xFF9C27B0),
    Color(0xFFFFFFFF),
  ];
  static const List<String> names = ['Merah','Hijau','Biru','Kuning','Oranye','Ungu','Putih'];
}

String defaultName(String prefix, DateTime dt) {
  final yy = dt.year.toString().substring(2);
  final mm = dt.month.toString().padLeft(2,'0');
  final dd = dt.day.toString().padLeft(2,'0');
  final hh = dt.hour.toString().padLeft(2,'0');
  final min = dt.minute.toString().padLeft(2,'0');
  return '$prefix-$yy$mm$dd[$hh:$min]';
}

String defaultLayerName(DateTime dt, String? userInput, int autoIndex) {
  final yy = dt.year.toString().substring(2);
  final mm = dt.month.toString().padLeft(2,'0');
  final dd = dt.day.toString().padLeft(2,'0');
  final suffix = (userInput != null && userInput.trim().isNotEmpty)
      ? userInput.trim().toUpperCase() : '$autoIndex';
  return 'LAYER$yy$mm$dd[$suffix]';
}

class LayerTrackPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;
  const LayerTrackPoint({required this.latitude, required this.longitude, this.altitude=0, required this.timestamp});
  Map<String,dynamic> toJson() => {'lat':latitude,'lon':longitude,'alt':altitude,'ts':timestamp.toIso8601String()};
  factory LayerTrackPoint.fromJson(Map<String,dynamic> j) => LayerTrackPoint(latitude:j['lat'],longitude:j['lon'],altitude:j['alt']??0,timestamp:DateTime.parse(j['ts']));
}

class LinePoint {
  final double latitude;
  final double longitude;
  const LinePoint({required this.latitude, required this.longitude});
  Map<String,dynamic> toJson() => {'lat':latitude,'lon':longitude};
  factory LinePoint.fromJson(Map<String,dynamic> j) => LinePoint(latitude:j['lat'],longitude:j['lon']);
}

class LayerTrack {
  final String id;
  String name;
  final DateTime createdAt;
  Color color;
  final List<LayerTrackPoint> points;
  bool isRecording;

  LayerTrack({String? id, String? name, DateTime? createdAt, this.color=const Color(0xFF00C853), List<LayerTrackPoint>? points, this.isRecording=false})
      : id=id??_uuid.v4(), createdAt=createdAt??DateTime.now(), points=points??[], name='' {
    this.name = name ?? defaultName('track', this.createdAt);
  }

  double get totalDistance {
    if (points.length < 2) return 0;
    double d = 0;
    for (int i = 1; i < points.length; i++) {
      d += _haversineRaw(points[i-1].latitude, points[i-1].longitude, points[i].latitude, points[i].longitude);
    }
    return d;
  }

  String get distanceLabel { final d=totalDistance; return d>=1000?'${(d/1000).toStringAsFixed(2)} km':'${d.toStringAsFixed(0)} m'; }

  Map<String,dynamic> toJson() => {'id':id,'name':name,'createdAt':createdAt.toIso8601String(),'color':color.value,'points':points.map((p)=>p.toJson()).toList(),'isRecording':isRecording};
  factory LayerTrack.fromJson(Map<String,dynamic> j) => LayerTrack(id:j['id'],name:j['name'],createdAt:DateTime.parse(j['createdAt']),color:Color(j['color']??0xFF00C853),points:(j['points'] as List).map((p)=>LayerTrackPoint.fromJson(p)).toList(),isRecording:j['isRecording']??false);
}

class LayerPin {
  final String id;
  String name;
  final DateTime createdAt;
  Color color;
  final double latitude;
  final double longitude;
  final double altitude;

  LayerPin({String? id, String? name, DateTime? createdAt, this.color=const Color(0xFFFF5252), required this.latitude, required this.longitude, this.altitude=0})
      : id=id??_uuid.v4(), createdAt=createdAt??DateTime.now(), name='' {
    this.name = name ?? defaultName('pin', this.createdAt);
  }

  Map<String,dynamic> toJson() => {'id':id,'name':name,'createdAt':createdAt.toIso8601String(),'color':color.value,'lat':latitude,'lon':longitude,'alt':altitude};
  factory LayerPin.fromJson(Map<String,dynamic> j) => LayerPin(id:j['id'],name:j['name'],createdAt:DateTime.parse(j['createdAt']),color:Color(j['color']??0xFFFF5252),latitude:j['lat'],longitude:j['lon'],altitude:j['alt']??0);
}

class LayerLine {
  final String id;
  String name;
  final DateTime createdAt;
  Color color;
  final List<LinePoint> points;

  LayerLine({String? id, String? name, DateTime? createdAt, this.color=const Color(0xFF2196F3), List<LinePoint>? points})
      : id=id??_uuid.v4(), createdAt=createdAt??DateTime.now(), points=points??[], name='' {
    this.name = name ?? defaultName('line', this.createdAt);
  }

  double get totalDistance => _calcDistance(points);
  String get distanceLabel { final d=totalDistance; return d>=1000?'${(d/1000).toStringAsFixed(2)} km':'${d.toStringAsFixed(0)} m'; }

  Map<String,dynamic> toJson() => {'id':id,'name':name,'createdAt':createdAt.toIso8601String(),'color':color.value,'points':points.map((p)=>p.toJson()).toList()};
  factory LayerLine.fromJson(Map<String,dynamic> j) => LayerLine(id:j['id'],name:j['name'],createdAt:DateTime.parse(j['createdAt']),color:Color(j['color']??0xFF2196F3),points:(j['points'] as List).map((p)=>LinePoint.fromJson(p)).toList());
}

class LayerPolygon {
  final String id;
  String name;
  final DateTime createdAt;
  Color color;
  final List<LinePoint> points;

  LayerPolygon({String? id, String? name, DateTime? createdAt, this.color=const Color(0xFF9C27B0), List<LinePoint>? points})
      : id=id??_uuid.v4(), createdAt=createdAt??DateTime.now(), points=points??[], name='' {
    this.name = name ?? defaultName('poly', this.createdAt);
  }

  double get area => _calcArea(points);
  String get areaLabel { final a=area; return a>=10000?'${(a/10000).toStringAsFixed(4)} ha':'${a.toStringAsFixed(2)} m²'; }

  Map<String,dynamic> toJson() => {'id':id,'name':name,'createdAt':createdAt.toIso8601String(),'color':color.value,'points':points.map((p)=>p.toJson()).toList()};
  factory LayerPolygon.fromJson(Map<String,dynamic> j) => LayerPolygon(id:j['id'],name:j['name'],createdAt:DateTime.parse(j['createdAt']),color:Color(j['color']??0xFF9C27B0),points:(j['points'] as List).map((p)=>LinePoint.fromJson(p)).toList());
}

class ImportedFile {
  final String id;
  String name;
  final DateTime importedAt;
  final String filePath;
  final List<LayerPin> pins;
  final List<LayerTrack> tracks;
  final List<LayerLine> lines;
  final List<LayerPolygon> polygons;

  ImportedFile({String? id, required this.name, DateTime? importedAt, required this.filePath, List<LayerPin>? pins, List<LayerTrack>? tracks, List<LayerLine>? lines, List<LayerPolygon>? polygons})
      : id=id??_uuid.v4(), importedAt=importedAt??DateTime.now(), pins=pins??[], tracks=tracks??[], lines=lines??[], polygons=polygons??[];

  bool get isEmpty => pins.isEmpty && tracks.isEmpty && lines.isEmpty && polygons.isEmpty;

  Map<String,dynamic> toJson() => {'id':id,'name':name,'importedAt':importedAt.toIso8601String(),'filePath':filePath,'pins':pins.map((p)=>p.toJson()).toList(),'tracks':tracks.map((t)=>t.toJson()).toList(),'lines':lines.map((l)=>l.toJson()).toList(),'polygons':polygons.map((p)=>p.toJson()).toList()};
  factory ImportedFile.fromJson(Map<String,dynamic> j) => ImportedFile(id:j['id'],name:j['name'],importedAt:DateTime.parse(j['importedAt']),filePath:j['filePath']??'',pins:(j['pins'] as List? ?? []).map((p)=>LayerPin.fromJson(p)).toList(),tracks:(j['tracks'] as List? ?? []).map((t)=>LayerTrack.fromJson(t)).toList(),lines:(j['lines'] as List? ?? []).map((l)=>LayerLine.fromJson(l)).toList(),polygons:(j['polygons'] as List? ?? []).map((p)=>LayerPolygon.fromJson(p)).toList());
}

class FieldLayer {
  final String id;
  String name;
  final DateTime createdAt;
  final double latitude;
  final double longitude;
  final double radius;
  Color color;
  final List<LayerTrack> tracks;
  final List<LayerPin> pins;
  final List<LayerLine> lines;
  final List<LayerPolygon> polygons;
  final List<ImportedFile> imports;

  FieldLayer({String? id, required this.name, DateTime? createdAt, required this.latitude, required this.longitude, required this.radius, this.color=const Color(0xFF00C853), List<LayerTrack>? tracks, List<LayerPin>? pins, List<LayerLine>? lines, List<LayerPolygon>? polygons, List<ImportedFile>? imports})
      : id=id??_uuid.v4(), createdAt=createdAt??DateTime.now(), tracks=tracks??[], pins=pins??[], lines=lines??[], polygons=polygons??[], imports=imports??[];

  bool get isEmpty => tracks.isEmpty && pins.isEmpty && lines.isEmpty && polygons.isEmpty && imports.isEmpty;
  bool get isOriginalEmpty => tracks.isEmpty && pins.isEmpty && lines.isEmpty && polygons.isEmpty;
  bool get isImportEmpty => imports.isEmpty;

  bool containsPoint(double lat, double lon) {
    final d = _haversineRaw(latitude, longitude, lat, lon);
    return d <= radius;
  }

  Map<String,dynamic> toJson() => {'id':id,'name':name,'createdAt':createdAt.toIso8601String(),'lat':latitude,'lon':longitude,'radius':radius,'color':color.value,'tracks':tracks.map((t)=>t.toJson()).toList(),'pins':pins.map((p)=>p.toJson()).toList(),'lines':lines.map((l)=>l.toJson()).toList(),'polygons':polygons.map((p)=>p.toJson()).toList(),'imports':imports.map((i)=>i.toJson()).toList()};
  factory FieldLayer.fromJson(Map<String,dynamic> j) => FieldLayer(id:j['id'],name:j['name'],createdAt:DateTime.parse(j['createdAt']),latitude:j['lat'],longitude:j['lon'],radius:j['radius'],color:Color(j['color']??0xFF00C853),tracks:(j['tracks'] as List? ?? []).map((t)=>LayerTrack.fromJson(t)).toList(),pins:(j['pins'] as List? ?? []).map((p)=>LayerPin.fromJson(p)).toList(),lines:(j['lines'] as List? ?? []).map((l)=>LayerLine.fromJson(l)).toList(),polygons:(j['polygons'] as List? ?? []).map((p)=>LayerPolygon.fromJson(p)).toList(),imports:(j['imports'] as List? ?? []).map((i)=>ImportedFile.fromJson(i)).toList());
}

double _haversineRaw(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final a1 = lat1*math.pi/180, a2 = lat2*math.pi/180;
  final dLat = (lat2-lat1)*math.pi/180, dLon = (lon2-lon1)*math.pi/180;
  final a = math.sin(dLat/2)*math.sin(dLat/2) + math.cos(a1)*math.cos(a2)*math.sin(dLon/2)*math.sin(dLon/2);
  return R*2*math.atan2(math.sqrt(a),math.sqrt(1-a));
}

double _calcDistance(List<LinePoint> points) {
  if (points.length < 2) return 0;
  double d = 0;
  for (int i=1;i<points.length;i++) d+=_haversineRaw(points[i-1].latitude,points[i-1].longitude,points[i].latitude,points[i].longitude);
  return d;
}

double _calcArea(List<LinePoint> points) {
  if (points.length < 3) return 0;
  const R = 6371000.0;
  double area = 0;
  final n = points.length;
  for (int i=0;i<n;i++) {
    final j=(i+1)%n;
    final xi=points[i].longitude*math.pi/180, yi=points[i].latitude*math.pi/180;
    final xj=points[j].longitude*math.pi/180, yj=points[j].latitude*math.pi/180;
    area += (xj-xi)*(2+math.sin(yi)+math.sin(yj));
  }
  return (area*R*R/2).abs();
}
