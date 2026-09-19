import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/gps_provider.dart';
import '../providers/map_provider.dart';
import '../providers/track_provider.dart';
import '../providers/layer_provider.dart';
import '../models/map_models.dart';
import '../models/layer_models.dart';
import '../models/gps_data.dart';
import '../theme/app_theme.dart';
import '../widgets/gps_panel.dart';
import '../widgets/compass_widget.dart';
import '../widgets/map_canvas.dart';
import '../utils/kml_importer.dart';
import 'layer_screen.dart';
import 'layer_detail_screen.dart';
import 'coordinate_screen.dart';
import 'radius_create_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final MapCanvasController _mapController = MapCanvasController();
  DrawingMode _drawingMode = DrawingMode.none;
  bool _layerDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GpsProvider>().start();
      _checkLayerOnStart();
    });
  }

  void _checkLayerOnStart() {
    final layer = context.read<LayerProvider>();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (layer.layers.isEmpty && !_layerDialogShown) {
        _layerDialogShown = true;
        _showCreateRadiusDialog();
      } else if (layer.layers.isNotEmpty && !_layerDialogShown) {
        _layerDialogShown = true;
        _showLayerPickerSheet();
      }
    });
  }

  void _showLayerPickerSheet() {
    final layer = context.read<LayerProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Pilih Layer', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...layer.layers.map((l) => ListTile(
            leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: l.color, shape: BoxShape.circle)),
            title: Text(l.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('${_radiusLabel(l.radius)}  •  ${l.pins.length} pin  •  ${l.tracks.length} track', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: () {
              layer.setActiveLayer(l);
              Navigator.pop(context);
              // Zoom fit ke radius layer
              _mapController.zoomFitToCoords([LatLon(l.latitude, l.longitude)]);
            },
          )),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(context); _showCreateRadiusDialog(); },
                icon: const Icon(Icons.add, color: AppColors.primary),
                label: const Text('Buat Layer Baru', style: TextStyle(color: AppColors.primary)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showCreateRadiusDialog() {
    final gps = context.read<GpsProvider>();
    final layer = context.read<LayerProvider>();
    final nameCtrl = TextEditingController();
    double radius = 100;
    Color color = LayerColors.options[1];
    final radiusOptions = [50, 100, 200, 500, 1000, 2000, 5000];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Buat Layer Baru', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Nama Layer (opsional)',
                    hintText: 'Contoh: GUNUNG MAS',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Radius', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: radiusOptions.map((r) {
                    final selected = radius == r;
                    return GestureDetector(
                      onTap: () => setS(() => radius = r.toDouble()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                        ),
                        child: Text(_radiusLabel(r.toDouble()), style: TextStyle(color: selected ? Colors.black : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Warna', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: LayerColors.options.map((c) => GestureDetector(
                    onTap: () => setS(() => color = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: color == c ? AppColors.primary : AppColors.divider, width: color == c ? 3 : 1)),
                      child: color == c ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            if (layer.layers.isNotEmpty)
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final coord = _mapController.getCrosshairCoord();
                final lat = coord?.latitude ?? gps.current?.latitude ?? 0;
                final lon = coord?.longitude ?? gps.current?.longitude ?? 0;
                final now = DateTime.now();
                final autoIndex = layer.todayLayerAutoIndex(now);
                final name = defaultLayerName(now, nameCtrl.text, autoIndex);
                final newLayer = FieldLayer(name: name, latitude: lat, longitude: lon, radius: radius, color: color);
                layer.addLayer(newLayer);
                Navigator.pop(context);
                _mapController.zoomFitToCoords([LatLon(lat, lon)]);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black),
              child: const Text('Buat Layer'),
            ),
          ],
        ),
      ),
    );
  }

  String _radiusLabel(double r) => r >= 1000 ? '${(r/1000).toStringAsFixed(0)} km' : '${r.toInt()} m';

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GpsProvider>();
    final layer = context.watch<LayerProvider>();

    if (layer.isRecording && gps.current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        layer.addTrackPoint(LayerTrackPoint(
          latitude: gps.current!.latitude,
          longitude: gps.current!.longitude,
          altitude: gps.current!.altitude,
          timestamp: gps.current!.timestamp,
        ));
      });
    }

    return WillPopScope(
      onWillPop: () async {
        if (layer.isRecording) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppColors.card,
              title: const Text('Track Sedang Direkam', style: TextStyle(color: AppColors.textPrimary)),
              content: const Text('Track akan disimpan otomatis. Yakin mau keluar?', style: TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text('Keluar & Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (confirm == true) await layer.autoSaveTrack();
          return confirm ?? false;
        }
        return true;
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, gps, layer),
            Expanded(
              child: Stack(
                children: [
                  MapCanvas(
                    controller: _mapController,
                    onLongPress: (lat, lon) => _showPinDialog(context, lat, lon),
                    onTapObject: (id, type, info) => _showObjectPopup(context, id, type, info, layer),
                    onDoubleTapObject: (id, type, isImport, importFileId) => _openObjectDetail(context, id, type, isImport, importFileId, layer),
                  ),
                  const Center(child: _Crosshair()),

                  // Banner error GPS
                  Consumer<GpsProvider>(builder: (_, gps, __) {
                    if (gps.errorMessage == null) return const SizedBox.shrink();
                    return Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: AppColors.error.withOpacity(0.92),
                        child: Row(
                          children: [
                            const Icon(Icons.location_off, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(gps.errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 12))),
                            TextButton(
                              onPressed: () => context.read<GpsProvider>().start(),
                              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Kompas -- hanya tampil kalau HP punya sensor
                  if (gps.hasCompass)
                    Positioned(top: 12, right: 12, child: CompassWidget(heading: gps.heading)),

                  // Track recording indicator
                  if (layer.isRecording)
                    Positioned(top: 12, left: 12, child: _TrackingIndicator(provider: layer)),

                  // Drawing mode toolbar
                  if (_drawingMode != DrawingMode.none)
                    Positioned(
                      bottom: 12, left: 0, right: 0,
                      child: _DrawingToolbar(
                        mode: _drawingMode,
                        onAdd: () { _mapController.addDrawPoint(); setState(() {}); },
                        onUndo: () { _mapController.undoDrawPoint(); setState(() {}); },
                        onFinish: () { _mapController.finishDrawing(); setState(() => _drawingMode = DrawingMode.none); },
                        onCancel: () { _mapController.setDrawingMode(DrawingMode.none); setState(() => _drawingMode = DrawingMode.none); },
                      ),
                    ),

                  // Zoom buttons
                  if (_drawingMode == DrawingMode.none)
                    Positioned(right: 12, bottom: 12, child: _ZoomButtons(controller: _mapController)),

                  // Action buttons
                  if (_drawingMode == DrawingMode.none)
                    Positioned(
                      left: 12, bottom: 12,
                      child: _ActionButtons(
                        onLayer: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LayerScreen())),
                        onPin: () => _addPinFromCrosshair(context),
                        onTrack: () => _toggleTrack(context, layer),
                        onLine: () => _startDrawing(DrawingMode.line),
                        onPolygon: () => _startPolygon(context),
                        onImport: () => _importFile(context),
                        onExport: () => _showExport(context, layer),
                        isTracking: layer.isRecording,
                      ),
                    ),
                ],
              ),
            ),
            StatefulBuilder(
              builder: (_, setState) => GpsPanel(gridInterval: _mapController.gridInterval),
            ),
          ],
        ),
      ),
    ); // Scaffold
    }, // WillPopScope child
    ); // WillPopScope
  }

  Widget _buildAppBar(BuildContext context, GpsProvider gps, LayerProvider layer) {
    return Container(
      height: 52,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.map_rounded, size: 16, color: Colors.black),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BorneoGIS Navigator', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  layer.activeLayer != null ? layer.activeLayer!.name : 'Tidak ada layer aktif',
                  style: TextStyle(color: layer.activeLayer != null ? AppColors.primary : AppColors.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.my_location, color: AppColors.textPrimary, size: 20), onPressed: () => _mapController.centerToGps()),
          IconButton(icon: const Icon(Icons.layers, color: AppColors.textPrimary, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LayerScreen()))),
          IconButton(icon: const Icon(Icons.search, color: AppColors.textPrimary, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinateScreen()))),
        ],
      ),
    );
  }

  void _addPinFromCrosshair(BuildContext context) {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) {
      _showCreateRadiusDialog();
      return;
    }
    final coord = _mapController.getCrosshairCoord();
    if (coord == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS belum aktif')));
      return;
    }
    _showPinDialog(context, coord.latitude, coord.longitude);
  }

  void _showPinDialog(BuildContext context, double lat, double lon) {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) { _showCreateRadiusDialog(); return; }

    if (!layer.activeLayer!.containsPoint(lat, lon)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Posisi di luar radius -- pin tidak bisa dipasang'), backgroundColor: AppColors.error),
      );
      return;
    }

    final ctrl = TextEditingController();
    Color selectedColor = LayerColors.options[0];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Pasang Pin', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(controller: ctrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Nama (opsional)')),
              const SizedBox(height: 12),
              const Text('Warna', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 8),
              Row(
                children: LayerColors.options.map((c) => GestureDetector(
                  onTap: () => setS(() => selectedColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: selectedColor == c ? AppColors.primary : AppColors.divider, width: selectedColor == c ? 3 : 1)),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final gps = context.read<GpsProvider>();
                final pin = LayerPin(
                  name: ctrl.text.isEmpty ? null : ctrl.text,
                  latitude: lat, longitude: lon,
                  altitude: gps.current?.altitude ?? 0,
                  color: selectedColor,
                );
                final ok = await context.read<LayerProvider>().addPin(pin);
                Navigator.pop(context);
                if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal pasang pin'), backgroundColor: AppColors.error));
              },
              child: const Text('Pasang'),
            ),
          ],
        ),
      ),
    );
  }

  void _showObjectPopup(BuildContext context, String id, HighlightType type, String info, LayerProvider layer) {
    if (layer.activeLayer == null) return;
    final al = layer.activeLayer!;

    String name = '';
    DateTime? timestamp;

    switch (type) {
      case HighlightType.pin:
        try { final obj = al.pins.firstWhere((p) => p.id == id); name = obj.name; timestamp = obj.createdAt; } catch (_) {
          for (final imp in al.imports) { try { final obj = imp.pins.firstWhere((p) => p.id == id); name = obj.name; timestamp = obj.createdAt; break; } catch (_) {} }
        }
        break;
      case HighlightType.track:
        try { final obj = al.tracks.firstWhere((t) => t.id == id); name = obj.name; timestamp = obj.createdAt; } catch (_) {
          for (final imp in al.imports) { try { final obj = imp.tracks.firstWhere((t) => t.id == id); name = obj.name; timestamp = obj.createdAt; break; } catch (_) {} }
        }
        break;
      case HighlightType.line:
        try { final obj = al.lines.firstWhere((l) => l.id == id); name = obj.name; timestamp = obj.createdAt; } catch (_) {
          for (final imp in al.imports) { try { final obj = imp.lines.firstWhere((l) => l.id == id); name = obj.name; timestamp = obj.createdAt; break; } catch (_) {} }
        }
        break;
      case HighlightType.polygon:
        try { final obj = al.polygons.firstWhere((p) => p.id == id); name = obj.name; timestamp = obj.createdAt; } catch (_) {
          for (final imp in al.imports) { try { final obj = imp.polygons.firstWhere((p) => p.id == id); name = obj.name; timestamp = obj.createdAt; break; } catch (_) {} }
        }
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_typeIcon(type), color: _typeColor(type), size: 18),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            if (info.isNotEmpty) Text(info, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Text(_formatTs(timestamp), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
            const SizedBox(height: 8),
            const Text('Double tap objek untuk edit', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _openObjectDetail(BuildContext context, String id, HighlightType type, bool isImport, String? importFileId, LayerProvider layer) {
    if (layer.activeLayer == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => LayerDetailScreen(
      layerId: layer.activeLayer!.id,
      focusId: id,
      focusType: type,
      isImport: isImport,
      importFileId: importFileId,
    )));
  }

  void _toggleTrack(BuildContext context, LayerProvider layer) {
    if (layer.activeLayer == null) { _showCreateRadiusDialog(); return; }
    if (layer.isRecording) {
      layer.stopRecording();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track disimpan')));
    } else {
      layer.startRecording(null);
    }
  }

  void _startDrawing(DrawingMode mode) {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) { _showCreateRadiusDialog(); return; }
    setState(() => _drawingMode = mode);
    _mapController.setDrawingMode(mode);
  }

  void _startPolygon(BuildContext context) {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) { _showCreateRadiusDialog(); return; }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Pilih Satuan Luas', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Hektar (ha)', style: TextStyle(color: AppColors.textPrimary)), onTap: () { Navigator.pop(context); _startDrawingPolygon(AreaUnit.hectare); }),
            ListTile(title: const Text('Meter persegi (m²)', style: TextStyle(color: AppColors.textPrimary)), onTap: () { Navigator.pop(context); _startDrawingPolygon(AreaUnit.squareMeter); }),
          ],
        ),
      ),
    );
  }

  void _startDrawingPolygon(AreaUnit unit) {
    context.read<LayerProvider>().setPendingPolygonUnit(unit);
    setState(() => _drawingMode = DrawingMode.polygon);
    _mapController.setDrawingMode(DrawingMode.polygon);
  }

  Future<void> _importFile(BuildContext context) async {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) { _showCreateRadiusDialog(); return; }
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['kml', 'KML']);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final imported = await KmlImporter.parse(path);
    if (imported == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal import file')));
      return;
    }
    await layer.addImport(layer.activeLayer!.id, imported);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import: ${imported.name}')));
  }

  void _showExport(BuildContext context, LayerProvider layer) {
    if (layer.activeLayer == null) { _showCreateRadiusDialog(); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => LayerDetailScreen(layerId: layer.activeLayer!.id)));
  }

  IconData _typeIcon(HighlightType type) {
    switch (type) {
      case HighlightType.pin: return Icons.location_on;
      case HighlightType.track: return Icons.timeline;
      case HighlightType.line: return Icons.polyline;
      case HighlightType.polygon: return Icons.pentagon_outlined;
    }
  }

  Color _typeColor(HighlightType type) {
    switch (type) {
      case HighlightType.pin: return AppColors.pinColor;
      case HighlightType.track: return AppColors.primary;
      case HighlightType.line: return AppColors.accent;
      case HighlightType.polygon: return AppColors.warning;
    }
  }

  String _formatTs(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

// ── DRAWING TOOLBAR ───────────────────────────────────────────────────────────

class _DrawingToolbar extends StatelessWidget {
  final DrawingMode mode;
  final VoidCallback onAdd, onUndo, onFinish, onCancel;
  const _DrawingToolbar({required this.mode, required this.onAdd, required this.onUndo, required this.onFinish, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.95), borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.divider)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mode == DrawingMode.line ? 'Line' : 'Poligon', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(width: 12),
            _ToolBtn(icon: Icons.add_location_alt, color: AppColors.primary, label: 'Shoot', onTap: onAdd),
            const SizedBox(width: 8),
            _ToolBtn(icon: Icons.undo, color: AppColors.warning, label: 'Undo', onTap: onUndo),
            const SizedBox(width: 8),
            _ToolBtn(icon: Icons.check_circle, color: AppColors.primary, label: 'Selesai', onTap: onFinish),
            const SizedBox(width: 8),
            _ToolBtn(icon: Icons.cancel, color: AppColors.error, label: 'Batal', onTap: onCancel),
          ],
        ),
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon; final Color color; final String label; final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 22),
      Text(label, style: TextStyle(color: color, fontSize: 9)),
    ]),
  );
}

