import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gps_provider.dart';
import '../providers/map_provider.dart';
import '../providers/track_provider.dart';
import '../models/gps_data.dart';
import '../models/map_models.dart';
import '../theme/app_theme.dart';

class MapCanvas extends StatefulWidget {
  final VoidCallback? onTap;
  final void Function(double lat, double lon)? onLongPress;

  const MapCanvas({super.key, this.onTap, this.onLongPress});

  @override
  State<MapCanvas> createState() => _MapCanvasState();

  static _MapCanvasState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MapCanvasState>();
}

class _MapCanvasState extends State<MapCanvas> {
  double _scale = 1.0;
  double _baseScale = 1.0;
  double _offsetX = 0;
  double _offsetY = 0;
  double _startOffX = 0;
  double _startOffY = 0;
  Offset? _focalStart;

  void zoomIn() => setState(() => _scale = (_scale * 1.3).clamp(0.1, 100.0));
  void zoomOut() => setState(() => _scale = (_scale / 1.3).clamp(0.1, 100.0));
  void centerToGps() => setState(() { _offsetX = 0; _offsetY = 0; });

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GpsProvider>();
    final map = context.watch<MapProvider>();
    final track = context.watch<TrackProvider>();
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _baseScale = _scale;
        _startOffX = _offsetX;
        _startOffY = _offsetY;
        _focalStart = d.localFocalPoint;
      },
      onScaleUpdate: (d) {
        setState(() {
          _scale = (_baseScale * d.scale).clamp(0.1, 100.0);
          if (_focalStart != null) {
            _offsetX = _startOffX + d.localFocalPoint.dx - _focalStart!.dx;
            _offsetY = _startOffY + d.localFocalPoint.dy - _focalStart!.dy;
          }
        });
      },
      onTap: widget.onTap,
      onLongPressStart: (d) {
        if (widget.onLongPress != null && gps.current != null) {
          final latLon = _pixelToLatLon(
            d.localPosition.dx, d.localPosition.dy,
            gps.current!, size.width, size.height,
          );
          widget.onLongPress!(latLon.latitude, latLon.longitude);
        }
      },
      child: CustomPaint(
        size: Size(size.width, size.height),
        painter: _MapPainter(
          gpsData: gps.current,
          pins: map.pins,
          circles: map.circles,
          trackPoints: track.currentPoints,
          savedTracks: track.savedTracks,
          scale: _scale,
          offsetX: _offsetX,
          offsetY: _offsetY,
          screenW: size.width,
          screenH: size.height,
        ),
      ),
    );
  }

  GpsData _pixelToLatLon(double px, double py, GpsData center, double sw, double sh) {
    const base = 10.0;
    const mPerDeg = 111319.9;
    final dx = ((px - sw / 2 - _offsetX) / _scale) * base;
    final dy = ((py - sh / 2 - _offsetY) / _scale) * base;
    final lat = center.latitude - dy / mPerDeg;
    final lon = center.longitude + dx / (mPerDeg * math.cos(center.latitude * math.pi / 180));
    return GpsData(latitude: lat, longitude: lon, timestamp: DateTime.now());
  }
}

class _MapPainter extends CustomPainter {
  final GpsData? gpsData;
  final List<MapPin> pins;
  final List<RadiusCircle> circles;
  final List<TrackPoint> trackPoints;
  final List<MapTrack> savedTracks;
  final double scale;
  final double offsetX;
  final double offsetY;
  final double screenW;
  final double screenH;

  static const double _base = 10.0; // meter per pixel at scale 1.0
  static const double _mPerDeg = 111319.9;

  _MapPainter({
    required this.gpsData,
    required this.pins,
    required this.circles,
    required this.trackPoints,
    required this.savedTracks,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.screenW,
    required this.screenH,
  });

