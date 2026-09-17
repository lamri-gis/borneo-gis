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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final MapCanvasController _mapController = MapCanvasController();
  DrawingMode _drawingMode = DrawingMode.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GpsProvider>().start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GpsProvider>();
    final layer = context.watch<LayerProvider>();

    // Auto-add track point kalau recording
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

    return Scaffold(
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
                    onLongPress: (lat, lon) => _onLongPress(context, lat, lon),
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

                  // Banner tidak ada layer aktif
                  if (layer.activeLayer == null)
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: AppColors.warning.withOpacity(0.9),
                        child: Row(
                          children: [
                            const Icon(Icons.layers_outlined, color: Colors.black, size: 16),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Belum ada layer aktif', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600))),
                            TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LayerScreen())),
                              child: const Text('Buat Layer', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Kompas
                  Positioned(
                    top: 12, right: 12,
                    child: CompassWidget(heading: gps.heading),
                  ),

                  // Track recording indicator
                  if (layer.isRecording)
                    Positioned(
                      top: 12, left: 12,
                      child: _TrackingIndicator(provider: layer),
                    ),

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
                    Positioned(
                      right: 12, bottom: 12,
                      child: _ZoomButtons(controller: _mapController),
                    ),

                  // Action buttons
                  if (_drawingMode == DrawingMode.none)
                    Positioned(
                      left: 12, bottom: 12,
                      child: _ActionButtons(
                        onLayer: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LayerScreen())),
                        onPin: () => _addPin(context),
                        onTrack: () => _toggleTrack(context, layer),
                        onLine: () => _startDrawing(DrawingMode.line),
                        onPolygon: () => _startDrawing(DrawingMode.polygon),
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
    );
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
                  style: TextStyle(color: layer.activeLayer != null ? AppColors.primary : AppColors.warning, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.textPrimary, size: 20),
            onPressed: () => _mapController.centerToGps(),
          ),
          IconButton(
            icon: const Icon(Icons.layers, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LayerScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinateScreen())),
          ),
        ],
      ),
    );
  }

  void _onLongPress(BuildContext context, double lat, double lon) {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buat layer dulu')));
      return;
    }
    _showPinDialog(context, lat, lon);
  }

  void _addPin(BuildContext context) {
    final gps = context.read<GpsProvider>();
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buat layer dulu')));
      return;
    }
    if (gps.current == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS belum aktif')));
      return;
    }
    _showPinDialog(context, gps.current!.latitude, gps.current!.longitude);
  }

  void _showPinDialog(BuildContext context, double lat, double lon) {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) return;

    // Cek apakah dalam radius
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
              TextField(
                controller: ctrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Nama (opsional)'),
              ),
              const SizedBox(height: 12),
              const Text('Warna', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 8),
              Row(
                children: LayerColors.options.map((c) => GestureDetector(
                  onTap: () => setS(() => selectedColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: c, shape: BoxShape.circle,
                      border: Border.all(color: selectedColor == c ? AppColors.primary : AppColors.divider, width: selectedColor == c ? 3 : 1),
                    ),
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
                  latitude: lat,
                  longitude: lon,
                  altitude: gps.current?.altitude ?? 0,
                  color: selectedColor,
                );
                final ok = await context.read<LayerProvider>().addPin(pin);
                Navigator.pop(context);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gagal pasang pin'), backgroundColor: AppColors.error),
                  );
                }
              },
              child: const Text('Pasang'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTrack(BuildContext context, LayerProvider layer) {
    if (layer.activeLayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buat layer dulu')));
      return;
    }
    if (layer.isRecording) {
      layer.stopRecording();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track disimpan')));
    } else {
      layer.startRecording(null);
    }
  }

  void _startDrawing(DrawingMode mode) {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buat layer dulu')));
      return;
    }
    setState(() => _drawingMode = mode);
    _mapController.setDrawingMode(mode);
  }

  Future<void> _importFile(BuildContext context) async {
    final layer = context.read<LayerProvider>();
    if (layer.activeLayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buat layer dulu')));
      return;
    }
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
    if (layer.activeLayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buat layer dulu')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => LayerDetailScreen(layerId: layer.activeLayer!.id)));
  }
}

// ── DRAWING TOOLBAR ───────────────────────────────────────────────────────────

class _DrawingToolbar extends StatelessWidget {
  final DrawingMode mode;
  final VoidCallback onAdd;
  final VoidCallback onUndo;
  final VoidCallback onFinish;
  final VoidCallback onCancel;

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
            _ToolBtn(icon: Icons.add_location_alt, color: AppColors.primary, label: 'Tambah', onTap: onAdd),
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
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ToolBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          Text(label, style: TextStyle(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── CROSSHAIR ─────────────────────────────────────────────────────────────────

class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 40, height: 40, child: CustomPaint(painter: _CrosshairPainter()));
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.crosshair..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    final cx = size.width / 2; final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(cx - 6, cy), paint);
    canvas.drawLine(Offset(cx + 6, cy), Offset(size.width, cy), paint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy - 6), paint);
    canvas.drawLine(Offset(cx, cy + 6), Offset(cx, size.height), paint);
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('REC  $pts pts  $dist', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── ZOOM BUTTONS ──────────────────────────────────────────────────────────────

class _ZoomButtons extends StatelessWidget {
  final MapCanvasController controller;
  const _ZoomButtons({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomBtn(icon: Icons.add, onTap: () => controller.zoomIn()),
        const SizedBox(height: 4),
        _ZoomBtn(icon: Icons.remove, onTap: () => controller.zoomOut()),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

// ── ACTION BUTTONS ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final VoidCallback onLayer;
  final VoidCallback onPin;
  final VoidCallback onTrack;
  final VoidCallback onLine;
  final VoidCallback onPolygon;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final bool isTracking;

  const _ActionButtons({
    required this.onLayer,
    required this.onPin,
    required this.onTrack,
    required this.onLine,
    required this.onPolygon,
    required this.onImport,
    required this.onExport,
    required this.isTracking,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
