import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_navigo/models/route_history.dart';
import 'package:project_navigo/services/utils/firebase_utils.dart';

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

  // Get user's route history with pagination
  Future<List<RouteHistory>> getUserRouteHistory({
    required String userId,
    int limit = 20,
    DocumentSnapshot? startAfterDocument,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('route_history')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => RouteHistory.fromFirestore(doc))
          .toList();
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