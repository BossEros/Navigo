import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_navigo/utils/firebase_utils.dart';

/// Manages the user onboarding process
class OnboardingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseUtils _firebaseUtils = FirebaseUtils();

  // ONBOARDING STATUS

  /// Get the current onboarding status for a user
  Future<String> getUserOnboardingStatus(String userId) async {
    return _firebaseUtils.safeOperation(() async {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) {
        throw Exception('User profile not found');
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return data['onboarding_status'] ?? 'incomplete';
    }, 'getUserOnboardingStatus');
  }

  /// Check if user has completed onboarding
  Future<bool> isOnboardingComplete(String userId) async {
    final status = await getUserOnboardingStatus(userId);
    return status == 'complete';
  }

  // ONBOARDING STEPS

  /// Complete username setup (first onboarding step)
  Future<void> completeUsernameSetup({
    required String userId,
    required String username,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore.collection('users').doc(userId).update({
        'username': username,
        'onboarding_status': 'username_completed', // Mark username step as done
        'updated_at': FieldValue.serverTimestamp(),
      });
    }, 'completeUsernameSetup');
  }

  /// Complete date of birth setup (final onboarding step)
  Future<void> completeDobSetup({
    required String userId,
    required DateTime dateOfBirth,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      // Calculate age from DOB
      final now = DateTime.now();
      final age = now.year - dateOfBirth.year -
          (now.month > dateOfBirth.month ||
              (now.month == dateOfBirth.month && now.day >= dateOfBirth.day) ? 0 : 1);

      await _firestore.collection('users').doc(userId).update({
        'date_of_birth': Timestamp.fromDate(dateOfBirth),
        'age': age,
        'onboarding_status': 'complete', // Mark onboarding as complete
        'updated_at': FieldValue.serverTimestamp(),
      });
    }, 'completeDobSetup');
  }

  /// Skip onboarding process (for testing or special cases)
  Future<void> skipOnboarding(String userId) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore.collection('users').doc(userId).update({
        'onboarding_status': 'complete',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }, 'skipOnboarding');
  }

  /// Reset onboarding status (for testing or if user wants to redo onboarding)
  Future<void> resetOnboarding(String userId) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore.collection('users').doc(userId).update({
        'onboarding_status': 'incomplete',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }, 'resetOnboarding');
  }
}