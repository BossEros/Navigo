import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/services/google-api-services.dart' as api;

/// Simplified model for route information
class RouteInfo {
  final String id;
  final List<LatLng> points;
  final int durationInSeconds;
  final int distanceInMeters;
  final String durationText;
  final String distanceText;
  final String summary;
  final LatLngBounds bounds;
  final bool isSelected;

  RouteInfo({
    required this.id,
    required this.points,
    required this.durationInSeconds,
    required this.distanceInMeters,
    required this.durationText,
    required this.distanceText,
    required this.summary,
    required this.bounds,
    this.isSelected = false,
  });

  /// Create a RouteInfo from API route
  factory RouteInfo.fromApiRoute(api.Route route, int index) {
    final leg = route.legs.isNotEmpty ? route.legs[0] : null;

    return RouteInfo(
      id: 'route_$index',
      points: route.polylinePoints,
      durationInSeconds: leg?.duration.value ?? 0,
      distanceInMeters: leg?.distance.value ?? 0,
      durationText: leg?.duration.text ?? '0 min',
      distanceText: leg?.distance.text ?? '0 km',
      summary: route.summary,
      bounds: route.bounds,
    );
  }

  /// Create a copy with some properties changed
  RouteInfo copyWith({
    String? id,
    List<LatLng>? points,
    int? durationInSeconds,
    int? distanceInMeters,
    String? durationText,
    String? distanceText,
    String? summary,
    LatLngBounds? bounds,
    bool? isSelected,
  }) {
    return RouteInfo(
      id: id ?? this.id,
      points: points ?? this.points,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
      durationText: durationText ?? this.durationText,
      distanceText: distanceText ?? this.distanceText,
      summary: summary ?? this.summary,
      bounds: bounds ?? this.bounds,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}