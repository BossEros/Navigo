import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationUtils {
  /// Calculate straight-line distance between two points (in meters)
  static double calculateDistanceInMeters(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double lon1 = point1.longitude * pi / 180;
    final double lon2 = point2.longitude * pi / 180;

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) * sin(dLon/2) * sin(dLon/2);
    final double c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c;
  }

  /// Calculate bearing between two points
  static double calculateBearing(LatLng start, LatLng end) {
    final double startLat = start.latitude * pi / 180;
    final double startLng = start.longitude * pi / 180;
    final double endLat = end.latitude * pi / 180;
    final double endLng = end.longitude * pi / 180;

    final double dLng = endLng - startLng;

    final double y = sin(dLng) * cos(endLat);
    final double x = cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(dLng);

    final double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  /// Find a position along a route at a certain percentage
  static LatLng findPositionAlongRoute(List<LatLng> points, double percentage) {
    if (points.isEmpty) return const LatLng(0, 0);
    if (points.length == 1) return points[0];

    int index = (points.length * percentage).toInt();
    index = index.clamp(0, points.length - 1);

    return points[index];
  }
}