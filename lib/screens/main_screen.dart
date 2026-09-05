import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/gps_provider.dart';
import '../providers/map_provider.dart';
import '../providers/track_provider.dart';
import '../models/map_models.dart';
import '../models/gps_data.dart';
import '../theme/app_theme.dart';
import '../widgets/gps_panel.dart';
import '../widgets/compass_widget.dart';
import '../widgets/map_canvas.dart';
import '../utils/kml_gpx_parser.dart';
import '../utils/export_utils.dart';
import 'radius_screen.dart';
import 'coordinate_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isTracking = false;
  final GlobalKey _mapKey = GlobalKey();

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
    final track = context.watch<TrackProvider>();

    // Tambah track point saat GPS update
    if (track.isRecording && gps.current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        track.addPoint(gps.current!);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar custom
            _buildAppBar(context, gps, track),
            // Map area
            Expanded(
              child: Stack(
                children: [
                  // Basemap canvas
                  MapCanvas(
                    key: _mapKey,
                    onLongPress: (lat, lon) => _showPinDialog(context, lat, lon),
                  ),

                  // Crosshair
                  const Center(child: _Crosshair()),

                  // Compass
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CompassWidget(heading: gps.heading),
                  ),

                  // Track indicator
                  if (track.isRecording)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _TrackingIndicator(track: track),
                    ),

                  // Zoom buttons
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _ZoomButtons(mapKey: _mapKey),
                  ),

                  // FAB actions
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _ActionButtons(
                      onAddRadius: () => _showRadiusOptions(context),
                      onAddPin: () => _showAddPinFromGps(context),
                      onImport: () => _importFile(context),
                      onExport: () => _showExportMenu(context),
                      onTrack: () => _toggleTracking(context, track),
                      isTracking: track.isRecording,
                    ),
                  ),
                ],
              ),
            ),
            // GPS Panel
            const GpsPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, GpsProvider gps, TrackProvider track) {
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
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BorneoGIS Navigator', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Field Mapping', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.textPrimary, size: 20),
            onPressed: () {
              final state = _mapKey.currentState;
              if (state is _MapCanvasState) state.centerToGps();
            },
            tooltip: 'Ke lokasi GPS',
          ),
          IconButton(
            icon: const Icon(Icons.layers_outlined, color: AppColors.textPrimary, size: 20),
            onPressed: () => _showLayersPanel(context),
            tooltip: 'Layer',
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinateScreen())),
            tooltip: 'Cari koordinat',
          ),
        ],
      ),
    );
  }

  void _showRadiusOptions(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RadiusScreen()));
  }

  void _showAddPinFromGps(BuildContext context) {
    final gps = context.read<GpsProvider>();
    if (gps.current == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS belum aktif')));
      return;
    }
    _showPinDialog(context, gps.current!.latitude, gps.current!.longitude);
  }

  void _showPinDialog(BuildContext context, double lat, double lon) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Pasang Pin', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${lat.toStringAsFixed(6)}°, ${lon.toStringAsFixed(6)}°',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Label (opsional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              context.read<MapProvider>().addPin(MapPin(
                latitude: lat, longitude: lon, label: ctrl.text,
              ));
              Navigator.pop(context);
            },
            child: const Text('Pasang'),
          ),
        ],
      ),
    );
  }

  void _toggleTracking(BuildContext context, TrackProvider track) async {
    if (track.isRecording) {
      final path = await track.stopAndSave();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path != null ? 'Disimpan: $path' : 'Track disimpan')),
        );
      }
    } else {
      final ctrl = TextEditingController(text: 'Track ${DateTime.now().day}-${DateTime.now().month}');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Mulai Rekam Track', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Nama track'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                track.startRecording(ctrl.text);
                Navigator.pop(context);
              },
              child: const Text('Mulai'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gpx', 'kml'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final parsed = await KmlGpxParser.parse(path);
    if (parsed == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal baca file')));
      return;
    }

    final map = context.read<MapProvider>();
    for (final pin in parsed.pins) map.addPin(pin);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import: ${parsed.pins.length} pin, ${parsed.tracks.length} track')),
      );
    }
  }

  void _showExportMenu(BuildContext context) {
    final map = context.read<MapProvider>();
    final track = context.read<TrackProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share, color: AppColors.primary),
            title: const Text('Export Pin ke GPX', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () async {
              Navigator.pop(context);
              final path = await ExportUtils.pinsToGpx(map.pins, 'borneogis');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disimpan: $path')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: AppColors.primary),
            title: const Text('Export Pin ke KML', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () async {
              Navigator.pop(context);
              final path = await ExportUtils.pinsToKml(map.pins, 'borneogis');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disimpan: $path')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: AppColors.accent),
            title: const Text('Export semua ke GeoJSON', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () async {
              Navigator.pop(context);
              final path = await ExportUtils.toGeoJson(map.pins, track.savedTracks, 'borneogis');
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disimpan: $path')));
            },
          ),
        ],
      ),
    );
  }

  void _showLayersPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (_) => Consumer<MapProvider>(builder: (_, map, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Layer', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            if (map.pins.isEmpty && map.circles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada layer', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ...map.pins.map((pin) => ListTile(
              leading: Icon(Icons.location_on, color: pin.color),
              title: Text(pin.label.isEmpty ? 'Pin' : pin.label, style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                onPressed: () => map.removePin(pin.id),
              ),
            )),
            ...map.circles.map((c) => ListTile(
              leading: Icon(Icons.radio_button_unchecked, color: c.color),
              title: Text(c.label.isEmpty ? 'Radius' : c.label, style: const TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('${c.radii.map((r) => r >= 1000 ? '${(r / 1000).toStringAsFixed(1)}km' : '${r.toStringAsFixed(0)}m').join(', ')}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                onPressed: () => map.removeCircle(c.id),
              ),
            )),
            const SizedBox(height: 16),
          ],
        );
      }),
    );
  }
}

