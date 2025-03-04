import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class GoogleApiServices {
  // Replace with your actual API key
  static const String _apiKey = 'AIzaSyAh29E6eO0XG7fci43OUpx1pw2dt1jWtKw';
  
  // Base URLs for different Google APIs
  static const String _placesBaseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _distanceMatrixBaseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String _geocodingBaseUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  
  // Places API - Autocomplete
  static Future<List<PlaceSuggestion>> getPlaceSuggestions(String query) async {
    if (query.length < 2) return [];
    
    final String url = 
        '$_placesBaseUrl/autocomplete/json?input=$query&types=establishment|address&language=en&key=$_apiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          // Parse suggestions
          List<PlaceSuggestion> suggestions = [];
          for (var prediction in data['predictions']) {
            suggestions.add(
              PlaceSuggestion(
                placeId: prediction['place_id'],
                description: prediction['description'],
                mainText: prediction['structured_formatting']['main_text'],
                secondaryText: prediction['structured_formatting']['secondary_text'] ?? '',
              )
            );
          }
          return suggestions;
        }
      }
      return [];
    } catch (e) {
      print('Error getting place suggestions: $e');
      return [];
    }
  }
  
  // Places API - Get place details
  static Future<Place?> getPlaceDetails(String placeId) async {
    final String url = 
        '$_placesBaseUrl/details/json?place_id=$placeId&fields=name,formatted_address,geometry,type&key=$_apiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final result = data['result'];
          final geometry = result['geometry']['location'];
          
          return Place(
            id: placeId,
            name: result['name'],
            address: result['formatted_address'],
            latLng: LatLng(
              geometry['lat'],
              geometry['lng'],
            ),
            types: List<String>.from(result['types']),
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting place details: $e');
      return null;
    }
  }
  
  // Directions API - Get route
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
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }
  
  // Distance Matrix API - Get distance and time between points
  static Future<DistanceMatrixResult?> getDistanceMatrix(
    List<LatLng> origins,
    List<LatLng> destinations, {
    String mode = 'driving',
    String? departureTime,
    bool avoidTolls = false,
    bool avoidHighways = false,
  }) async {
    if (origins.isEmpty || destinations.isEmpty) {
      return null;
    }
    
    // Build origins parameter
    String originsParam = 'origins=';
    for (int i = 0; i < origins.length; i++) {
      if (i > 0) originsParam += '|';
      originsParam += '${origins[i].latitude},${origins[i].longitude}';
    }
    
    // Build destinations parameter
    String destinationsParam = 'destinations=';
    for (int i = 0; i < destinations.length; i++) {
      if (i > 0) destinationsParam += '|';
      destinationsParam += '${destinations[i].latitude},${destinations[i].longitude}';
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
        '$_distanceMatrixBaseUrl?$originsParam'
        '&$destinationsParam'
        '&mode=$mode'
        '$avoid'
        '$departureTimeParam'
        '&key=$_apiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          List<DistanceMatrixRow> rows = [];
          
          for (var rowData in data['rows']) {
            List<DistanceMatrixElement> elements = [];
            
            for (var elementData in rowData['elements']) {
              if (elementData['status'] == 'OK') {
                elements.add(
                  DistanceMatrixElement(
                    distance: Distance(
                      text: elementData['distance']['text'],
                      value: elementData['distance']['value'],
                    ),
                    duration: Duration(
                      text: elementData['duration']['text'],
                      value: elementData['duration']['value'],
                    ),
                    status: elementData['status'],
                  )
                );
              } else {
                elements.add(
                  DistanceMatrixElement(
                    status: elementData['status'],
                  )
                );
              }
            }
            
            rows.add(DistanceMatrixRow(elements: elements));
          }
          
          return DistanceMatrixResult(
            originAddresses: List<String>.from(data['origin_addresses']),
            destinationAddresses: List<String>.from(data['destination_addresses']),
            rows: rows,
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting distance matrix: $e');
      return null;
    }
  }
  
  // Geocoding API - Convert address to coordinates
  static Future<LatLng?> geocodeAddress(String address) async {
    final String url = 
        '$_geocodingBaseUrl?address=${Uri.encodeComponent(address)}&key=$_apiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
      
      return null;
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }
  
  // Reverse Geocoding API - Convert coordinates to address
  static Future<String?> reverseGeocode(LatLng latLng) async {
    final String url = 
        '$_geocodingBaseUrl?latlng=${latLng.latitude},${latLng.longitude}&key=$_apiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      
      return null;
    } catch (e) {
      print('Error reverse geocoding: $e');
      return null;
    }
  }
}

// Model classes for Places API
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

// Model classes for Distance Matrix API
class DistanceMatrixResult {
  final List<String> originAddresses;
  final List<String> destinationAddresses;
  final List<DistanceMatrixRow> rows;
  
  DistanceMatrixResult({
    required this.originAddresses,
    required this.destinationAddresses,
    required this.rows,
  });
}

class DistanceMatrixRow {
  final List<DistanceMatrixElement> elements;
  
  DistanceMatrixRow({
    required this.elements,
  });
}

class DistanceMatrixElement {
  final Distance? distance;
  final Duration? duration;
  final String status;
  
  DistanceMatrixElement({
    this.distance,
    this.duration,
    required this.status,
  });
}
