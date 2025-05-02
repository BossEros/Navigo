import 'package:flutter/material.dart';

/// Model class representing filters for route history
class RouteHistoryFilter {
  /// Date range for filtering routes
  final DateTimeRange? dateRange;

  /// Travel modes to include (null means all modes)
  final List<String>? travelModes;

  /// Distance range in meters
  final RangeValues? distanceRange;

  /// Duration range in seconds
  final RangeValues? durationRange;

  /// Traffic conditions to include (null means all conditions)
  final List<String>? trafficConditions;

  /// Maximum distance available in the filter (meters)
  static const double maxDistance = 50000; // 50 km

  /// Maximum duration available in the filter (seconds)
  static const double maxDuration = 7200; // 2 hours

  /// Default constructor
  RouteHistoryFilter({
    this.dateRange,
    this.travelModes,
    this.distanceRange,
    this.durationRange,
    this.trafficConditions,
  });

  /// Create a new filter with no constraints (shows all routes)
  factory RouteHistoryFilter.empty() {
    return RouteHistoryFilter();
  }

  /// Create a copy of this filter with some values changed
  RouteHistoryFilter copyWith({
    DateTimeRange? dateRange,
    List<String>? travelModes,
    RangeValues? distanceRange,
    RangeValues? durationRange,
    List<String>? trafficConditions,
    bool clearDateRange = false,
    bool clearTravelModes = false,
    bool clearDistanceRange = false,
    bool clearDurationRange = false,
    bool clearTrafficConditions = false,
  }) {
    return RouteHistoryFilter(
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      travelModes: clearTravelModes ? null : (travelModes ?? this.travelModes),
      distanceRange: clearDistanceRange ? null : (distanceRange ?? this.distanceRange),
      durationRange: clearDurationRange ? null : (durationRange ?? this.durationRange),
      trafficConditions: clearTrafficConditions ? null : (trafficConditions ?? this.trafficConditions),
    );
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return dateRange != null ||
        travelModes != null ||
        distanceRange != null ||
        durationRange != null ||
        trafficConditions != null;
  }

  /// Count how many filter categories are active
  int get activeFilterCount {
    int count = 0;
    if (dateRange != null) count++;
    if (travelModes != null) count++;
    if (distanceRange != null) count++;
    if (durationRange != null) count++;
    if (trafficConditions != null) count++;
    return count;
  }

  /// Convert distance range from meters to user-friendly format
  String get formattedDistanceRange {
    if (distanceRange == null) return 'Any distance';

    final minDistance = distanceRange!.start;
    final maxDistance = distanceRange!.end;

    // Format using km for larger distances
    String minText = minDistance < 1000
        ? '${minDistance.toInt()} m'
        : '${(minDistance / 1000).toStringAsFixed(1)} km';

    String maxText = maxDistance >= maxDistance
        ? 'Any'
        : maxDistance < 1000
        ? '${maxDistance.toInt()} m'
        : '${(maxDistance / 1000).toStringAsFixed(1)} km';

    return '$minText - $maxText';
  }

  /// Convert duration range from seconds to user-friendly format
  String get formattedDurationRange {
    if (durationRange == null) return 'Any duration';

    final minDuration = durationRange!.start;
    final maxDuration = durationRange!.end;

    // Format using minutes or hours as appropriate
    String minText = _formatDuration(minDuration);
    String maxText = maxDuration >= maxDuration
        ? 'Any'
        : _formatDuration(maxDuration);

    return '$minText - $maxText';
  }

  /// Format seconds into a readable duration
  String _formatDuration(double seconds) {
    if (seconds < 60) {
      return '${seconds.toInt()} sec';
    } else if (seconds < 3600) {
      return '${(seconds / 60).floor()} min';
    } else {
      int hours = (seconds / 3600).floor();
      int minutes = ((seconds % 3600) / 60).floor();
      return minutes > 0 ? '$hours h $minutes min' : '$hours h';
    }
  }

  /// Format travel modes into readable text
  String get formattedTravelModes {
    if (travelModes == null) return 'Any mode';

    return travelModes!.map((mode) {
      switch (mode) {
        case 'DRIVING': return 'Driving';
        case 'WALKING': return 'Walking';
        case 'BICYCLING': return 'Cycling';
        case 'TRANSIT': return 'Transit';
        default: return mode;
      }
    }).join(', ');
  }

  /// Format traffic conditions into readable text
  String get formattedTrafficConditions {
    if (trafficConditions == null) return 'Any traffic';

    return trafficConditions!.map((condition) {
      return condition[0].toUpperCase() + condition.substring(1).toLowerCase();
    }).join(', ');
  }
}