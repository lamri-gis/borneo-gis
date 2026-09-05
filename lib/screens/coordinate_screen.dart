import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_provider.dart';
import '../models/map_models.dart';
import '../theme/app_theme.dart';

class CoordinateScreen extends StatefulWidget {
  const CoordinateScreen({super.key});

  @override
  State<CoordinateScreen> createState() => _CoordinateScreenState();
}

class _CoordinateScreenState extends State<CoordinateScreen> {
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _eastingCtrl = TextEditingController();
  final _northingCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController(text: '50');
  bool _isNorthern = true;
  String _mode = 'latlon';

  @override
  void dispose() {
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _labelCtrl.dispose();
    _eastingCtrl.dispose();
    _northingCtrl.dispose();
    _zoneCtrl.dispose();
    super.dispose();
  }

  // Konversi UTM ke Lat/Lon akurat (WGS84)
  List<double>? _utmToLatLon(double easting, double northing, int zone, bool isNorthern) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const e2 = 2 * f - f * f;
    const k0 = 0.9996;
    const e0 = 500000.0;

    final x = easting - e0;
    final y = isNorthern ? northing : northing - 10000000.0;
    final lonOrigin = (zone - 1) * 6 - 180 + 3;
    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
    final M = y / k0;
    final mu = M / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));

    final phi1 = mu
        + (3 * e1 / 2 - 27 * e1 * e1 * e1 / 32) * math.sin(2 * mu)
        + (21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32) * math.sin(4 * mu)
        + (151 * e1 * e1 * e1 / 96) * math.sin(6 * mu);

    final N1 = a / math.sqrt(1 - e2 * math.sin(phi1) * math.sin(phi1));
    final T1 = math.tan(phi1) * math.tan(phi1);
    final C1 = e2 / (1 - e2) * math.cos(phi1) * math.cos(phi1);
    final R1 = a * (1 - e2) / math.pow(1 - e2 * math.sin(phi1) * math.sin(phi1), 1.5);
    final D = x / (N1 * k0);

    final lat = phi1 - (N1 * math.tan(phi1) / R1) * (
        D * D / 2
        - (5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * e2 / (1 - e2)) * math.pow(D, 4) / 24
        + (61 + 90 * T1 + 298 * C1 + 45 * T1 * T1 - 252 * e2 / (1 - e2) - 3 * C1 * C1) * math.pow(D, 6) / 720);

    final lon = (D
        - (1 + 2 * T1 + C1) * math.pow(D, 3) / 6
        + (5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * e2 / (1 - e2) + 24 * T1 * T1) * math.pow(D, 5) / 120
    ) / math.cos(phi1);

    return [lat * 180 / math.pi, lonOrigin + lon * 180 / math.pi];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Input Koordinat'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode selector
          Row(
            children: [
              ChoiceChip(
                label: const Text('Lat/Lon'),
                selected: _mode == 'latlon',
                onSelected: (_) => setState(() => _mode = 'latlon'),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.card,
                labelStyle: TextStyle(color: _mode == 'latlon' ? Colors.black : AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('UTM'),
                selected: _mode == 'utm',
                onSelected: (_) => setState(() => _mode = 'utm'),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.card,
                labelStyle: TextStyle(color: _mode == 'utm' ? Colors.black : AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_mode == 'latlon') ...[
            TextField(
              controller: _latCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Latitude', hintText: 'contoh: 0.914925'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lonCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Longitude', hintText: 'contoh: 118.215600'),
            ),
          ] else ...[
            Row(children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _eastingCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Easting (m)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _northingCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Northing (m)'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _zoneCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Zona UTM', hintText: '1-60'),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Hemisphere:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('N'),
                selected: _isNorthern,
                onSelected: (_) => setState(() => _isNorthern = true),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.card,
                labelStyle: TextStyle(color: _isNorthern ? Colors.black : AppColors.textPrimary),
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('S'),
                selected: !_isNorthern,
                onSelected: (_) => setState(() => _isNorthern = false),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.card,
                labelStyle: TextStyle(color: !_isNorthern ? Colors.black : AppColors.textPrimary),
              ),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Zona UTM otomatis dari lon GPS. Cek peta jika tidak yakin.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],

          const SizedBox(height: 16),
          TextField(
            controller: _labelCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Label pin (opsional)'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Pasang Pin di Koordinat Ini'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    double lat, lon;

    if (_mode == 'latlon') {
      lat = double.tryParse(_latCtrl.text) ?? double.nan;
      lon = double.tryParse(_lonCtrl.text) ?? double.nan;
    } else {
      final e = double.tryParse(_eastingCtrl.text) ?? double.nan;
      final n = double.tryParse(_northingCtrl.text) ?? double.nan;
      final z = int.tryParse(_zoneCtrl.text) ?? 0;
      if (e.isNaN || n.isNaN || z < 1 || z > 60) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Isi Easting, Northing, dan Zona yang valid (1-60)')),
        );
        return;
      }
      final result = _utmToLatLon(e, n, z, _isNorthern);
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konversi gagal')));
        return;
      }
      lat = result[0];
      lon = result[1];
    }

    if (lat.isNaN || lon.isNaN || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koordinat tidak valid')));
      return;
    }

    context.read<MapProvider>().addPin(MapPin(
      latitude: lat, longitude: lon, label: _labelCtrl.text,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pin dipasang: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}')),
    );
    Navigator.pop(context);
  }
}
