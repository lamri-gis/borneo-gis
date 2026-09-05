import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gps_provider.dart';
import '../providers/map_provider.dart';
import '../models/map_models.dart';
import '../theme/app_theme.dart';

class RadiusScreen extends StatefulWidget {
  const RadiusScreen({super.key});

  @override
  State<RadiusScreen> createState() => _RadiusScreenState();
}

class _RadiusScreenState extends State<RadiusScreen> {
  final List<TextEditingController> _controllers = [TextEditingController(text: '100')];
  final _labelCtrl = TextEditingController();
  String _unit = 'm';
  String _source = 'gps';
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    _labelCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tambah Radius'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Label
          const Text('Label (opsional)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _labelCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Nama radius'),
          ),
          const SizedBox(height: 20),

          // Unit
          const Text('Satuan', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: ['m', 'km'].map((u) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(u),
                selected: _unit == u,
                onSelected: (_) => setState(() => _unit = u),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.card,
                labelStyle: TextStyle(color: _unit == u ? Colors.black : AppColors.textPrimary),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),

          // Radius values
          const Text('Nilai Radius', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          ..._controllers.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: e.value,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Radius ${e.key + 1}',
                      suffixText: _unit,
                      suffixStyle: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                if (_controllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: AppColors.error),
                    onPressed: () => setState(() => _controllers.removeAt(e.key)),
                  ),
              ],
            ),
          )),
          TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Tambah radius', style: TextStyle(color: AppColors.primary)),
            onPressed: () => setState(() => _controllers.add(TextEditingController())),
          ),
          const SizedBox(height: 20),

          // Source
          const Text('Titik Pusat', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          ...['gps', 'manual'].map((s) => RadioListTile(
            value: s,
            groupValue: _source,
            onChanged: (v) => setState(() => _source = v!),
            title: Text(s == 'gps' ? 'Dari GPS saat ini' : 'Input koordinat manual',
                style: const TextStyle(color: AppColors.textPrimary)),
            activeColor: AppColors.primary,
          )),

          if (_source == 'manual') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lonCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Tambah Radius', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final gps = context.read<GpsProvider>();
    final map = context.read<MapProvider>();

    double lat, lon;
    if (_source == 'gps') {
      if (gps.current == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS belum aktif')));
        return;
      }
      lat = gps.current!.latitude;
      lon = gps.current!.longitude;
    } else {
      lat = double.tryParse(_latCtrl.text) ?? 0;
      lon = double.tryParse(_lonCtrl.text) ?? 0;
      if (lat == 0 && lon == 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan koordinat yang valid')));
        return;
      }
    }

    final radii = _controllers
        .map((c) => double.tryParse(c.text) ?? 0)
        .where((r) => r > 0)
        .map((r) => _unit == 'km' ? r * 1000 : r)
        .toList();

    if (radii.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan minimal satu radius')));
      return;
    }

    map.addCircle(RadiusCircle(
      latitude: lat,
      longitude: lon,
      radii: radii,
      label: _labelCtrl.text,
    ));

    Navigator.pop(context);
  }
}
