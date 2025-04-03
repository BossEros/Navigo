// lib/models/route_history.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile.dart';  // For Address class

class RouteHistory {
  final String id;
  final Address startLocation;
  final Address endLocation;
  final List<Address> waypoints;
  final Distance distance;
  final TravelDuration duration;
  final DateTime createdAt;
  final String travelMode;
  final String polyline;
  final String? routeName;
  final String? trafficConditions;
  final String? weatherConditions;

  RouteHistory({
    required this.id,
    required this.startLocation,
    required this.endLocation,
    required this.waypoints,
    required this.distance,
    required this.duration,
    required this.createdAt,
    required this.travelMode,
    required this.polyline,
    this.routeName,
    this.trafficConditions,
    this.weatherConditions,
  });

  factory RouteHistory.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<Address> waypoints = [];
    if (data.containsKey('waypoints') && data['waypoints'] is List) {
      waypoints = (data['waypoints'] as List)
          .map((wp) => Address.fromMap(wp as Map<String, dynamic>))
          .toList();
    }

    return RouteHistory(
      id: doc.id,
      startLocation: Address.fromMap(data['start_location'] ?? {}),
      endLocation: Address.fromMap(data['end_location'] ?? {}),
      waypoints: waypoints,
      distance: Distance.fromMap(data['distance'] ?? {}),
      duration: TravelDuration.fromMap(data['duration'] ?? {}),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      travelMode: data['travel_mode'] ?? 'DRIVING',
      polyline: data['polyline'] ?? '',
      routeName: data['route_name'],
      trafficConditions: data['traffic_conditions'],
      weatherConditions: data['weather_conditions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start_location': startLocation.toMap(),
      'end_location': endLocation.toMap(),
      'waypoints': waypoints.map((wp) => wp.toMap()).toList(),
      'distance': distance.toMap(),
      'duration': duration.toMap(),
      'created_at': createdAt,
      'travel_mode': travelMode,
      'polyline': polyline,
      'route_name': routeName,
      'traffic_conditions': trafficConditions,
      'weather_conditions': weatherConditions,
    };
  }
}

class Distance {
  final String text;
  final int value;

  Distance({required this.text, required this.value});

  factory Distance.fromMap(Map<String, dynamic> map) {
    return Distance(
      text: map['text'] ?? '0 km',
      value: map['value'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'value': value,
    };
  }
}

class TravelDuration {
  final String text;
  final int value;

  TravelDuration({required this.text, required this.value});

  factory TravelDuration.fromMap(Map<String, dynamic> map) {
    return TravelDuration(
      text: map['text'] ?? '0 min',
      value: map['value'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'value': value,
    };
  }
}