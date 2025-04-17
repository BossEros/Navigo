import 'package:flutter/material.dart';
import '../../models/map_models/map_style.dart';

class MapUtils {
  /// Get icon data for instruction step
  static IconData getManeuverIcon(String instruction) {
    final String lowerInstruction = instruction.toLowerCase();

    if (lowerInstruction.contains('turn right')) {
      return Icons.turn_right;
    } else if (lowerInstruction.contains('turn left')) {
      return Icons.turn_left;
    } else if (lowerInstruction.contains('u-turn')) {
      return Icons.u_turn_left;
    } else if (lowerInstruction.contains('merge') ||
        lowerInstruction.contains('take exit')) {
      return Icons.merge_type;
    } else if (lowerInstruction.contains('destination')) {
      return Icons.place;
    }

    return Icons.arrow_forward;
  }

  /// Get color for traffic condition
  static Color getTrafficColor(String? trafficConditions) {
    if (trafficConditions == null) return Colors.grey;

    switch (trafficConditions.toLowerCase()) {
      case 'light':
        return Colors.green;
      case 'normal':
        return Colors.amber;
      case 'heavy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get appropriate map style for current state
  static String? getMapStyleForState({
    required bool isInNavigationMode,
    required bool trafficEnabled,
    required bool isNightMode,
  }) {
    if (!trafficEnabled) {
      return MapStyles.trafficOffMapStyle;
    }

    if (isNightMode) {
      return MapStyles.nightMapStyle;
    }

    if (isInNavigationMode) {
      return MapStyles.navigationMapStyle;
    }

    return null; // Default Google style
  }

  /// Get icon for place type
  static IconData getIconForPlaceType(String? type) {
    if (type == null) return Icons.location_on_outlined;

    switch (type) {
      case 'restaurant':
      case 'food':
      case 'cafe':
        return Icons.restaurant;
      case 'store':
      case 'shopping_mall':
      case 'supermarket':
        return Icons.shopping_bag;
      case 'school':
      case 'university':
        return Icons.school;
      case 'hospital':
      case 'doctor':
      case 'pharmacy':
        return Icons.local_hospital;
      case 'airport':
      case 'bus_station':
      case 'train_station':
        return Icons.directions_transit;
      case 'hotel':
      case 'lodging':
        return Icons.hotel;
      case 'park':
      case 'tourist_attraction':
        return Icons.park;
      case 'gym':
      case 'fitness_center':
        return Icons.fitness_center;
      case 'bar':
      case 'night_club':
        return Icons.nightlife;
      case 'gas_station':
        return Icons.local_gas_station;
      case 'bank':
      case 'atm':
        return Icons.account_balance;
      default:
        return Icons.location_on_outlined;
    }
  }
}