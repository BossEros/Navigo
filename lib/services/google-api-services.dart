import 'dart:convert';
import 'package:project_navigo/config/config.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class GoogleApiServices {
  // Replace with your actual API key
  static const String _apiKey = AppConfig.apiKey;

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
        throw Exception(
            'Google Places API error: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      print('Error getting place suggestions: $e');
      throw Exception('Failed to get suggestions: $e');
    }
  }

  static Future<List<String>> getPlacePhotos(String placeId) async {
    try {
      // First fetch photo references
      final String url = '$_placesBaseUrl/places/$placeId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'photos'
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Future<String>> photoFutures = [];

        if (data.containsKey('photos') && data['photos'] is List && data['photos'].isNotEmpty) {
          // Create a list of future requests for parallel execution
          for (var photo in data['photos']) {
            if (photo.containsKey('name')) {
              photoFutures.add(getPlacePhoto(placeId, photo['name']));
            }
          }

          // Execute requests in parallel with a timeout
          final results = await Future.wait(
            photoFutures,
          );

          // Filter out empty results and return
          return results.where((url) => url.isNotEmpty).toList();
        }
      }
      return [];
    } catch (e) {
      print('Exception fetching place photos: $e');
      return [];
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
        final errorMessage = errorData['error']?['message'] ??
            'No error message';
        print(
            'Place Details API error: ${response.statusCode} - $errorMessage');
        throw Exception('Failed to get place details: $errorMessage');
      }
    } catch (e) {
      print('Error getting place details: $e');
      throw Exception('Failed to get place details: $e');
    }
  }

  // Potential implementation
  static Future<List<Place>> searchNearbyPlaces(LatLng location, {
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
          return data['places'].map<Place>((place) =>
              Place(
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
        throw Exception(
            'Nearby Places API error: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      throw Exception('Failed to get nearby places: $e');
    }
  }

  static Future<String> getPlacePhoto(String placeId, String photoId) async {
    // Determine the correct URL based on the format of photoId
    String baseUrl;

    // If photoId starts with 'places/', it's a full resource path
    if (photoId.startsWith('places/')) {
      baseUrl = '$_placesBaseUrl/$photoId/media';
    } else {
      // Assume it's just a photo ID and construct the full path
      baseUrl = '$_placesBaseUrl/places/$placeId/photos/$photoId/media';
    }

    // Create URI with query parameters for dimensions
    final Uri uri = Uri.parse(baseUrl).replace(queryParameters: {
      'max_width_px': '800',  // Reasonable width for mobile UI
      'max_height_px': '600'  // Reasonable height for mobile UI
    });

    final String url = uri.toString();
    print('Fetching photo media: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'X-Goog-Api-Key': _apiKey,
        },
      );

      print('Photo media API response status: ${response.statusCode}');

      // Check if we got a successful response
      if (response.statusCode == 200) {
        // The response is the actual image binary data, not JSON
        // Simply return the URL which can be used directly in Image.network
        return url;
      } else if (response.statusCode == 302 || response.statusCode == 301) {
        // Handle redirect
        final location = response.headers['location'];
        if (location != null && location.isNotEmpty) {
          print('Redirect to photo: $location');
          return location;
        }
        return '';
      } else {
        print('Error status: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
            print('Error message: $errorMessage');
          } catch (e) {
            print('Could not parse error response: ${response.body}');
          }
        }
        return '';
      }
    } catch (e) {
      print('Exception in getPlacePhoto: $e');
      print('Stack trace: ${StackTrace.current}');
      return '';
    }
  }

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
    // The Routes API uses a different endpoint
    final String url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    // Convert the travel mode to the correct format for Routes API
    String travelMode;
    switch (mode.toLowerCase()) {
      case 'driving':
        travelMode = 'DRIVE';
        break;
      case 'walking':
        travelMode = 'WALK';
        break;
      case 'bicycling':
        travelMode = 'BICYCLE';
        break;
      case 'transit':
      // Transit is not directly supported in the same way
        travelMode = 'DRIVE'; // Default fallback
        break;
      default:
        travelMode = 'DRIVE';
    }

    try {
      print('Requesting routes using Routes API with mode: $travelMode');

      // Build the request body
      Map<String, dynamic> requestBody = {
        "origin": {
          "location": {
            "latLng": {
              "latitude": origin.latitude,
              "longitude": origin.longitude
            }
          }
        },
        "destination": {
          "location": {
            "latLng": {
              "latitude": destination.latitude,
              "longitude": destination.longitude
            }
          }
        },
        "travelMode": travelMode,
        "routingPreference": "TRAFFIC_AWARE",
        "computeAlternativeRoutes": alternatives,
        "routeModifiers": {
          "avoidTolls": avoidTolls,
          "avoidHighways": avoidHighways
        },
        "languageCode": "en-US",
        "units": "IMPERIAL" // Change to METRIC if desired
      };

      // Add departure time if provided
      if (departureTime != null) {
        requestBody["departureTime"] = departureTime;
      }

      // Add waypoints if provided
      if (waypoints.isNotEmpty) {
        requestBody["intermediates"] = waypoints.map((waypoint) => {
          "location": {
            "latLng": {
              "latitude": waypoint.latitude,
              "longitude": waypoint.longitude
            }
          }
        }).toList();
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'routes.legs,routes.polyline,routes.duration,routes.distanceMeters,routes.travelAdvisory,routes.viewport'
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('routes') && data['routes'].isNotEmpty) {
          List<Route> routes = [];

          for (var routeData in data['routes']) {
            List<Leg> legs = [];

            // Handle the case where legs might be missing or empty
            final legsList = routeData['legs'] ?? [];

            for (var legData in legsList) {
              List<Step> steps = [];

              // Handle the case where steps might be missing or empty
              final stepsList = legData['steps'] ?? [];

              for (var stepData in stepsList) {
                // Safe navigation with null checks
                String instruction = '';
                if (stepData['navigationInstruction'] != null) {
                  instruction = stepData['navigationInstruction']['instructions'] ?? '';
                }

                // Safe distance handling
                int distanceMeters = stepData['distanceMeters'] ?? 0;

                // Safe duration handling
                String durationStr = stepData['duration'] ?? '0s';

                steps.add(
                    Step(
                      instruction: instruction,
                      distance: Distance(
                        text: _formatDistance(distanceMeters),
                        value: distanceMeters,
                      ),
                      duration: TravelDuration(
                        text: _formatDuration(durationStr),
                        value: _parseDuration(durationStr),
                      ),
                      startLocation: _getStepLocation(stepData, 'start'),
                      endLocation: _getStepLocation(stepData, 'end'),
                      polyline: stepData['polyline']?['encodedPolyline'] ?? '',
                      travelMode: stepData['travelMode'] ?? 'DRIVE',
                    )
                );
              }

              // Safe handling of leg distance and duration
              int legDistance = legData['distanceMeters'] ?? 0;
              String legDuration = legData['duration'] ?? '0s';

              legs.add(
                  Leg(
                    steps: steps,
                    distance: Distance(
                      text: _formatDistance(legDistance),
                      value: legDistance,
                    ),
                    duration: TravelDuration(
                      text: _formatDuration(legDuration),
                      value: _parseDuration(legDuration),
                    ),
                    startAddress: legData['startAddress'] ?? '',
                    endAddress: legData['endAddress'] ?? '',
                    startLocation: _getLegLocation(legData, 'start'),
                    endLocation: _getLegLocation(legData, 'end'),
                  )
              );
            }

            // Extract polyline points for the entire route with null safety
            List<LatLng> polylinePoints = [];
            String? encodedPolyline = routeData['polyline']?['encodedPolyline'];

            if (encodedPolyline != null) {
              try {
                PolylinePoints polylinePointsDecoder = PolylinePoints();
                List<PointLatLng> decodedPoints = polylinePointsDecoder.decodePolyline(encodedPolyline);

                for (var point in decodedPoints) {
                  polylinePoints.add(LatLng(point.latitude, point.longitude));
                }
              } catch (e) {
                print('Error decoding polyline: $e');
                // Use empty list if decoding fails
              }
            }

            // Create route with safe navigation
            routes.add(
                Route(
                  legs: legs,
                  polylinePoints: polylinePoints,
                  bounds: _getBoundsFromViewport(routeData['viewport']),
                  summary: routeData['description'] ?? '',
                  warnings: routeData['travelAdvisory'] != null ?
                  List<String>.from(routeData['travelAdvisory']['warnings'] ?? []) : [],
                )
            );
          }

          return RouteDetails(
            routes: routes,
          );
        } else {
          print('Routes API returned no routes');
          return null;
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            print('Error details: $errorData');
          } catch (e) {
            print('Could not parse error response: ${response.body}');
          }
        }
        return null;
      }
    } catch (e) {
      print('Error getting directions: $e');
      print('Stack trace: ${StackTrace.current}'); // Add stack trace for better debugging
      return null;
    }
  }

