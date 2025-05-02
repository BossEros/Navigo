import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';
import 'package:project_navigo/utils/firebase_utils.dart';

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
        'onboarding_status': username.isNotEmpty && age > 0
            ? 'complete'
            : 'incomplete',
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
    try {
      // Get user data for cleanup (mainly for profile image)
      UserProfile? userProfile;
      try {
        userProfile = await getUserProfile(userId);
      } catch (e) {
        print('Could not retrieve user profile for deletion: $e');
        // Continue even if we can't get the profile
      }

      // 1. Delete all subcollections first
      await _deleteUserSubcollections(userId);

      // 2. Delete user profile document
      try {
        await _firestore.collection('users').doc(userId).delete();
        print('User profile document deleted successfully');
      } catch (e) {
        print('Error deleting user profile: $e');
        // This is a critical error - if we can't delete the profile, throw an exception
        throw Exception('Failed to delete user profile: $e');
      }

      // 3. Delete profile picture if it exists
      if (userProfile != null && userProfile.profileImagePath != null &&
          userProfile.profileImagePath!.isNotEmpty) {
        try {
          final storageRef = FirebaseStorage.instance.ref(
              userProfile.profileImagePath);
          await storageRef.delete();
          print('Profile image deleted successfully');
        } catch (e) {
          print('Error deleting profile image: $e');
          // Non-critical error - continue with deletion
        }
      }

      // 4. Delete any other files in user's storage folder
      try {
        final storageRef = FirebaseStorage.instance.ref().child(
            'users/$userId');
        final listResult = await storageRef.listAll();

        for (var item in listResult.items) {
          await item.delete();
        }
        print('All user storage files deleted successfully');
      } catch (e) {
        print('Error deleting user storage files: $e');
        // Non-critical error - continue with auth deletion
      }

      // 5. Finally, delete the Authentication account
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == userId) {
        try {
          await user.delete();
          print('User authentication account deleted successfully');
        } catch (e) {
          print('Error deleting authentication account: $e');

          // This is the most critical part - check for specific Firebase errors
          if (e is FirebaseAuthException) {
            if (e.code == 'requires-recent-login') {
              throw Exception(
                  'For security reasons, please log out and log back in before deleting your account.');
            }
          }

          throw Exception('Could not delete authentication account: $e');
        }
      } else {
        throw Exception(
            'Could not delete authentication account: User not logged in or UID mismatch');
      }
    } catch (e) {
      print('Error during account deletion: $e');
      rethrow; // Rethrow to allow UI to handle the error
    }
  }

  /// Helper method to delete all user subcollections
  Future<void> _deleteUserSubcollections(String userId) async {
    try {
      // Use batch operations for more efficient deletion
      final List<Future<void>> deletionTasks = [];

      // 1. Delete recent locations subcollection
      deletionTasks.add(_deleteCollection(
          _firestore.collection('users').doc(userId).collection('recent_locations'),
          'recent locations'
      ));

      // 2. Delete route history subcollection
      deletionTasks.add(_deleteCollection(
          _firestore.collection('users').doc(userId).collection('route_history'),
          'route history'
      ));

      // 3. Delete saved maps subcollection
      deletionTasks.add(_deleteCollection(
          _firestore.collection('users').doc(userId).collection('saved_maps'),
          'saved locations'
      ));

      // 4. Delete quick access shortcuts subcollection
      deletionTasks.add(_deleteCollection(
          _firestore.collection('users').doc(userId).collection('quick_access_shortcuts'),
          'quick access shortcuts'
      ));

      // Execute all deletion tasks
      await Future.wait(deletionTasks);
      print('All user subcollections deleted successfully');

    } catch (e) {
      print('Error deleting user subcollections: $e');
      // Continue with account deletion even if subcollection deletion fails
    }
  }

  /// Helper method to delete a collection
  Future<void> _deleteCollection(CollectionReference collection, String collectionName) async {
    try {
      final querySnapshot = await collection.get();

      if (querySnapshot.docs.isEmpty) {
        print('No $collectionName found to delete');
        return;
      }

      // Use a batched write to delete up to 500 documents at once
      final batch = _firestore.batch();
      int count = 0;

      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
        count++;
      }

      if (count > 0) {
        await batch.commit();
        print('Deleted $count $collectionName documents');
      }

    } catch (e) {
      print('Error deleting $collectionName: $e');
      // Don't throw here, as we want to continue with other deletions
    }
  }
}

