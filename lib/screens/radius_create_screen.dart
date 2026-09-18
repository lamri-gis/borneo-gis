import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gps_provider.dart';
import '../providers/layer_provider.dart';
import '../providers/map_provider.dart';
import '../models/layer_models.dart';
import '../theme/app_theme.dart';
import '../widgets/map_canvas.dart';

class RadiusCreateScreen extends StatefulWidget {
  final MapCanvasController? mapController;
  const RadiusCreateScreen({super.key, this.mapController});

  @override
  State<RadiusCreateScreen> createState() => _RadiusCreateScreenState();
}

class _RadiusCreateScreenState extends State<RadiusCreateScreen> {
  final _nameCtrl = TextEditingController();
  double _radius = 100;
  Color _color = LayerColors.options[1];
  bool _useCrosshair = true; // default pakai crosshair

  final List<double> _radiusOptions = [50, 100, 200, 500, 1000, 2000, 5000];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  String _radiusLabel(double r) => r >= 1000 ? '${(r/1000).toStringAsFixed(0)} km' : '${r.toInt()} m';

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GpsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Buat Layer Baru', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sumber koordinat
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pusat Radius', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _useCrosshair = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _useCrosshair ? AppColors.primary.withOpacity(0.15) : AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _useCrosshair ? AppColors.primary : AppColors.divider),
                          ),
                          child: Column(children: [
                            Icon(Icons.add, color: _useCrosshair ? AppColors.primary : AppColors.textSecondary, size: 18),
                            const SizedBox(height: 2),
                            Text('Crosshair', style: TextStyle(color: _useCrosshair ? AppColors.primary : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _useCrosshair = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_useCrosshair ? AppColors.primary.withOpacity(0.15) : AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: !_useCrosshair ? AppColors.primary : AppColors.divider),
                          ),
                          child: Column(children: [
                            Icon(Icons.gps_fixed, color: !_useCrosshair ? AppColors.primary : AppColors.textSecondary, size: 18),
                            const SizedBox(height: 2),
                            Text('GPS', style: TextStyle(color: !_useCrosshair ? AppColors.primary : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    _useCrosshair
                        ? 'Pusat radius dari posisi crosshair di peta'
                        : gps.isActive
                            ? 'GPS: ${gps.current!.latitude.toStringAsFixed(6)}°, ${gps.current!.longitude.toStringAsFixed(6)}°'
                            : 'GPS tidak aktif',
                    style: TextStyle(color: _useCrosshair ? AppColors.accent : gps.isActive ? AppColors.textPrimary : AppColors.error, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Nama layer
            const Text('Nama Layer', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Contoh: GUNUNG MAS',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true, fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                helperText: 'Kosongkan untuk auto nama',
                helperStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ),
            const SizedBox(height: 20),

            // Radius
            const Text('Radius', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _radiusOptions.map((r) {
                final selected = _radius == r;
                return GestureDetector(
                  onTap: () => setState(() => _radius = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                    ),
                    child: Text(_radiusLabel(r), style: TextStyle(color: selected ? Colors.black : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Warna
            const Text('Warna', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(LayerColors.options.length, (i) {
                final c = LayerColors.options[i];
                final selected = _color == c;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 3 : 1)),
                    child: selected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_useCrosshair || gps.isActive) ? () => _create(context, gps) : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Buat Layer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _create(BuildContext context, GpsProvider gps) {
    double lat, lon;

    if (_useCrosshair && widget.mapController != null) {
      final coord = widget.mapController!.getCrosshairCoord();
      if (coord == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS belum aktif -- crosshair belum bisa digunakan')));
        return;
      }
      lat = coord.latitude;
      lon = coord.longitude;
    } else {
      if (gps.current == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS tidak aktif')));
        return;
      }
      lat = gps.current!.latitude;
      lon = gps.current!.longitude;
    }

    final layerProvider = context.read<LayerProvider>();
    final now = DateTime.now();
    final autoIndex = layerProvider.todayLayerAutoIndex(now);
    final name = defaultLayerName(now, _nameCtrl.text, autoIndex);

    final layer = FieldLayer(name: name, latitude: lat, longitude: lon, radius: _radius, color: _color);
    layerProvider.addLayer(layer);
    Navigator.pop(context);
  }
}