// ── CROSSHAIR ─────────────────────────────────────────────────────────────────

class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) => SizedBox(width: 40, height: 40, child: CustomPaint(painter: _CrosshairPainter()));
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.crosshair..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final cx = size.width/2; final cy = size.height/2;
    canvas.drawLine(Offset(0, cy), Offset(cx-6, cy), paint);
    canvas.drawLine(Offset(cx+6, cy), Offset(size.width, cy), paint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy-6), paint);
    canvas.drawLine(Offset(cx, cy+6), Offset(cx, size.height), paint);
    canvas.drawCircle(Offset(cx, cy), 2, paint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => false;
}

// ── TRACKING INDICATOR ────────────────────────────────────────────────────────

class _TrackingIndicator extends StatelessWidget {
  final LayerProvider provider;
  const _TrackingIndicator({required this.provider});

  @override
  Widget build(BuildContext context) {
    final track = provider.recordingTrack;
    final pts = track?.points.length ?? 0;
    final dist = track?.distanceLabel ?? '0 m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('REC  $pts pts  $dist', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── ZOOM BUTTONS ──────────────────────────────────────────────────────────────

class _ZoomButtons extends StatelessWidget {
  final MapCanvasController controller;
  const _ZoomButtons({required this.controller});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    _ZoomBtn(icon: Icons.add, onTap: () => controller.zoomIn()),
    const SizedBox(height: 4),
    _ZoomBtn(icon: Icons.remove, onTap: () => controller.zoomOut()),
  ]);
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
      child: Icon(icon, color: AppColors.textPrimary, size: 20),
    ),
  );
}

