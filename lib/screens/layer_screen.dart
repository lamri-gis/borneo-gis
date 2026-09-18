import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/layer_provider.dart';
import '../models/layer_models.dart';
import '../theme/app_theme.dart';
import 'radius_create_screen.dart';
import 'layer_detail_screen.dart';

class LayerScreen extends StatelessWidget {
  const LayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Layer', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RadiusCreateScreen())),
            tooltip: 'Buat Layer Baru',
          ),
        ],
      ),
      body: Consumer<LayerProvider>(builder: (_, lp, __) {
        if (lp.layers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.layers_outlined, color: AppColors.textSecondary, size: 48),
                const SizedBox(height: 12),
                const Text('Belum ada layer', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                const Text('Tap + untuk buat layer baru', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RadiusCreateScreen())),
                  icon: const Icon(Icons.add),
                  label: const Text('Buat Layer'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lp.layers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final layer = lp.layers[i];
            final isActive = lp.activeLayer?.id == layer.id;
            return _LayerCard(layer: layer, isActive: isActive);
          },
        );
      }),
    );
  }
}

class _LayerCard extends StatelessWidget {
  final FieldLayer layer;
  final bool isActive;

  const _LayerCard({required this.layer, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final lp = context.read<LayerProvider>();

    return GestureDetector(
      onTap: () {
        lp.setActiveLayer(layer);
        Navigator.push(context, MaterialPageRoute(builder: (_) => LayerDetailScreen(layerId: layer.id)));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? layer.color : AppColors.divider, width: isActive ? 2 : 1),
        ),
        child: Row(
          children: [
            // Indikator aktif
            GestureDetector(
              onTap: () => lp.setActiveLayer(layer),
              child: Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: isActive ? layer.color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: layer.color, width: 2),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(layer.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${_radiusLabel(layer.radius)}  •  ${layer.pins.length} pin  •  ${layer.tracks.length} track  •  ${layer.lines.length} line  •  ${layer.polygons.length} poly',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Edit radius
            IconButton(
              icon: const Icon(Icons.radio_button_unchecked, color: AppColors.accent, size: 18),
              onPressed: () => _editRadius(context, lp, layer),
              tooltip: 'Edit radius',
            ),
            // Hapus layer
            IconButton(
              icon: Icon(Icons.delete_outline, color: layer.isEmpty ? AppColors.error : AppColors.divider, size: 18),
              onPressed: layer.isEmpty
                  ? () => _confirmDelete(context, lp, layer)
                  : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kosongkan semua section terlebih dahulu'))),
            ),
          ],
        ),
      ),
    );
  }

  String _radiusLabel(double r) => r >= 1000 ? '${(r/1000).toStringAsFixed(0)} km' : '${r.toInt()} m';

  void _editRadius(BuildContext context, LayerProvider lp, FieldLayer layer) {
    double newRadius = layer.radius;
    final List<double> options = [50, 100, 200, 500, 1000, 2000, 5000];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Edit Radius', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Radius sekarang: ${_radiusLabel(layer.radius)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: options.map((r) {
                  final selected = newRadius == r;
                  return GestureDetector(
                    onTap: () => setS(() => newRadius = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                      ),
                      child: Text(_radiusLabel(r), style: TextStyle(color: selected ? Colors.black : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                lp.updateLayerRadius(layer.id, newRadius);
                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, LayerProvider lp, FieldLayer layer) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Hapus Layer', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Hapus ${layer.name}?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () { lp.removeLayer(layer.id); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
