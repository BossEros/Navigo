import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_navigo/models/saved_map.dart';
import 'package:project_navigo/services/utils/firebase_utils.dart';

/// Service class for managing saved maps/locations
class SavedMapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseUtils _firebaseUtils = FirebaseUtils();

  /// Save a location to the user's saved maps
  Future<String> saveLocation({
    required String userId,
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    String category = 'favorite',
    String? icon,
    String? notes,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      // Create a new document reference with auto-generated ID
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_maps')
          .doc();

      final savedMap = {
        'place_id': placeId,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'category': category,
        'icon': icon,
        'saved_at': FieldValue.serverTimestamp(),
        'notes': notes,
      };

      // Save to Firestore
      await docRef.set(savedMap);

      return docRef.id;
    }, 'saveLocation');
  }

  /// Check if a location is already saved
  Future<bool> isLocationSaved({
    required String userId,
    required String placeId,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_maps')
          .where('place_id', isEqualTo: placeId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    }, 'isLocationSaved');
  }

  /// Get all saved locations for a user
  Future<List<SavedMap>> getSavedLocations({
    required String userId,
    String? category,
    int limit = 20,
    DocumentSnapshot? startAfterDocument,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_maps')
          .orderBy('saved_at', descending: true);

      // Filter by category if provided
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      // Apply pagination
      query = query.limit(limit);
      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => SavedMap.fromFirestore(doc))
          .toList();
    }, 'getSavedLocations');
  }

  /// Delete a saved location
  Future<void> deleteSavedLocation({
    required String userId,
    required String savedMapId,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_maps')
          .doc(savedMapId)
          .delete();
    }, 'deleteSavedLocation');
  }

  /// Update a saved location (e.g., change category or add notes)
  Future<void> updateSavedLocation({
    required String userId,
    required String savedMapId,
    String? category,
    String? notes,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      Map<String, dynamic> updates = {};

      if (category != null) updates['category'] = category;
      if (notes != null) updates['notes'] = notes;

      // Only update if there are changes
      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('saved_maps')
            .doc(savedMapId)
            .update(updates);
      }
    }, 'updateSavedLocation');
  }

  /// Get a saved location by place ID
  Future<SavedMap?> getSavedLocationByPlaceId({
    required String userId,
    required String placeId,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_maps')
          .where('place_id', isEqualTo: placeId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return SavedMap.fromFirestore(querySnapshot.docs.first);
    }, 'getSavedLocationByPlaceId');
  }
}