// ── ACTION BUTTONS ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final VoidCallback onLayer, onPin, onTrack, onLine, onPolygon, onImport, onExport;
  final bool isTracking;

  const _ActionButtons({required this.onLayer, required this.onPin, required this.onTrack, required this.onLine, required this.onPolygon, required this.onImport, required this.onExport, required this.isTracking});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _ActionBtn(icon: Icons.layers, label: 'Layer', color: AppColors.primary, onTap: onLayer),
      const SizedBox(height: 6),
      _ActionBtn(icon: Icons.location_on, label: 'Pin', color: AppColors.pinColor, onTap: onPin),
      const SizedBox(height: 6),
      _ActionBtn(icon: isTracking ? Icons.stop : Icons.play_arrow, label: isTracking ? 'Stop' : 'Track', color: isTracking ? AppColors.error : AppColors.primary, onTap: onTrack),
      const SizedBox(height: 6),
      _ActionBtn(icon: Icons.polyline, label: 'Line', color: AppColors.accent, onTap: onLine),
      const SizedBox(height: 6),
      _ActionBtn(icon: Icons.pentagon_outlined, label: 'Poly', color: AppColors.warning, onTap: onPolygon),
      const SizedBox(height: 6),
      _ActionBtn(icon: Icons.upload_file, label: 'Import', color: AppColors.accent, onTap: onImport),
      const SizedBox(height: 6),
      _ActionBtn(icon: Icons.download, label: 'Export', color: AppColors.warning, onTap: onExport),
    ],
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
