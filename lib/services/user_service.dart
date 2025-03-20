// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import 'package:project_navigo/services/utils/firebase_utils.dart';

/// Manages user profiles in Firestore
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseUtils _firebaseUtils = FirebaseUtils();

  // PROFILE CREATION & RETRIEVAL

  /// Create initial minimal user profile after registration
  Future<void> createInitialUserProfile({
    required String userId,
    required String email,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      // Create minimal profile with empty/default values
      Address emptyAddress = Address(
        formattedAddress: '',
        lat: 0.0,
        lng: 0.0,
        placeId: '',
      );

      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'username': '', // Empty until completed in profile setup
        'home_address': emptyAddress.toMap(),
        'work_address': emptyAddress.toMap(),
        'age': 0, // Will be calculated from birth date later
        'date_of_birth': null, // Will be set during profile setup
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'is_active': true,
        'schema_version': 1,
        'onboarding_status': 'incomplete', // Track onboarding progress
      });
    }, 'createInitialUserProfile');
  }

  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String username,
    int age = 0,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      // Create a default empty address
      Address emptyAddress = Address(
        formattedAddress: '',
        lat: 0.0,
        lng: 0.0,
        placeId: '',
      );

      // Create the profile with all data at once
      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'username': username,
        'age': age,
        'home_address': emptyAddress.toMap(),
        'work_address': emptyAddress.toMap(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'is_active': true,
        'schema_version': 1,
        'onboarding_status': username.isNotEmpty && age > 0 ? 'complete' : 'incomplete',
      });
    }, 'createUserProfile');
  }

  /// Get user profile by ID
  Future<UserProfile> getUserProfile(String userId) async {
    return _firebaseUtils.safeOperation(() async {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) {
        throw Exception('User profile not found');
      }

      return UserProfile.fromFirestore(doc);
    }, 'getUserProfile');
  }

  // PROFILE UPDATES

  /// Update user profile fields
  Future<void> updateUserProfile({
    required String userId,
    String? username,
    Address? homeAddress,
    Address? workAddress,
    int? age,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      Map<String, dynamic> updates = {
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (username != null) updates['username'] = username;
      if (homeAddress != null) updates['home_address'] = homeAddress.toMap();
      if (workAddress != null) updates['work_address'] = workAddress.toMap();
      if (age != null) updates['age'] = age;

      await _firestore
          .collection('users')
          .doc(userId)
          .update(updates);
    }, 'updateUserProfile');
  }

  /// Update user profile picture
  Future<void> updateProfilePicture({
    required String userId,
    required String imageUrl,
    required String imagePath,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'profileImageUrl': imageUrl,
        'profileImagePath': imagePath,
        'profileImageUpdatedAt': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }, 'updateProfilePicture');
  }

  /// Update home address
  Future<void> updateHomeAddress({
    required String userId,
    required String formattedAddress,
    required double lat,
    required double lng,
    required String placeId,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      Address homeAddress = Address(
        formattedAddress: formattedAddress,
        lat: lat,
        lng: lng,
        placeId: placeId,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'home_address': homeAddress.toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }, 'updateHomeAddress');
  }

  /// Update work address
  Future<void> updateWorkAddress({
    required String userId,
    required String formattedAddress,
    required double lat,
    required double lng,
    required String placeId,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      Address workAddress = Address(
        formattedAddress: formattedAddress,
        lat: lat,
        lng: lng,
        placeId: placeId,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'work_address': workAddress.toMap(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }, 'updateWorkAddress');
  }

  // ACCOUNT MANAGEMENT

  /// Deactivate user account (soft delete)
  Future<void> deactivateAccount(String userId) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }, 'deactivateAccount');
  }

  /// Delete user account and profile data
  Future<void> deleteAccount(String userId) async {
    return _firebaseUtils.safeOperation(() async {
      // In a production app, you might want to:
      // 1. Delete other user-related data first (saved maps, routes, etc.)
      // 2. Create a deletion log for audit purposes
      // 3. Delete the Auth account

      // For Navigo college project, simply delete the profile
      await _firestore.collection('users').doc(userId).delete();

      // Note: This doesn't delete the Firebase Auth account
      // Ideally, also delete from Auth
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null && user.uid == userId) {
          await user.delete();
        }
      } catch (e) {
        print('Error deleting Auth account: $e');
        // Don't throw - we successfully deleted profile data
      }
    }, 'deleteAccount');
  }
}