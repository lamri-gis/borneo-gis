import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gps_provider.dart';
import '../providers/map_provider.dart';
import '../providers/track_provider.dart';
import '../providers/layer_provider.dart';
import '../models/gps_data.dart';
import '../models/map_models.dart';
import '../models/layer_models.dart';
import '../theme/app_theme.dart';

enum DrawingMode { none, line, polygon }

class MapCanvasController {
  _MapCanvasState? _state;
  void zoomIn() => _state?.zoomIn();
  void zoomOut() => _state?.zoomOut();
  void centerToGps() => _state?.centerToGps();
  void addDrawPoint() => _state?.addDrawPoint();
  void undoDrawPoint() => _state?.undoDrawPoint();
  void finishDrawing() => _state?.finishDrawing();
  void setDrawingMode(DrawingMode mode) => _state?.setDrawingMode(mode);
  DrawingMode get drawingMode => _state?._drawingMode ?? DrawingMode.none;
  double get gridInterval => _state?._currentGridInterval ?? 100;
}

class MapCanvas extends StatefulWidget {
  final VoidCallback? onTap;
  final void Function(double lat, double lon)? onLongPress;
  final MapCanvasController? controller;

  const MapCanvas({super.key, this.onTap, this.onLongPress, this.controller});

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> {
  double _scale = 1.0;
  double _offsetX = 0;
  double _offsetY = 0;
  double _startOffX = 0;
  double _startOffY = 0;
  Offset? _focalStart;
  bool _autocentered = false;
  double _currentGridInterval = 100;
  DrawingMode _drawingMode = DrawingMode.none;
  final List<LinePoint> _drawPoints = [];

  static const List<double> _gridSteps = [1, 10, 100, 1000];

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(MapCanvas old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    super.dispose();
  }

  void zoomIn() => setState(() => _scale = (_scale * 1.585).clamp(0.1, 2000.0));
  void zoomOut() => setState(() => _scale = (_scale / 1.585).clamp(0.1, 2000.0));

  void setDrawingMode(DrawingMode mode) {
    setState(() {
      _drawingMode = mode;
      _drawPoints.clear();
    });
  }

  void addDrawPoint() {
    if (_drawingMode == DrawingMode.none) return;
    final gps = context.read<GpsProvider>();
    final size = MediaQuery.of(context).size;
    // Ambil koordinat dari tengah layar (posisi crosshair)
    final latLon = _pixelToLatLon(
      size.width / 2, size.height / 2,
      gps.firstFix ?? gps.current!,
      size.width, size.height,
    );
    setState(() => _drawPoints.add(LinePoint(latitude: latLon.latitude, longitude: latLon.longitude)));
  }

  void undoDrawPoint() {
    if (_drawPoints.isEmpty) return;
    setState(() => _drawPoints.removeLast());
  }

  void finishDrawing() {
    if (_drawPoints.length < 2) return;
    final layerProvider = context.read<LayerProvider>();
    final layerId = layerProvider.activeLayer?.id;
    if (layerId == null) return;
    final now = DateTime.now();
    if (_drawingMode == DrawingMode.line) {
      layerProvider.addLine(layerId, LayerLine(points: List.from(_drawPoints)));
    } else if (_drawingMode == DrawingMode.polygon && _drawPoints.length >= 3) {
      layerProvider.addPolygon(layerId, LayerPolygon(points: List.from(_drawPoints)));
    }
    setState(() {
      _drawingMode = DrawingMode.none;
      _drawPoints.clear();
    });
  }

  void centerToGps() {
    final gps = context.read<GpsProvider>();
    if (gps.current == null || gps.firstFix == null) {
      setState(() { _offsetX = 0; _offsetY = 0; });
      return;
    }
    final current = gps.current!;
    final first = gps.firstFix!;
    const base = 10.0;
    const mPerDeg = 111319.9;
    final dLat = current.latitude - first.latitude;
    final dLon = current.longitude - first.longitude;
    final dx = dLon * mPerDeg * math.cos(first.latitude * math.pi / 180);
    final dy = -dLat * mPerDeg;
    setState(() {
      _offsetX = -(dx / base) * _scale;
      _offsetY = -(dy / base) * _scale;
    });
  }

  double _calcGridInterval() {
    const base = 10.0;
    for (final step in _gridSteps) {
      final px = (step / base) * _scale;
      if (px >= 40) return step;
    }
    return _gridSteps.last;
  }

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GpsProvider>();
    final map = context.watch<MapProvider>();
    final track = context.watch<TrackProvider>();
    final layer = context.watch<LayerProvider>();
    final size = MediaQuery.of(context).size;

    if (gps.current != null && !_autocentered) {
      _autocentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => centerToGps());
    }

