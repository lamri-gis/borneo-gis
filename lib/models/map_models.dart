import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

export 'layer_models.dart';

const _uuid = Uuid();

enum OverlayType { gpx, kml }

class MapOverlay {
  final String id;
  String name;
  final String filePath;
  final OverlayType type;
  bool visible;
  MapOverlay({String? id, required this.name, required this.filePath, required this.type, this.visible=true}) : id=id??_uuid.v4();
}

class MapPin {
  final String id;
  String label;
  final double latitude;
  final double longitude;
  Color color;
  final DateTime createdAt;

  MapPin({String? id, required this.latitude, required this.longitude, this.label='', this.color=const Color(0xFFFF5252), DateTime? createdAt})
      : id=id??_uuid.v4(), createdAt=createdAt??DateTime.now();

  Map<String,dynamic> toJson() => {'id':id,'lat':latitude,'lon':longitude,'label':label,'color':color.value,'createdAt':createdAt.toIso8601String()};
  factory MapPin.fromJson(Map<String,dynamic> j) => MapPin(id:j['id'],latitude:j['lat'],longitude:j['lon'],label:j['label']??'',color:Color(j['color']??0xFFFF5252),createdAt:DateTime.tryParse(j['createdAt']??'')??DateTime.now());
}

class RadiusCircle {
  final String id;
  final double latitude;
  final double longitude;
  final List<double> radii;
  String label;
  Color color;
  RadiusCircle({String? id, required this.latitude, required this.longitude, required this.radii, this.label='', this.color=const Color(0xFF00C853)}) : id=id??_uuid.v4();

  Map<String,dynamic> toJson() => {'id':id,'lat':latitude,'lon':longitude,'radii':radii,'label':label,'color':color.value};
  factory RadiusCircle.fromJson(Map<String,dynamic> j) => RadiusCircle(id:j['id'],latitude:j['lat'],longitude:j['lon'],radii:List<double>.from(j['radii']),label:j['label']??'',color:Color(j['color']??0xFF00C853));
}

class OldTrackPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;
  const OldTrackPoint({required this.latitude, required this.longitude, this.altitude=0, required this.timestamp});
}

class MapTrack {
  final String id;
  String name;
  final List<OldTrackPoint> points;
  Color color;
  final DateTime createdAt;

  MapTrack({String? id, required this.name, List<OldTrackPoint>? points, this.color=const Color(0xFF00C853), DateTime? createdAt})
      : id=id??_uuid.v4(), points=points??[], createdAt=createdAt??DateTime.now();

  double get totalDistance {
    if (points.length < 2) return 0;
    double d = 0;
    for (int i=1;i<points.length;i++) d+=_dist(points[i-1],points[i]);
    return d;
  }

  static double _dist(OldTrackPoint a, OldTrackPoint b) {
    const R=6371000.0;
    final lat1=a.latitude*math.pi/180, lat2=b.latitude*math.pi/180;
    final dLat=(b.latitude-a.latitude)*math.pi/180, dLon=(b.longitude-a.longitude)*math.pi/180;
    final sa=math.sin(dLat/2)*math.sin(dLat/2)+math.cos(lat1)*math.cos(lat2)*math.sin(dLon/2)*math.sin(dLon/2);
    return R*2*math.atan2(math.sqrt(sa),math.sqrt(1-sa));
  }
}
