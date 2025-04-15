import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_navigo/models/recent_location.dart';
import 'package:project_navigo/services/utils/firebase_utils.dart';

class RecentLocationsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseUtils _firebaseUtils = FirebaseUtils();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get recent locations for the current user
  Future<List<RecentLocation>> getRecentLocations({int limit = 7}) async {
    return _firebaseUtils.safeOperation(() async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      print('Fetching recent locations for user: ${currentUser.uid}, limit: $limit');

      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('recent_locations')
          .orderBy('accessed_at', descending: true)
          .limit(limit)
          .get();

      print('Found ${querySnapshot.docs.length} recent locations');

      return querySnapshot.docs
          .map((doc) => RecentLocation.fromFirestore(doc))
          .toList();
    }, 'getRecentLocations');
  }

  // Add or update a recent location
  Future<void> addRecentLocation({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    String? iconType,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Reference to the collection
      final recentLocationsRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('recent_locations');

      // Check if this location already exists
      final existing = await recentLocationsRef
          .where('place_id', isEqualTo: placeId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update the timestamp of the existing location
        await recentLocationsRef.doc(existing.docs.first.id).update({
          'accessed_at': FieldValue.serverTimestamp(),
          'name': name, // Update name in case it changed
          'address': address, // Update address in case it changed
        });
        print('Updated existing recent location: $name');
      } else {
        // Add new location
        final newLocation = RecentLocation(
          id: '', // Will be set by Firestore
          placeId: placeId,
          name: name,
          address: address,
          lat: lat,
          lng: lng,
          accessedAt: DateTime.now(),
          iconType: iconType,
        );

        await recentLocationsRef.add(newLocation.toMap());
        print('Added new recent location: $name');

        // Check if we need to remove old locations to maintain limit
        await _pruneOldLocations(currentUser.uid);
      }
    }, 'addRecentLocation');
  }

  // Remove old locations if count exceeds maximum
  Future<void> _pruneOldLocations(String userId, {int maxLocations = 20}) async {
    try {
      // Get count of locations
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_locations')
          .orderBy('accessed_at', descending: true)
          .get();

      if (querySnapshot.docs.length > maxLocations) {
        // Get locations to delete
        final locationsToDelete = querySnapshot.docs.sublist(maxLocations);

        // Delete old locations
        for (var doc in locationsToDelete) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('recent_locations')
              .doc(doc.id)
              .delete();
        }

        print('Pruned ${locationsToDelete.length} old recent locations');
      }
    } catch (e) {
      print('Error pruning old locations: $e');
      // Non-critical operation, so don't throw
    }
  }

  // Delete a specific recent location
  Future<void> deleteRecentLocation(String locationId) async {
    return _firebaseUtils.safeOperation(() async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('recent_locations')
          .doc(locationId)
          .delete();
    }, 'deleteRecentLocation');
  }

  // Clear all recent locations
  Future<void> clearAllRecentLocations() async {
    return _firebaseUtils.safeOperation(() async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      final querySnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('recent_locations')
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }, 'clearAllRecentLocations');
  }
}