    _currentGridInterval = _calcGridInterval();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _startOffX = _offsetX;
        _startOffY = _offsetY;
        _focalStart = d.localFocalPoint;
      },
      onScaleUpdate: (d) {
        setState(() {
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
            gps.firstFix ?? gps.current!, size.width, size.height,
          );
          widget.onLongPress!(latLon.latitude, latLon.longitude);
        }
      },
      child: CustomPaint(
        size: Size(size.width, size.height),
        painter: _MapPainter(
          gpsData: gps.current,
          firstFix: gps.firstFix,
          pins: map.pins,
          circles: map.circles,
          trackPoints: track.currentPoints,
          savedTracks: track.savedTracks,
          activeLayer: layer.activeLayer,
          recordingTrack: layer.recordingTrack,
          drawPoints: _drawPoints,
          drawingMode: _drawingMode,
          scale: _scale,
          offsetX: _offsetX,
          offsetY: _offsetY,
          screenW: size.width,
          screenH: size.height,
          gridInterval: _currentGridInterval,
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
  final GpsData? firstFix;
  final List<MapPin> pins;
  final List<RadiusCircle> circles;
  final List<OldTrackPoint> trackPoints;
  final List<MapTrack> savedTracks;
  final FieldLayer? activeLayer;
  final LayerTrack? recordingTrack;
  final List<LinePoint> drawPoints;
  final DrawingMode drawingMode;
  final double scale;
  final double offsetX;
  final double offsetY;
  final double screenW;
  final double screenH;
  final double gridInterval;

  static const double _base = 10.0;
  static const double _mPerDeg = 111319.9;

  _MapPainter({
    required this.gpsData,
    required this.firstFix,
    required this.pins,
    required this.circles,
    required this.trackPoints,
    required this.savedTracks,
    required this.activeLayer,
    required this.recordingTrack,
    required this.drawPoints,
    required this.drawingMode,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.screenW,
    required this.screenH,
    required this.gridInterval,
  });

  GpsData get _ref => firstFix ?? gpsData!;

  Offset _toScreen(double lat, double lon) {
    final dLat = lat - _ref.latitude;
    final dLon = lon - _ref.longitude;
    final dx = dLon * _mPerDeg * math.cos(_ref.latitude * math.pi / 180);
    final dy = -dLat * _mPerDeg;
    return Offset(
      screenW / 2 + (dx / _base) * scale + offsetX,
      screenH / 2 + (dy / _base) * scale + offsetY,
    );
  }

  double _metersToPixels(double meters) => (meters / _base) * scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = AppColors.mapBackground);
    _drawGrid(canvas, size);
    if (gpsData == null) return;

    // Layer radius aktif
    if (activeLayer != null) {
      _drawRadius(canvas, activeLayer!);
      _drawLayerLines(canvas, activeLayer!);
      _drawLayerPolygons(canvas, activeLayer!);
      _drawLayerTracks(canvas, activeLayer!);
      _drawLayerPins(canvas, activeLayer!);
      // Import
      for (final imp in activeLayer!.imports) {
        _drawImportLines(canvas, imp);
        _drawImportPolygons(canvas, imp);
        _drawImportTracks(canvas, imp);
        _drawImportPins(canvas, imp);
      }
    }

    // Legacy pins dan circles
    _drawCircles(canvas);
    for (final t in savedTracks) {
      _drawOldTrackPoints(canvas, t.points, AppColors.trackLine.withOpacity(0.6));
    }
    if (trackPoints.isNotEmpty) _drawOldTrackPoints(canvas, trackPoints, AppColors.trackLine);
    _drawPins(canvas);

    // Recording track dari layer
    if (recordingTrack != null && recordingTrack!.points.isNotEmpty) {
      _drawLayerTrackPoints(canvas, recordingTrack!.points, AppColors.error);
    }

    // Drawing mode preview
    if (drawPoints.isNotEmpty) _drawPreview(canvas);

    final gpsScreen = _toScreen(gpsData!.latitude, gpsData!.longitude);
    _drawGpsMarker(canvas, gpsScreen);
    _drawGridLabel(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.gridLine..strokeWidth = 0.5;
    final spacing = _metersToPixels(gridInterval);
    if (spacing < 20) return;
    final cx = screenW / 2 + offsetX;
    final cy = screenH / 2 + offsetY;
    double x = cx % spacing;
    while (x < size.width) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint); x += spacing; }
    double y = cy % spacing;
    while (y < size.height) { canvas.drawLine(Offset(0, y), Offset(size.width, y), paint); y += spacing; }
  }

  void _drawGridLabel(Canvas canvas, Size size) {
    final meters = gridInterval;
    final label = '⊞ ${meters >= 1000 ? '${(meters/1000).toStringAsFixed(0)} km' : '${meters.toInt()} m'}';
    final tp = TextPainter(text: TextSpan(text: label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)), textDirection: TextDirection.ltr)..layout();
    const p = 8.0;
    final x = p; final y = size.height - tp.height - p;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x-4, y-3, tp.width+8, tp.height+6), const Radius.circular(4)), Paint()..color = Colors.black.withOpacity(0.4));
    tp.paint(canvas, Offset(x, y));
  }

  void _drawRadius(Canvas canvas, FieldLayer layer) {
    final center = _toScreen(layer.latitude, layer.longitude);
    final px = _metersToPixels(layer.radius);
    canvas.drawCircle(center, px, Paint()..color = layer.color.withOpacity(0.08)..style = PaintingStyle.fill);
    canvas.drawCircle(center, px, Paint()..color = layer.color..strokeWidth = 1.5..style = PaintingStyle.stroke);
    _drawText(canvas, layer.name, center + Offset(0, -px - 10), 11, layer.color);
  }

  void _drawLayerLines(Canvas canvas, FieldLayer layer) {
    for (final line in layer.lines) {
      if (line.points.length < 2) continue;
      final path = Path();
      for (int i = 0; i < line.points.length; i++) {
        final pt = _toScreen(line.points[i].latitude, line.points[i].longitude);
        if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, Paint()..color = line.color..strokeWidth = 2..style = PaintingStyle.stroke);
    }
  }

  void _drawLayerPolygons(Canvas canvas, FieldLayer layer) {
    for (final poly in layer.polygons) {
      if (poly.points.length < 3) continue;
      final path = Path();
      for (int i = 0; i < poly.points.length; i++) {
        final pt = _toScreen(poly.points[i].latitude, poly.points[i].longitude);
        if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = poly.color.withOpacity(0.2)..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = poly.color..strokeWidth = 2..style = PaintingStyle.stroke);
    }
  }

  void _drawLayerTracks(Canvas canvas, FieldLayer layer) {
    for (final track in layer.tracks) {
      _drawLayerTrackPoints(canvas, track.points, track.color);
    }
  }

  void _drawLayerTrackPoints(Canvas canvas, List<LayerTrackPoint> points, Color color) {
    if (points.length < 2) return;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pt = _toScreen(points[i].latitude, points[i].longitude);
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
  }

  void _drawLayerPins(Canvas canvas, FieldLayer layer) {
    for (final pin in layer.pins) {
      final pos = _toScreen(pin.latitude, pin.longitude);
      canvas.drawCircle(pos, 8, Paint()..color = pin.color);
      canvas.drawCircle(pos, 8, Paint()..color = Colors.white..strokeWidth = 1.5..style = PaintingStyle.stroke);
      if (pin.name.isNotEmpty) _drawText(canvas, pin.name, pos + const Offset(0, -16), 10, Colors.white);
    }
  }

  void _drawImportLines(Canvas canvas, ImportedFile imp) {
    for (final line in imp.lines) {
      if (line.points.length < 2) continue;
      final path = Path();
      for (int i = 0; i < line.points.length; i++) {
        final pt = _toScreen(line.points[i].latitude, line.points[i].longitude);
        if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, Paint()..color = line.color.withOpacity(0.7)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }
  }

  void _drawImportPolygons(Canvas canvas, ImportedFile imp) {
    for (final poly in imp.polygons) {
      if (poly.points.length < 3) continue;
      final path = Path();
      for (int i = 0; i < poly.points.length; i++) {
        final pt = _toScreen(poly.points[i].latitude, poly.points[i].longitude);
        if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = poly.color.withOpacity(0.15)..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = poly.color.withOpacity(0.7)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }
  }

  void _drawImportTracks(Canvas canvas, ImportedFile imp) {
    for (final track in imp.tracks) {
      _drawLayerTrackPoints(canvas, track.points, track.color.withOpacity(0.7));
    }
  }

  void _drawImportPins(Canvas canvas, ImportedFile imp) {
    for (final pin in imp.pins) {
      final pos = _toScreen(pin.latitude, pin.longitude);
      canvas.drawCircle(pos, 6, Paint()..color = pin.color.withOpacity(0.8));
      canvas.drawCircle(pos, 6, Paint()..color = Colors.white..strokeWidth = 1..style = PaintingStyle.stroke);
    }
  }

  void _drawPreview(Canvas canvas) {
    if (drawPoints.isEmpty) return;
    final paint = Paint()..color = AppColors.accent..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final path = Path();
    for (int i = 0; i < drawPoints.length; i++) {
      final pt = _toScreen(drawPoints[i].latitude, drawPoints[i].longitude);
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      canvas.drawCircle(pt, 5, Paint()..color = AppColors.accent);
    }
    if (drawingMode == DrawingMode.polygon && drawPoints.length >= 3) {
      final first = _toScreen(drawPoints.first.latitude, drawPoints.first.longitude);
      path.lineTo(first.dx, first.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawCircles(Canvas canvas) {
    for (final circle in circles) {
      final center = _toScreen(circle.latitude, circle.longitude);
      for (final r in circle.radii) {
        final px = _metersToPixels(r);
        canvas.drawCircle(center, px, Paint()..color = circle.color.withOpacity(0.15)..style = PaintingStyle.fill);
        canvas.drawCircle(center, px, Paint()..color = circle.color..strokeWidth = 1.5..style = PaintingStyle.stroke);
      }
      if (circle.label.isNotEmpty) _drawText(canvas, circle.label, center + const Offset(0, -10), 11, circle.color);
    }
  }

  void _drawOldTrackPoints(Canvas canvas, List<OldTrackPoint> points, Color color) {
    if (points.length < 2) return;
    final paint = Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pt = _toScreen(points[i].latitude, points[i].longitude);
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawPins(Canvas canvas) {
    for (final pin in pins) {
      final pos = _toScreen(pin.latitude, pin.longitude);
      canvas.drawCircle(pos, 8, Paint()..color = pin.color);
      canvas.drawCircle(pos, 8, Paint()..color = Colors.white..strokeWidth = 1.5..style = PaintingStyle.stroke);
      if (pin.label.isNotEmpty) _drawText(canvas, pin.label, pos + const Offset(0, -16), 10, Colors.white);
    }
  }

  void _drawGpsMarker(Canvas canvas, Offset pos) {
    if (gpsData!.accuracy > 0) {
      final r = _metersToPixels(gpsData!.accuracy);
      canvas.drawCircle(pos, r, Paint()..color = AppColors.primary.withOpacity(0.1)..style = PaintingStyle.fill);
      canvas.drawCircle(pos, r, Paint()..color = AppColors.primary.withOpacity(0.4)..strokeWidth = 1..style = PaintingStyle.stroke);
    }
    canvas.drawCircle(pos, 8, Paint()..color = AppColors.primary);
    canvas.drawCircle(pos, 8, Paint()..color = Colors.white..strokeWidth = 2..style = PaintingStyle.stroke);
    canvas.drawCircle(pos, 3, Paint()..color = Colors.white);
  }

  void _drawText(Canvas canvas, String text, Offset pos, double size, Color color) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx-tp.width/2-3, pos.dy-tp.height/2-2, tp.width+6, tp.height+4), const Radius.circular(3)), Paint()..color = Colors.black.withOpacity(0.5));
    tp.paint(canvas, Offset(pos.dx-tp.width/2, pos.dy-tp.height/2));
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}
