import 'dart:math';

/// ACI Centre — auto check-in geofence (§11 of the replication guide).
const double aciCenterLat = 23.7639;
const double aciCenterLng = 90.3934;
const double geofenceRadiusMeters = 150;

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * R * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double d) => d * pi / 180;

double distanceFromAciCenter(double lat, double lng) =>
    haversineMeters(lat, lng, aciCenterLat, aciCenterLng);

bool insideAciCenter(double lat, double lng) =>
    distanceFromAciCenter(lat, lng) <= geofenceRadiusMeters;
