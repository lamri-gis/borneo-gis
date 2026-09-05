import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/gps_provider.dart';
import '../models/gps_data.dart';
import '../theme/app_theme.dart';

class GpsPanel extends StatefulWidget {
  const GpsPanel({super.key});

  @override
  State<GpsPanel> createState() => _GpsPanelState();
}

class _GpsPanelState extends State<GpsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<GpsProvider>(builder: (_, gps, __) {
      final pos = gps.current;
      final utm = pos?.utm;
      final accuracy = pos?.accuracy ?? 0;
      final color = accuracy <= 5 ? AppColors.primary
          : accuracy <= 15 ? AppColors.warning
          : AppColors.error;

      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      gps.isActive ? Icons.gps_fixed : Icons.gps_off,
                      color: gps.isActive ? AppColors.primary : AppColors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      gps.isActive ? 'GPS Aktif' : 'GPS Tidak Aktif',
                      style: TextStyle(
                        color: gps.isActive ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pos != null ? '±${accuracy.toStringAsFixed(1)} m' : '--',
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(children: [
                      _InfoCard('LATITUDE', pos != null ? '${pos.latitude.toStringAsFixed(6)}° N' : '--'),
                      const SizedBox(width: 8),
                      _InfoCard('LONGITUDE', pos != null ? '${pos.longitude.toStringAsFixed(6)}° E' : '--'),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _InfoCard('UTM EASTING', utm != null ? utm.easting.toStringAsFixed(1) : '--'),
                      const SizedBox(width: 8),
                      _InfoCard('UTM NORTHING', utm != null ? utm.northing.toStringAsFixed(1) : '--'),
                      const SizedBox(width: 8),
                      _InfoCard('ZONA', utm != null ? '${utm.zone}${utm.zoneLetter}' : '--', flex: 1),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _InfoCard('ELEVASI', pos != null ? '${pos.altitude.toStringAsFixed(1)} m' : '--'),
                      const SizedBox(width: 8),
                      _InfoCard('HEADING', pos != null ? '${_headingLabel(pos.heading)} ${pos.heading.toStringAsFixed(0)}°' : '--'),
                      const SizedBox(width: 8),
                      _InfoCard('KECEPATAN', pos != null ? '${pos.speed.toStringAsFixed(1)} km/h' : '--'),
                    ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  String _headingLabel(double h) {
    if (h < 22.5 || h >= 337.5) return 'U';
    if (h < 67.5) return 'TL';
    if (h < 112.5) return 'T';
    if (h < 157.5) return 'TG';
    if (h < 202.5) return 'S';
    if (h < 247.5) return 'BD';
    if (h < 292.5) return 'B';
    return 'BL';
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final int flex;

  const _InfoCard(this.label, this.value, {this.flex = 2});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
