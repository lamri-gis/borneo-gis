import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gps_provider.dart';
import '../providers/layer_provider.dart';
import '../models/layer_models.dart';
import '../theme/app_theme.dart';

class RadiusCreateScreen extends StatefulWidget {
  const RadiusCreateScreen({super.key});

  @override
  State<RadiusCreateScreen> createState() => _RadiusCreateScreenState();
}

class _RadiusCreateScreenState extends State<RadiusCreateScreen> {
  final _nameCtrl = TextEditingController();
  double _radius = 100;
  Color _color = LayerColors.options[1];

  final List<double> _radiusOptions = [50, 100, 200, 500, 1000, 2000, 5000];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

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
            // GPS status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed, color: gps.isActive ? AppColors.primary : AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    gps.isActive
                        ? 'GPS: ${gps.current!.latitude.toStringAsFixed(6)}°, ${gps.current!.longitude.toStringAsFixed(6)}°'
                        : 'GPS tidak aktif',
                    style: TextStyle(color: gps.isActive ? AppColors.textPrimary : AppColors.error, fontSize: 12),
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
              decoration: InputDecoration(
                hintText: 'Contoh: GUNUNG MAS',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
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
              spacing: 8,
              runSpacing: 8,
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
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 3 : 1),
                    ),
                    child: selected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Tombol buat
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: gps.isActive ? () => _create(context, gps) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Buat Layer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _create(BuildContext context, GpsProvider gps) {
    final layerProvider = context.read<LayerProvider>();
    final now = DateTime.now();
    final autoIndex = layerProvider.todayLayerAutoIndex(now);
    final name = defaultLayerName(now, _nameCtrl.text, autoIndex);

    final layer = FieldLayer(
      name: name,
      latitude: gps.current!.latitude,
      longitude: gps.current!.longitude,
      radius: _radius,
      color: _color,
    );

    layerProvider.addLayer(layer);
    Navigator.pop(context);
  }
}
