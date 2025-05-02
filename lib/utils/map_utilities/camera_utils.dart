import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CameraUtils {
  /// Calculate LatLngBounds from a list of points
  static LatLngBounds calculateBoundsFromPoints(List<LatLng> points) {
    if (points.isEmpty) {
      // Default bounds if no points are provided
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Add some buffer for a smoother look
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final buffer = max(latSpan, lngSpan) * 0.1; // 10% buffer

    return LatLngBounds(
      southwest: LatLng(minLat - buffer, minLng - buffer),
      northeast: LatLng(maxLat + buffer, maxLng + buffer),
    );
  }

  /// Calculate offset target for camera to account for UI overlays
  static LatLng calculateOffsetTarget(
      LatLng location,
      double verticalOffsetPixels,
      double zoom) {
    if (verticalOffsetPixels == 0) return location;

    // Convert pixel offset to LatLng offset based on zoom level
    final latitudeOffset = _calculateLatitudeOffset(
        verticalOffsetPixels,
        location.latitude,
        zoom
    );

    // Create a new target with the offset applied
    return LatLng(
        location.latitude - latitudeOffset, // Move south (down in screen coordinates)
        location.longitude
    );
  }

  /// Calculates latitude offset based on vertical pixel offset, current latitude, and zoom level.
  /// This converts screen pixels to geographic coordinates.
  static double _calculateLatitudeOffset(double pixelOffset, double latitude, double zoom) {
    // The number of pixels per degree varies based on latitude and zoom level
    // This is an approximation based on the Mercator projection
    final metersPerPixel = 156543.03392 * cos(latitude * pi / 180) / pow(2, zoom);
    final metersOffset = pixelOffset * metersPerPixel;

    // Convert meters to degrees (approximate)
    // 111,111 meters per degree of latitude (roughly)
    return metersOffset / 111111;
  }
}