class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40, height: 40,
      child: CustomPaint(painter: _CrosshairPainter()),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.crosshair
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(cx - 6, cy), paint);
    canvas.drawLine(Offset(cx + 6, cy), Offset(size.width, cy), paint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, cy - 6), paint);
    canvas.drawLine(Offset(cx, cy + 6), Offset(cx, size.height), paint);
    canvas.drawCircle(Offset(cx, cy), 2, paint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => false;
}

class _TrackingIndicator extends StatelessWidget {
  final TrackProvider track;
  const _TrackingIndicator({required this.track});

  @override
  Widget build(BuildContext context) {
    final pts = track.currentPoints.length;
    final dist = track.activeTrack?.totalDistance ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            'REC  $pts pts  ${dist >= 1000 ? '${(dist / 1000).toStringAsFixed(2)}km' : '${dist.toStringAsFixed(0)}m'}',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ZoomButtons extends StatelessWidget {
  final GlobalKey mapKey;
  const _ZoomButtons({required this.mapKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomBtn(icon: Icons.add, onTap: () {
          final state = mapKey.currentState;
          if (state is _MapCanvasState) state.zoomIn();
        }),
        const SizedBox(height: 4),
        _ZoomBtn(icon: Icons.remove, onTap: () {
          final state = mapKey.currentState;
          if (state is _MapCanvasState) state.zoomOut();
        }),
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onAddRadius;
  final VoidCallback onAddPin;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onTrack;
  final bool isTracking;

  const _ActionButtons({
    required this.onAddRadius,
    required this.onAddPin,
    required this.onImport,
    required this.onExport,
    required this.onTrack,
    required this.isTracking,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActionBtn(icon: Icons.radio_button_unchecked, label: 'Radius', color: AppColors.primary, onTap: onAddRadius),
        const SizedBox(height: 6),
        _ActionBtn(icon: Icons.location_on, label: 'Pin', color: AppColors.pinColor, onTap: onAddPin),
        const SizedBox(height: 6),
        _ActionBtn(icon: Icons.upload_file, label: 'Import', color: AppColors.accent, onTap: onImport),
        const SizedBox(height: 6),
        _ActionBtn(icon: Icons.download, label: 'Export', color: AppColors.warning, onTap: onExport),
        const SizedBox(height: 6),
        _ActionBtn(
          icon: isTracking ? Icons.stop : Icons.play_arrow,
          label: isTracking ? 'Stop' : 'Track',
          color: isTracking ? AppColors.error : AppColors.primary,
          onTap: onTrack,
        ),
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
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
