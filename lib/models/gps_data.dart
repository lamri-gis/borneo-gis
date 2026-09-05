import 'dart:math' as math;

class GpsData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime timestamp;

  const GpsData({
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
    this.accuracy = 0,
    this.speed = 0,
    this.heading = 0,
    required this.timestamp,
  });

  UtmCoord get utm => UtmCoord.fromLatLon(latitude, longitude);

  double distanceTo(GpsData other) {
    const R = 6371000.0;
    final lat1 = latitude * math.pi / 180;
    final lat2 = other.latitude * math.pi / 180;
    final dLat = (other.latitude - latitude) * math.pi / 180;
    final dLon = (other.longitude - longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class UtmCoord {
  final double easting;
  final double northing;
  final int zone;
  final bool isNorthern;

  const UtmCoord({
    required this.easting,
    required this.northing,
    required this.zone,
    required this.isNorthern,
  });

  String get zoneLetter => isNorthern ? 'N' : 'S';

  factory UtmCoord.fromLatLon(double lat, double lon) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const e2 = 2 * f - f * f;
    const k0 = 0.9996;
    const e0 = 500000.0;

    final zone = ((lon + 180) / 6).floor() + 1;
    final isNorthern = lat >= 0;

    final latRad = lat * math.pi / 180;
    final lonRad = lon * math.pi / 180;
    final lonOriginRad = ((zone - 1) * 6 - 180 + 3) * math.pi / 180;

    final sinLat = math.sin(latRad);
    final cosLat = math.cos(latRad);
    final tanLat = math.tan(latRad);

    final N = a / math.sqrt(1 - e2 * sinLat * sinLat);
    final T = tanLat * tanLat;
    final C = e2 / (1 - e2) * cosLat * cosLat;
    final A = cosLat * (lonRad - lonOriginRad);

    final e4 = e2 * e2;
    final e6 = e4 * e2;
    final M = a * (
      (1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * latRad
      - (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * latRad)
      + (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * latRad)
      - 35 * e6 / 3072 * math.sin(6 * latRad)
    );

    final x = k0 * N * (A + (1 - T + C) * math.pow(A, 3) / 6 +
        (5 - 18 * T + T * T + 72 * C - 58 * (e2 / (1 - e2))) *
        math.pow(A, 5) / 120) + e0;

    final y = k0 * (M + N * tanLat * (A * A / 2 +
        (5 - T + 9 * C + 4 * C * C) * math.pow(A, 4) / 24 +
        (61 - 58 * T + T * T + 600 * C - 330 * (e2 / (1 - e2))) *
        math.pow(A, 6) / 720));

    return UtmCoord(
      easting: x,
      northing: isNorthern ? y : y + 10000000.0,
      zone: zone,
      isNorthern: isNorthern,
    );
  }
}