  Offset _toScreen(double lat, double lon, GpsData center) {
    final dLat = lat - center.latitude;
    final dLon = lon - center.longitude;
    final dx = dLon * _mPerDeg * math.cos(center.latitude * math.pi / 180);
    final dy = -dLat * _mPerDeg;
    return Offset(
      screenW / 2 + (dx / _base) * scale + offsetX,
      screenH / 2 + (dy / _base) * scale + offsetY,
    );
  }

  double _metersToPixels(double meters) => (meters / _base) * scale;

  @override
  void paint(Canvas canvas, Size size) {
    // Background putih
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);

    // Grid
    _drawGrid(canvas, size);

    if (gpsData == null) return;

    // Radius circles
    _drawCircles(canvas);

    // Saved tracks
    for (final t in savedTracks) {
      _drawTrackPoints(canvas, t.points, AppColors.trackLine.withOpacity(0.6));
    }

    // Active track
    if (trackPoints.isNotEmpty) {
      _drawTrackPoints(canvas, trackPoints, AppColors.trackLine);
    }

    // Pins
    _drawPins(canvas);

    // GPS position dot
    final center = Offset(screenW / 2 + offsetX, screenH / 2 + offsetY);
    _drawGpsMarker(canvas, center);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.5;

    // Grid spacing in pixels
    final spacing = _metersToPixels(100); // 100m grid
    if (spacing < 20) return; // terlalu kecil

    final cx = screenW / 2 + offsetX;
    final cy = screenH / 2 + offsetY;

    // Vertical lines
    double x = cx % spacing;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      x += spacing;
    }

    // Horizontal lines
    double y = cy % spacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += spacing;
    }
  }

  void _drawCircles(Canvas canvas) {
    for (final circle in circles) {
      final center = _toScreen(circle.latitude, circle.longitude, gpsData!);
      for (final r in circle.radii) {
        final px = _metersToPixels(r);
        canvas.drawCircle(center, px,
            Paint()..color = circle.color.withOpacity(0.15)..style = PaintingStyle.fill);
        canvas.drawCircle(center, px,
            Paint()..color = circle.color..strokeWidth = 1.5..style = PaintingStyle.stroke);
      }
      // Label
      if (circle.label.isNotEmpty) {
        _drawText(canvas, circle.label, center + const Offset(0, -10), 11, circle.color);
      }
    }
  }

  void _drawTrackPoints(Canvas canvas, List<TrackPoint> points, Color color) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pt = _toScreen(points[i].latitude, points[i].longitude, gpsData!);
      if (i == 0) path.moveTo(pt.dx, pt.dy);
      else path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawPins(Canvas canvas) {
    for (final pin in pins) {
      final pos = _toScreen(pin.latitude, pin.longitude, gpsData!);
      // Pin shape
      final paint = Paint()..color = pin.color;
      canvas.drawCircle(pos, 8, paint);
      canvas.drawCircle(pos, 8, Paint()..color = Colors.white..strokeWidth = 1.5..style = PaintingStyle.stroke);
      // Label
      if (pin.label.isNotEmpty) {
        _drawText(canvas, pin.label, pos + const Offset(0, -16), 10, Colors.white);
      }
    }
  }

  void _drawGpsMarker(Canvas canvas, Offset pos) {
    // Accuracy circle
    if (gpsData!.accuracy > 0) {
      final r = _metersToPixels(gpsData!.accuracy);
      canvas.drawCircle(pos, r,
          Paint()..color = AppColors.primary.withOpacity(0.1)..style = PaintingStyle.fill);
      canvas.drawCircle(pos, r,
          Paint()..color = AppColors.primary.withOpacity(0.4)..strokeWidth = 1..style = PaintingStyle.stroke);
    }
    // Dot
    canvas.drawCircle(pos, 8, Paint()..color = AppColors.primary);
    canvas.drawCircle(pos, 8, Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke);
    canvas.drawCircle(pos, 3, Paint()..color = Colors.white);
  }

  void _drawText(Canvas canvas, String text, Offset pos, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pos.dx - tp.width / 2 - 3, pos.dy - tp.height / 2 - 2, tp.width + 6, tp.height + 4),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}
