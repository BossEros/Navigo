import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:project_navigo/models/route_history.dart';
import 'package:project_navigo/models/route_history_filter.dart';
import 'package:project_navigo/utils/firebase_utils.dart';

import '../models/route_history_filter.dart';
import '../utils/firebase_utils.dart';

class RouteHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseUtils _firebaseUtils = FirebaseUtils();

  // Save completed route to Firestore
  Future<String> saveCompletedRoute({
    required String userId,
    required RouteHistory routeHistory,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      // Create a new document reference with auto-generated ID
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('route_history')
          .doc();

      // Create map with document ID included
      final routeData = routeHistory.toMap();

      // Add metadata for AI training
      routeData['dayOfWeek'] = routeHistory.createdAt.weekday; // 1-7 (Monday-Sunday)
      routeData['timeOfDay'] = _getTimeOfDay(routeHistory.createdAt);

      // Save to Firestore
      await docRef.set(routeData);

      return docRef.id;
    }, 'saveCompletedRoute');
  }

  // Get user's route history with pagination and filtering
  Future<List<RouteHistory>> getUserRouteHistory({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfterDocument,
    RouteHistoryFilter? filter,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      print('Fetching route history for user: $userId, limit: $limit');
      print('Applying filters: ${filter?.hasActiveFilters ?? false}');

      // IMPORTANT: Use snake_case for the field name to match your Firestore structure
      const String createdAtField = 'created_at';  // Changed from 'createdAt' to 'created_at'

      // Start with the base query
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('route_history')
          .orderBy(createdAtField, descending: true);

      // Apply filters if provided
      if (filter != null) {
        // Date range filter
        if (filter.dateRange != null) {
          final start = Timestamp.fromDate(filter.dateRange!.start);
          // End date needs to be set to the end of the day for inclusive filtering
          final end = Timestamp.fromDate(DateTime(
            filter.dateRange!.end.year,
            filter.dateRange!.end.month,
            filter.dateRange!.end.day,
            23, 59, 59, 999,
          ));

          query = query.where(createdAtField, isGreaterThanOrEqualTo: start)
              .where(createdAtField, isLessThanOrEqualTo: end);
        }

        // Travel mode filter
        if (filter.travelModes != null && filter.travelModes!.isNotEmpty) {
          // If there's only one travel mode, we can use a simple where clause
          if (filter.travelModes!.length == 1) {
            query = query.where('travel_mode', isEqualTo: filter.travelModes!.first);
          } else {
            // For multiple values, we need to use 'in' operator
            query = query.where('travel_mode', whereIn: filter.travelModes);
          }
        }

        // Traffic conditions filter
        if (filter.trafficConditions != null && filter.trafficConditions!.isNotEmpty) {
          // If there's only one condition, we can use a simple where clause
          if (filter.trafficConditions!.length == 1) {
            query = query.where('traffic_conditions', isEqualTo: filter.trafficConditions!.first);
          } else {
            // For multiple values, we need to use 'in' operator
            query = query.where('traffic_conditions', whereIn: filter.trafficConditions);
          }
        }

        // Note: Distance and duration filters need to be applied after fetching
        // because Firestore doesn't support range queries on multiple fields
      }

      // Apply pagination
      query = query.limit(limit);
      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      // Execute the query
      final querySnapshot = await query.get();
      print('Found ${querySnapshot.docs.length} route documents');

      // Process the results
      List<RouteHistory> routes = [];
      for (var doc in querySnapshot.docs) {
        try {
          final route = RouteHistory.fromFirestore(doc);

          // Apply distance filter if needed
          if (filter?.distanceRange != null) {
            final distance = route.distance.value.toDouble();
            if (distance < filter!.distanceRange!.start ||
                distance > filter.distanceRange!.end) {
              continue; // Skip this route
            }
          }

          // Apply duration filter if needed
          if (filter?.durationRange != null) {
            final duration = route.duration.value.toDouble();
            if (duration < filter!.durationRange!.start ||
                duration > filter.durationRange!.end) {
              continue; // Skip this route
            }
          }

          routes.add(route);
        } catch (e) {
          print('Error parsing route document ${doc.id}: $e');
          // Continue to next document rather than failing the whole operation
        }
      }

      return routes;
    }, 'getUserRouteHistory');
  }

  // Delete a route history entry
  Future<void> deleteRouteHistory({
    required String userId,
    required String routeId,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('route_history')
          .doc(routeId)
          .delete();
    }, 'deleteRouteHistory');
  }

  // Get frequently visited places for a user
  Future<List<Map<String, dynamic>>> getFrequentDestinations({
    required String userId,
    int limit = 5,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('route_history')
          .orderBy('createdAt', descending: true)
          .limit(100) // Get recent routes to analyze
          .get();

      // Count occurrences of each destination
      final Map<String, Map<String, dynamic>> destinations = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final endLocation = data['endLocation'] as Map<String, dynamic>;
        final placeId = endLocation['placeId'] as String;

        if (placeId.isNotEmpty) {
          if (!destinations.containsKey(placeId)) {
            destinations[placeId] = {
              'placeId': placeId,
              'address': endLocation['formattedAddress'],
              'lat': endLocation['lat'],
              'lng': endLocation['lng'],
              'count': 1,
              'lastVisited': data['createdAt'],
            };
          } else {
            destinations[placeId]!['count'] = destinations[placeId]!['count'] + 1;

            // Update last visited if more recent
            final lastVisited = destinations[placeId]!['lastVisited'] as Timestamp;
            final currentVisit = data['createdAt'] as Timestamp;

            if (currentVisit.compareTo(lastVisited) > 0) {
              destinations[placeId]!['lastVisited'] = currentVisit;
            }
          }
        }
      }

      // Sort by frequency (count) and return top results
      final sortedDestinations = destinations.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return sortedDestinations.take(limit).toList();
    }, 'getFrequentDestinations');
  }

  // Helper method to categorize time of day
  String _getTimeOfDay(DateTime dateTime) {
    final hour = dateTime.hour;

    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
  }
}