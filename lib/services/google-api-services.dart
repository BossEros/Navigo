import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class GoogleApiServices {
  // Replace with your actual API key
  static const String _apiKey = 'AIzaSyAh29E6eO0XG7fci43OUpx1pw2dt1jWtKw';

  // Updated Base URLs for Google APIs
  static const String _placesBaseUrl = 'https://places.googleapis.com/v1';
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _distanceMatrixBaseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String _geocodingBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  // Updated Places API (New) - Autocomplete with improved error handling
  static Future<List<PlaceSuggestion>> getPlaceSuggestions(String query) async {
    if (query.length < 2) return [];

    // New Places API uses POST with JSON body
    final String url = '$_placesBaseUrl/places:searchText';

    try {
      print('Sending request to Places API (New): $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress'
        },
        body: json.encode({
          'textQuery': query,
          'languageCode': 'en'
        }),
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('places')) {
          // Parse suggestions from new API format
          List<PlaceSuggestion> suggestions = [];
          for (var place in data['places']) {
            suggestions.add(
                PlaceSuggestion(
                  placeId: place['id'],
                  description: place['formattedAddress'] ?? '',
                  mainText: place['displayName']?['text'] ?? '',
                  secondaryText: place['formattedAddress'] ?? '',
                )
            );
          }
          print('Found ${suggestions.length} suggestions');
          return suggestions;
        } else {
          print('Places API response contains no places');
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        print('Places API error: ${response.statusCode} - $errorMessage');
        throw Exception('Google Places API error: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      print('Error getting place suggestions: $e');
      throw Exception('Failed to get suggestions: $e');
    }
  }

  // Updated Places API (New) - Get place details
  static Future<Place?> getPlaceDetails(String placeId) async {
    final String url = '$_placesBaseUrl/places/$placeId';

    try {
      print('Fetching place details for ID: $placeId');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,types'
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        return Place(
          id: placeId,
          name: data['displayName']?['text'] ?? 'Unknown Place',
          address: data['formattedAddress'] ?? '',
          latLng: LatLng(
            data['location']['latitude'],
            data['location']['longitude'],
          ),
          types: data.containsKey('types')
              ? List<String>.from(data['types'])
              : ['unknown'],
        );
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'No error message';
        print('Place Details API error: ${response.statusCode} - $errorMessage');
        throw Exception('Failed to get place details: $errorMessage');
      }
    } catch (e) {
      print('Error getting place details: $e');
      throw Exception('Failed to get place details: $e');
    }
  }

  // Potential implementation
  static Future<List<Place>> searchNearbyPlaces(
      LatLng location, {
        double radiusInMeters = 1000,
        String? keyword,
        List<String>? types,
      }) async {
    final String url = '$_placesBaseUrl/places:searchNearby';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.types'
        },
        body: json.encode({
          'locationRestriction': {
            'circle': {
              'center': {
                'latitude': location.latitude,
                'longitude': location.longitude
              },
              'radius': radiusInMeters
            }
          },
          if (keyword != null) 'textQuery': keyword,
          if (types != null && types.isNotEmpty) 'includedTypes': types,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('places')) {
          return data['places'].map<Place>((place) => Place(
            id: place['id'],
            name: place['displayName']?['text'] ?? 'Unknown Place',
            address: place['formattedAddress'] ?? '',
            latLng: LatLng(
              place['location']['latitude'],
              place['location']['longitude'],
            ),
            types: place.containsKey('types')
                ? List<String>.from(place['types'])
                : ['unknown'],
          )).toList();
        }
        return [];
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Nearby Places API error: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      throw Exception('Failed to get nearby places: $e');
    }
  }

  static Future<String> getPlacePhoto(String placeId, String photoId) async {
    final String url = '$_placesBaseUrl/places/$placeId/photos/$photoId/media';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['photoUri']; // URL to the photo
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Place Photos API error: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      throw Exception('Failed to get place photo: $e');
    }
  }

  // Directions API - Get route (remains unchanged as it uses a different API)
  static Future<RouteDetails?> getDirections(
      LatLng origin,
      LatLng destination, {
        List<LatLng> waypoints = const [],
        String mode = 'driving',
        String? departureTime,
        bool alternatives = false,
        bool avoidTolls = false,
        bool avoidHighways = false,
      }) async {
    // Build waypoints parameter if provided
    String waypointsParam = '';
    if (waypoints.isNotEmpty) {
      waypointsParam = '&waypoints=';
      for (int i = 0; i < waypoints.length; i++) {
        if (i > 0) waypointsParam += '|';
        waypointsParam += '${waypoints[i].latitude},${waypoints[i].longitude}';
      }
    }

    // Build other parameters
    String avoid = '';
    if (avoidTolls) avoid += 'tolls|';
    if (avoidHighways) avoid += 'highways|';
    if (avoid.isNotEmpty) {
      avoid = '&avoid=${avoid.substring(0, avoid.length - 1)}';
    }

    String departureTimeParam = '';
    if (departureTime != null) {
      departureTimeParam = '&departure_time=$departureTime';
    }

    final String url =
        '$_directionsBaseUrl?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=$mode'
        '$waypointsParam'
        '$avoid'
        '$departureTimeParam'
        '&alternatives=${alternatives ? 'true' : 'false'}'
        '&key=$_apiKey';

    try {
      print('Requesting directions: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          List<Route> routes = [];

          for (var routeData in data['routes']) {
            List<Leg> legs = [];

            for (var legData in routeData['legs']) {
              List<Step> steps = [];

              for (var stepData in legData['steps']) {
                steps.add(
                    Step(
                      instruction: stepData['html_instructions'],
                      distance: Distance(
                        text: stepData['distance']['text'],
                        value: stepData['distance']['value'],
                      ),
                      duration: Duration(
                        text: stepData['duration']['text'],
                        value: stepData['duration']['value'],
                      ),
                      startLocation: LatLng(
                        stepData['start_location']['lat'],
                        stepData['start_location']['lng'],
                      ),
                      endLocation: LatLng(
                        stepData['end_location']['lat'],
                        stepData['end_location']['lng'],
                      ),
                      polyline: stepData['polyline']['points'],
                      travelMode: stepData['travel_mode'],
                    )
                );
              }

              legs.add(
                  Leg(
                    steps: steps,
                    distance: Distance(
                      text: legData['distance']['text'],
                      value: legData['distance']['value'],
                    ),
                    duration: Duration(
                      text: legData['duration']['text'],
                      value: legData['duration']['value'],
                    ),
                    startAddress: legData['start_address'],
                    endAddress: legData['end_address'],
                    startLocation: LatLng(
                      legData['start_location']['lat'],
                      legData['start_location']['lng'],
                    ),
                    endLocation: LatLng(
                      legData['end_location']['lat'],
                      legData['end_location']['lng'],
                    ),
                  )
              );
            }

            // Extract polyline points for the entire route
            List<LatLng> polylinePoints = [];
            PolylinePoints polylinePointsDecoder = PolylinePoints();
            List<PointLatLng> decodedPoints =
            polylinePointsDecoder.decodePolyline(routeData['overview_polyline']['points']);

            for (var point in decodedPoints) {
              polylinePoints.add(LatLng(point.latitude, point.longitude));
            }

            routes.add(
                Route(
                  legs: legs,
                  polylinePoints: polylinePoints,
                  bounds: LatLngBounds(
                    southwest: LatLng(
                      routeData['bounds']['southwest']['lat'],
                      routeData['bounds']['southwest']['lng'],
                    ),
                    northeast: LatLng(
                      routeData['bounds']['northeast']['lat'],
                      routeData['bounds']['northeast']['lng'],
                    ),
                  ),
                  summary: routeData['summary'],
                  warnings: List<String>.from(routeData['warnings']),
                )
            );
          }

          return RouteDetails(
            routes: routes,
          );
        } else {
          print('Directions API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
          return null;
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }
}

// Model classes
class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

class Place {
  final String id;
  final String name;
  final String address;
  final LatLng latLng;
  final List<String> types;

  Place({
    required this.id,
    required this.name,
    required this.address,
    required this.latLng,
    required this.types,
  });
}

// Model classes for Directions API
class RouteDetails {
  final List<Route> routes;

  RouteDetails({
    required this.routes,
  });
}

class Route {
  final List<Leg> legs;
  final List<LatLng> polylinePoints;
  final LatLngBounds bounds;
  final String summary;
  final List<String> warnings;

  Route({
    required this.legs,
    required this.polylinePoints,
    required this.bounds,
    required this.summary,
    required this.warnings,
  });
}

class Leg {
  final List<Step> steps;
  final Distance distance;
  final Duration duration;
  final String startAddress;
  final String endAddress;
  final LatLng startLocation;
  final LatLng endLocation;

  Leg({
    required this.steps,
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
    required this.startLocation,
    required this.endLocation,
  });
}

class Step {
  final String instruction;
  final Distance distance;
  final Duration duration;
  final LatLng startLocation;
  final LatLng endLocation;
  final String polyline;
  final String travelMode;

  Step({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.polyline,
    required this.travelMode,
  });
}

class Distance {
  final String text;
  final int value;

  Distance({
    required this.text,
    required this.value,
  });
}

class Duration {
  final String text;
  final int value;

  Duration({
    required this.text,
    required this.value,
  });
}