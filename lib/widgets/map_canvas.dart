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
  void centerToGps() => _state?.snapCrosshairToGps();
  void addDrawPoint() => _state?.addDrawPoint();
  void undoDrawPoint() => _state?.undoDrawPoint();
  void finishDrawing() => _state?.finishDrawing();
  void setDrawingMode(DrawingMode mode) => _state?.setDrawingMode(mode);
  DrawingMode get drawingMode => _state?._drawingMode ?? DrawingMode.none;
  double get gridInterval => _state?._currentGridInterval ?? 100;
  GpsData? getCrosshairCoord() => _state?._getCrosshairCoord();
}

class MapCanvas extends StatefulWidget {
  final void Function(double lat, double lon)? onLongPress;
  final void Function(String id, HighlightType type)? onDoubleTapObject;
  final void Function(String id, HighlightType type, String info)? onTapObject;
  final MapCanvasController? controller;

  const MapCanvas({super.key, this.onLongPress, this.onDoubleTapObject, this.onTapObject, this.controller});

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> with TickerProviderStateMixin {
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

  // Highlight animation
  late AnimationController _blinkController;
  late Animation<double> _blinkAnim;

  // Double tap detection
  int _tapCount = 0;
  DateTime? _firstTapTime;
  Offset? _firstTapPos;
  _HitResult? _pendingHit;

  static const List<double> _gridSteps = [1, 10, 100, 1000];

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _blinkAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_blinkController);
  }

  @override
  void didUpdateWidget(MapCanvas old) {
    super.didUpdateWidget(old);
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    _blinkController.dispose();
    widget.controller?._state = null;
    super.dispose();
  }

  void zoomIn() => setState(() => _scale = (_scale * 1.585).clamp(0.1, 2000.0));
  void zoomOut() => setState(() => _scale = (_scale / 1.585).clamp(0.1, 2000.0));

  void setDrawingMode(DrawingMode mode) {
    setState(() { _drawingMode = mode; _drawPoints.clear(); });
  }

  void addDrawPoint() {
    if (_drawingMode == DrawingMode.none) return;
    final coord = _getCrosshairCoord();
    if (coord == null) return;
    setState(() => _drawPoints.add(LinePoint(latitude: coord.latitude, longitude: coord.longitude)));
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
    if (_drawingMode == DrawingMode.line) {
      layerProvider.addLine(layerId, LayerLine(points: List.from(_drawPoints)));
    } else if (_drawingMode == DrawingMode.polygon && _drawPoints.length >= 3) {
      layerProvider.addPolygon(layerId, LayerPolygon(
        points: List.from(_drawPoints),
        areaUnit: layerProvider.pendingPolygonUnit,
      ));
    }
    setState(() { _drawingMode = DrawingMode.none; _drawPoints.clear(); });
  }

  // Fix presisi -- snap crosshair tepat ke posisi GPS
  void snapCrosshairToGps() {
    final gps = context.read<GpsProvider>();
    if (gps.current == null) return;

    final ref = gps.firstFix ?? gps.current!;
    final current = gps.current!;

    const base = 10.0;
    const mPerDeg = 111319.9;

    // Hitung berapa pixel GPS marker saat ini dari tengah layar
    final dLat = current.latitude - ref.latitude;
    final dLon = current.longitude - ref.longitude;
    final dx = dLon * mPerDeg * math.cos(ref.latitude * math.pi / 180);
    final dy = -dLat * mPerDeg;

    final gpsScreenX = (dx / base) * _scale;
    final gpsScreenY = (dy / base) * _scale;

    // Set offset agar GPS marker tepat di tengah layar (posisi crosshair)
    setState(() {
      _offsetX = -gpsScreenX;
      _offsetY = -gpsScreenY;
    });
  }

  // Ambil koordinat dari posisi crosshair (tengah layar)
  GpsData? _getCrosshairCoord() {
    final gps = context.read<GpsProvider>();
    final ref = gps.firstFix ?? gps.current;
    if (ref == null) return null;
    final size = MediaQuery.of(context).size;
    return _pixelToLatLon(size.width / 2, size.height / 2, ref, size.width, size.height);
  }

  double _calcGridInterval() {
    const base = 10.0;
    for (final step in _gridSteps) {
      final px = (step / base) * _scale;
      if (px >= 40) return step;
    }
    return _gridSteps.last;
  }

  // Hit test -- cari objek paling dekat dari tap
  _HitResult? _hitTest(Offset tapPos, FieldLayer layer, Size size) {
    const pinRadius = 24.0;
    const lineThreshold = 18.0;

    // Original -- Pin
    for (final pin in layer.pins) {
      final pos = _toScreen(pin.latitude, pin.longitude);
      if ((pos - tapPos).distance <= pinRadius) {
        return _HitResult(id: pin.id, type: HighlightType.pin, info: '${pin.latitude.toStringAsFixed(6)}°, ${pin.longitude.toStringAsFixed(6)}°', name: pin.name, timestamp: pin.createdAt, isImport: false);
      }
    }

    // Original -- Track
    for (final track in layer.tracks) {
      final pts = track.points.map((p) => _toScreen(p.latitude, p.longitude)).toList();
      if (_isNearPath(tapPos, pts, lineThreshold)) {
        return _HitResult(id: track.id, type: HighlightType.track, info: track.distanceLabel, name: track.name, timestamp: track.createdAt, isImport: false);
      }
    }

    // Original -- Line
    for (final line in layer.lines) {
      final pts = line.points.map((p) => _toScreen(p.latitude, p.longitude)).toList();
      if (_isNearPath(tapPos, pts, lineThreshold)) {
        return _HitResult(id: line.id, type: HighlightType.line, info: line.distanceLabel, name: line.name, timestamp: line.createdAt, isImport: false);
      }
    }

    // Original -- Poligon
    for (final poly in layer.polygons) {
      final pts = poly.points.map((p) => _toScreen(p.latitude, p.longitude)).toList();
      if (_isInsidePolygon(tapPos, pts) || _isNearPath(tapPos, [...pts, if (pts.isNotEmpty) pts.first], lineThreshold)) {
        return _HitResult(id: poly.id, type: HighlightType.polygon, info: poly.areaLabel, name: poly.name, timestamp: poly.createdAt, isImport: false);
      }
    }

    // Import -- Pin
    for (final imp in layer.imports) {
      for (final pin in imp.pins) {
        final pos = _toScreen(pin.latitude, pin.longitude);
        if ((pos - tapPos).distance <= pinRadius) {
          return _HitResult(id: pin.id, type: HighlightType.pin, info: '${pin.latitude.toStringAsFixed(6)}°, ${pin.longitude.toStringAsFixed(6)}°', name: pin.name, timestamp: pin.createdAt, isImport: true, importFileId: imp.id);
        }
      }

      // Import -- Track
      for (final track in imp.tracks) {
        final pts = track.points.map((p) => _toScreen(p.latitude, p.longitude)).toList();
        if (_isNearPath(tapPos, pts, lineThreshold)) {
          return _HitResult(id: track.id, type: HighlightType.track, info: track.distanceLabel, name: track.name, timestamp: track.createdAt, isImport: true, importFileId: imp.id);
        }
      }

      // Import -- Line
      for (final line in imp.lines) {
        final pts = line.points.map((p) => _toScreen(p.latitude, p.longitude)).toList();
        if (_isNearPath(tapPos, pts, lineThreshold)) {
          return _HitResult(id: line.id, type: HighlightType.line, info: line.distanceLabel, name: line.name, timestamp: line.createdAt, isImport: true, importFileId: imp.id);
        }
      }

      // Import -- Poligon
      for (final poly in imp.polygons) {
        final pts = poly.points.map((p) => _toScreen(p.latitude, p.longitude)).toList();
        if (_isInsidePolygon(tapPos, pts) || _isNearPath(tapPos, [...pts, if (pts.isNotEmpty) pts.first], lineThreshold)) {
          return _HitResult(id: poly.id, type: HighlightType.polygon, info: poly.areaLabel, name: poly.name, timestamp: poly.createdAt, isImport: true, importFileId: imp.id);
        }
      }
    }

    return null;
  }

  bool _isNearPath(Offset tap, List<Offset> pts, double threshold) {
    for (int i = 1; i < pts.length; i++) {
      if (_distToSegment(tap, pts[i-1], pts[i]) <= threshold) return true;
    }
    return false;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy + 0.0001);
    final clamped = t.clamp(0.0, 1.0);
    final closest = a + ab * clamped;
    return (p - closest).distance;
  }

  bool _isInsidePolygon(Offset p, List<Offset> pts) {
    if (pts.length < 3) return false;
    bool inside = false;
    int j = pts.length - 1;
    for (int i = 0; i < pts.length; i++) {
      if ((pts[i].dy > p.dy) != (pts[j].dy > p.dy) &&
          p.dx < (pts[j].dx - pts[i].dx) * (p.dy - pts[i].dy) / (pts[j].dy - pts[i].dy) + pts[i].dx) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  Offset _toScreen(double lat, double lon) {
    final gps = context.read<GpsProvider>();
    final ref = gps.firstFix ?? gps.current;
    if (ref == null) return Offset.zero;
    const base = 10.0;
    const mPerDeg = 111319.9;
    final dLat = lat - ref.latitude;
    final dLon = lon - ref.longitude;
    final dx = dLon * mPerDeg * math.cos(ref.latitude * math.pi / 180);
    final dy = -dLat * mPerDeg;
    final size = MediaQuery.of(context).size;
    return Offset(
      size.width / 2 + (dx / base) * _scale + _offsetX,
      size.height / 2 + (dy / base) * _scale + _offsetY,
    );
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
      WidgetsBinding.instance.addPostFrameCallback((_) => snapCrosshairToGps());
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
      onTapUp: (d) {
        if (layer.activeLayer == null) return;
        final hit = _hitTest(d.localPosition, layer.activeLayer!, size);

        final now = DateTime.now();
        final pos = d.localPosition;

        if (hit != null) {
          _tapCount++;
          if (_tapCount == 1) {
            _firstTapTime = now;
            _firstTapPos = pos;
            _pendingHit = hit;
            // Tunggu kemungkinan tap kedua
            Future.delayed(const Duration(milliseconds: 350), () {
              if (_tapCount == 1) {
                // Single tap
                widget.onTapObject?.call(hit.id, hit.type, hit.info);
                layer.setHighlight(hit.id, hit.type);
              }
              _tapCount = 0;
              _firstTapTime = null;
              _firstTapPos = null;
              _pendingHit = null;
            });
          } else if (_tapCount == 2) {
            // Double tap
            final isDouble = _firstTapTime != null &&
                now.difference(_firstTapTime!).inMilliseconds < 400 &&
                _firstTapPos != null &&
                (pos - _firstTapPos!).distance < 40;
            if (isDouble) {
              widget.onDoubleTapObject?.call(hit.id, hit.type);
            }
            _tapCount = 0;
            _firstTapTime = null;
            _firstTapPos = null;
            _pendingHit = null;
          }
        } else {
          _tapCount = 0;
          _firstTapTime = null;
          _firstTapPos = null;
          _pendingHit = null;
          layer.clearHighlight();
        }
      },
      onLongPressStart: (d) {
        if (widget.onLongPress != null) {
          final coord = _getCrosshairCoord();
          if (coord != null) widget.onLongPress!(coord.latitude, coord.longitude);
        }
      },
      child: AnimatedBuilder(
        animation: _blinkAnim,
        builder: (_, __) => CustomPaint(
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
            highlight: layer.highlight,
            blinkValue: _blinkAnim.value,
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

class _HitResult {
  final String id;
  final HighlightType type;
  final String info;
  final String name;
  final DateTime timestamp;
  final bool isImport;
  final String? importFileId;
  const _HitResult({required this.id, required this.type, required this.info, required this.name, required this.timestamp, required this.isImport, this.importFileId});
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
  final HighlightState? highlight;
  final double blinkValue;
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
    required this.gpsData, required this.firstFix, required this.pins,
    required this.circles, required this.trackPoints, required this.savedTracks,
    required this.activeLayer, required this.recordingTrack, required this.highlight,
    required this.blinkValue, required this.drawPoints, required this.drawingMode,
    required this.scale, required this.offsetX, required this.offsetY,
    required this.screenW, required this.screenH, required this.gridInterval,
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

  bool _isHighlighted(String id) => highlight?.id == id;
  double _highlightOpacity(String id) => _isHighlighted(id) ? blinkValue : 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = AppColors.mapBackground);
    _drawGrid(canvas, size);
    if (gpsData == null) return;

    if (activeLayer != null) {
      _drawRadius(canvas, activeLayer!);
      _drawLayerLines(canvas, activeLayer!);
      _drawLayerPolygons(canvas, activeLayer!);
      _drawLayerTracks(canvas, activeLayer!);
      _drawLayerPins(canvas, activeLayer!);
      for (final imp in activeLayer!.imports) {
        _drawImportLines(canvas, imp);
        _drawImportPolygons(canvas, imp);
        _drawImportTracks(canvas, imp);
        _drawImportPins(canvas, imp);
      }
    }

    _drawCircles(canvas);
    for (final t in savedTracks) _drawOldTrackPoints(canvas, t.points, AppColors.trackLine.withOpacity(0.6));
    if (trackPoints.isNotEmpty) _drawOldTrackPoints(canvas, trackPoints, AppColors.trackLine);
    _drawPins(canvas);

    if (recordingTrack != null && recordingTrack!.points.isNotEmpty) {
      _drawLayerTrackPoints(canvas, recordingTrack!.points, AppColors.error);
    }

    if (drawPoints.isNotEmpty) _drawPreview(canvas);
    _drawGpsMarker(canvas, _toScreen(gpsData!.latitude, gpsData!.longitude));
    // Label grid DIHAPUS dari canvas -- cukup di GPS panel bawah
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

  void _drawRadius(Canvas canvas, FieldLayer layer) {
    final center = _toScreen(layer.latitude, layer.longitude);
    final px = _metersToPixels(layer.radius);
    canvas.drawCircle(center, px, Paint()..color = layer.color.withOpacity(0.08)..style = PaintingStyle.fill);
    canvas.drawCircle(center, px, Paint()..color = layer.color..strokeWidth = 1.5..style = PaintingStyle.stroke);
    _drawLabel(canvas, layer.name, center + Offset(0, -px - 10), 11, layer.color);
  }

  void _drawLayerLines(Canvas canvas, FieldLayer layer) {
    for (final line in layer.lines) {
      if (line.points.length < 2) continue;
      final opacity = _highlightOpacity(line.id);
      final path = Path();
      Offset? mid;
      for (int i = 0; i < line.points.length; i++) {
        final pt = _toScreen(line.points[i].latitude, line.points[i].longitude);
        if (i == line.points.length ~/ 2) mid = pt;
        if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, Paint()..color = line.color.withOpacity(opacity)..strokeWidth = _isHighlighted(line.id) ? 3 : 2..style = PaintingStyle.stroke);
      if (_isHighlighted(line.id) && mid != null) _drawInfoLabel(canvas, line.distanceLabel, mid);
    }
  }

  void _drawLayerPolygons(Canvas canvas, FieldLayer layer) {
    for (final poly in layer.polygons) {
      if (poly.points.length < 3) continue;
      final opacity = _highlightOpacity(poly.id);
      final path = Path();
      Offset center = Offset.zero;
      for (int i = 0; i < poly.points.length; i++) {
        final pt = _toScreen(poly.points[i].latitude, poly.points[i].longitude);
        center += pt;
        if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      center = center / poly.points.length.toDouble();
      canvas.drawPath(path, Paint()..color = poly.color.withOpacity(0.2 * opacity)..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = poly.color.withOpacity(opacity)..strokeWidth = _isHighlighted(poly.id) ? 3 : 2..style = PaintingStyle.stroke);
      if (_isHighlighted(poly.id)) _drawInfoLabel(canvas, poly.areaLabel, center);
    }
  }

  void _drawLayerTracks(Canvas canvas, FieldLayer layer) {
    for (final track in layer.tracks) {
      final opacity = _highlightOpacity(track.id);
      _drawLayerTrackPoints(canvas, track.points, track.color.withOpacity(opacity), width: _isHighlighted(track.id) ? 3.5 : 2.5);
      if (_isHighlighted(track.id) && track.points.length > 1) {
        final mid = track.points[track.points.length ~/ 2];
        _drawInfoLabel(canvas, track.distanceLabel, _toScreen(mid.latitude, mid.longitude));
      }
    }
  }

  void _drawLayerTrackPoints(Canvas canvas, List<LayerTrackPoint> points, Color color, {double width = 2.5}) {
    if (points.length < 2) return;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pt = _toScreen(points[i].latitude, points[i].longitude);
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
  }

  void _drawLayerPins(Canvas canvas, FieldLayer layer) {
    for (final pin in layer.pins) {
      final pos = _toScreen(pin.latitude, pin.longitude);
      final opacity = _highlightOpacity(pin.id);
      final r = _isHighlighted(pin.id) ? 11.0 : 8.0;
      canvas.drawCircle(pos, r, Paint()..color = pin.color.withOpacity(opacity));
      canvas.drawCircle(pos, r, Paint()..color = Colors.white.withOpacity(opacity)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }
  }

  void _drawImportLines(Canvas canvas, ImportedFile imp) {
    for (final line in imp.lines) {
      if (line.points.length < 2) continue;
      final opacity = _highlightOpacity(line.id);
      final path = Path();
      Offset? mid;
      for (int i = 0; i < line.points.length; i++) {
        final pt = _toScreen(line.points[i].latitude, line.points[i].longitude);
        if (i == line.points.length ~/ 2) mid = pt;
        if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, Paint()..color = line.color.withOpacity(0.7 * opacity)..strokeWidth = _isHighlighted(line.id) ? 3 : 1.5..style = PaintingStyle.stroke);
      if (_isHighlighted(line.id) && mid != null) _drawInfoLabel(canvas, line.distanceLabel, mid);
    }
  }

  void _drawImportPolygons(Canvas canvas, ImportedFile imp) {
    for (final poly in imp.polygons) {
      if (poly.points.length < 3) continue;
      final opacity = _highlightOpacity(poly.id);
      final path = Path();
      Offset center = Offset.zero;
      for (int i = 0; i < poly.points.length; i++) {
        final pt = _toScreen(poly.points[i].latitude, poly.points[i].longitude);
        center += pt;
        if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      center = center / poly.points.length.toDouble();
      canvas.drawPath(path, Paint()..color = poly.color.withOpacity(0.15 * opacity)..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = poly.color.withOpacity(0.7 * opacity)..strokeWidth = _isHighlighted(poly.id) ? 3 : 1.5..style = PaintingStyle.stroke);
      if (_isHighlighted(poly.id)) _drawInfoLabel(canvas, poly.areaLabel, center);
    }
  }

  void _drawImportTracks(Canvas canvas, ImportedFile imp) {
    for (final track in imp.tracks) {
      final opacity = _highlightOpacity(track.id);
      _drawLayerTrackPoints(canvas, track.points, track.color.withOpacity(0.7 * opacity), width: _isHighlighted(track.id) ? 3.5 : 1.5);
      if (_isHighlighted(track.id) && track.points.length > 1) {
        final mid = track.points[track.points.length ~/ 2];
        _drawInfoLabel(canvas, track.distanceLabel, _toScreen(mid.latitude, mid.longitude));
      }
    }
  }

  void _drawImportPins(Canvas canvas, ImportedFile imp) {
    for (final pin in imp.pins) {
      final pos = _toScreen(pin.latitude, pin.longitude);
      final opacity = _highlightOpacity(pin.id);
      final r = _isHighlighted(pin.id) ? 10.0 : 6.0;
      canvas.drawCircle(pos, r, Paint()..color = pin.color.withOpacity(0.8 * opacity));
      canvas.drawCircle(pos, r, Paint()..color = Colors.white..strokeWidth = 1..style = PaintingStyle.stroke);
    }
  }

  void _drawPreview(Canvas canvas) {
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
    }
  }

  void _drawOldTrackPoints(Canvas canvas, List<OldTrackPoint> points, Color color) {
    if (points.length < 2) return;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pt = _toScreen(points[i].latitude, points[i].longitude);
      if (i == 0) path.moveTo(pt.dx, pt.dy); else path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
  }

  void _drawPins(Canvas canvas) {
    for (final pin in pins) {
      final pos = _toScreen(pin.latitude, pin.longitude);
      canvas.drawCircle(pos, 8, Paint()..color = pin.color);
      canvas.drawCircle(pos, 8, Paint()..color = Colors.white..strokeWidth = 1.5..style = PaintingStyle.stroke);
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

  void _drawInfoLabel(Canvas canvas, String text, Offset pos) {
    final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx-tp.width/2-5, pos.dy-tp.height/2-3, tp.width+10, tp.height+6), const Radius.circular(4)), Paint()..color = Colors.black.withOpacity(0.75));
    tp.paint(canvas, Offset(pos.dx-tp.width/2, pos.dy-tp.height/2));
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, double size, Color color) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx-tp.width/2-3, pos.dy-tp.height/2-2, tp.width+6, tp.height+4), const Radius.circular(3)), Paint()..color = Colors.black.withOpacity(0.5));
    tp.paint(canvas, Offset(pos.dx-tp.width/2, pos.dy-tp.height/2));
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}