// Helper methods for parsing Routes API responses
  static String _formatDistance(int meters) {
    if (meters == null) return '0 m';

    if (meters < 1000) {
      return '$meters m';
    } else {
      double km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  static String _formatDuration(String durationStr) {
    if (durationStr == null) return '0 min';

    // Parse duration string like "1324s" or PT1H22M
    if (durationStr.endsWith('s')) {
      int seconds = int.tryParse(durationStr.substring(0, durationStr.length - 1)) ?? 0;
      if (seconds < 60) {
        return '$seconds sec';
      } else if (seconds < 3600) {
        int minutes = seconds ~/ 60;
        return '$minutes min';
      } else {
        int hours = seconds ~/ 3600;
        int minutes = (seconds % 3600) ~/ 60;
        return '$hours h $minutes min';
      }
    } else if (durationStr.startsWith('PT')) {
      // Handle ISO 8601 duration format
      final hours = RegExp(r'(\d+)H').firstMatch(durationStr)?.group(1);
      final minutes = RegExp(r'(\d+)M').firstMatch(durationStr)?.group(1);
      final seconds = RegExp(r'(\d+)S').firstMatch(durationStr)?.group(1);

      String result = '';
      if (hours != null) result += '$hours h ';
      if (minutes != null) result += '$minutes min';
      if (result.isEmpty && seconds != null) result = '$seconds sec';

      return result.trim();
    }

    return durationStr;
  }

  static int _parseDuration(String durationStr) {
    if (durationStr == null) return 0;

    // Convert duration string to seconds
    if (durationStr.endsWith('s')) {
      return int.tryParse(durationStr.substring(0, durationStr.length - 1)) ?? 0;
    } else if (durationStr.startsWith('PT')) {
      int seconds = 0;
      final hours = RegExp(r'(\d+)H').firstMatch(durationStr)?.group(1);
      final minutes = RegExp(r'(\d+)M').firstMatch(durationStr)?.group(1);
      final secs = RegExp(r'(\d+)S').firstMatch(durationStr)?.group(1);

      if (hours != null) seconds += int.parse(hours) * 3600;
      if (minutes != null) seconds += int.parse(minutes) * 60;
      if (secs != null) seconds += int.parse(secs);

      return seconds;
    }

    return 0;
  }

  static LatLng _getStepLocation(Map<String, dynamic> stepData, String type) {
    if (stepData == null) return const LatLng(0, 0);

    try {
      final locationData = stepData['${type}Location'];
      if (locationData != null && locationData['latLng'] != null) {
        final latLng = locationData['latLng'];
        return LatLng(
          latLng['latitude'] ?? 0,
          latLng['longitude'] ?? 0,
        );
      }
    } catch (e) {
      print('Error getting step location: $e');
    }

    return const LatLng(0, 0);
  }

  static LatLng _getLegLocation(Map<String, dynamic> legData, String type) {
    if (legData == null) return const LatLng(0, 0);

    try {
      final locationData = legData['${type}Location'];
      if (locationData != null && locationData['latLng'] != null) {
        final latLng = locationData['latLng'];
        return LatLng(
          latLng['latitude'] ?? 0,
          latLng['longitude'] ?? 0,
        );
      }
    } catch (e) {
      print('Error getting leg location: $e');
    }

    return const LatLng(0, 0);
  }

  static LatLngBounds _getBoundsFromViewport(Map<String, dynamic>? viewport) {
    if (viewport == null) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    try {
      final low = viewport['low'];
      final high = viewport['high'];

      if (low != null && high != null) {
        return LatLngBounds(
          southwest: LatLng(
            low['latitude'] ?? 0,
            low['longitude'] ?? 0,
          ),
          northeast: LatLng(
            high['latitude'] ?? 0,
            high['longitude'] ?? 0,
          ),
        );
      }
    } catch (e) {
      print('Error getting bounds: $e');
    }

    return LatLngBounds(
      southwest: const LatLng(0, 0),
      northeast: const LatLng(0, 0),
    );
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
  List<String> photoUrls = [];  // Add this field

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

class Route{
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
  final TravelDuration duration;
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
  final TravelDuration duration;
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

class TravelDuration {
  final String text;
  final int value;

  TravelDuration({
    required this.text,
    required this.value,
  });

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