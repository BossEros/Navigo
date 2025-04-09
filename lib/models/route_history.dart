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
    print('Parsing document: ${doc.id}');

    // Parse the created_at timestamp from the database
    DateTime createdAt;
    try {
      if (data['created_at'] is Timestamp) {
        createdAt = (data['created_at'] as Timestamp).toDate();
      } else if (data['created_at'] is String) {
        createdAt = DateTime.parse(data['created_at']);
      } else {
        createdAt = DateTime.now();
        print('Warning: created_at not found or invalid format, using current time');
      }
    } catch (e) {
      print('Error parsing created_at: $e');
      createdAt = DateTime.now();
    }

    // Parse start_location object with error handling
    Address startLocation;
    try {
      if (data['start_location'] is Map) {
        Map<String, dynamic> startLocationMap = data['start_location'] as Map<String, dynamic>;
        startLocation = Address(
          formattedAddress: startLocationMap['formattedAddress'] ?? '',
          lat: (startLocationMap['lat'] is num) ? (startLocationMap['lat'] as num).toDouble() : 0.0,
          lng: (startLocationMap['lng'] is num) ? (startLocationMap['lng'] as num).toDouble() : 0.0,
          placeId: startLocationMap['placeId'] ?? '',
        );
      } else {
        startLocation = Address.empty();
        print('Warning: start_location not found or invalid format, using empty address');
      }
    } catch (e) {
      print('Error parsing start_location: $e');
      startLocation = Address.empty();
    }

    // Parse end_location object with error handling
    Address endLocation;
    try {
      if (data['end_location'] is Map) {
        Map<String, dynamic> endLocationMap = data['end_location'] as Map<String, dynamic>;
        endLocation = Address(
          formattedAddress: endLocationMap['formattedAddress'] ?? '',
          lat: (endLocationMap['lat'] is num) ? (endLocationMap['lat'] as num).toDouble() : 0.0,
          lng: (endLocationMap['lng'] is num) ? (endLocationMap['lng'] as num).toDouble() : 0.0,
          placeId: endLocationMap['placeId'] ?? '',
        );
      } else {
        endLocation = Address.empty();
        print('Warning: end_location not found or invalid format, using empty address');
      }
    } catch (e) {
      print('Error parsing end_location: $e');
      endLocation = Address.empty();
    }

    // Parse waypoints array with error handling
    List<Address> waypoints = [];
    try {
      if (data['waypoints'] is List) {
        List waypointsList = data['waypoints'] as List;
        for (var wp in waypointsList) {
          if (wp is Map) {
            waypoints.add(Address(
              formattedAddress: wp['formattedAddress'] ?? '',
              lat: (wp['lat'] is num) ? (wp['lat'] as num).toDouble() : 0.0,
              lng: (wp['lng'] is num) ? (wp['lng'] as num).toDouble() : 0.0,
              placeId: wp['placeId'] ?? '',
            ));
          }
        }
      }
    } catch (e) {
      print('Error parsing waypoints: $e');
    }

    // Parse distance object with error handling
    Distance distance;
    try {
      if (data['distance'] is Map) {
        Map<String, dynamic> distanceMap = data['distance'] as Map<String, dynamic>;
        distance = Distance(
          text: distanceMap['text'] ?? '0 km',
          value: (distanceMap['value'] is num) ? (distanceMap['value'] as num).toInt() : 0,
        );
      } else {
        distance = Distance(text: '0 km', value: 0);
        print('Warning: distance not found or invalid format, using default');
      }
    } catch (e) {
      print('Error parsing distance: $e');
      distance = Distance(text: '0 km', value: 0);
    }

    // Parse duration object with error handling
    TravelDuration duration;
    try {
      if (data['duration'] is Map) {
        Map<String, dynamic> durationMap = data['duration'] as Map<String, dynamic>;
        duration = TravelDuration(
          text: durationMap['text'] ?? '0 min',
          value: (durationMap['value'] is num) ? (durationMap['value'] as num).toInt() : 0,
        );
      } else {
        duration = TravelDuration(text: '0 min', value: 0);
        print('Warning: duration not found or invalid format, using default');
      }
    } catch (e) {
      print('Error parsing duration: $e');
      duration = TravelDuration(text: '0 min', value: 0);
    }

    return RouteHistory(
      id: doc.id,
      startLocation: startLocation,
      endLocation: endLocation,
      waypoints: waypoints,
      distance: distance,
      duration: duration,
      createdAt: createdAt,
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