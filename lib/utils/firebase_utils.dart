// lib/services/utils/firebase_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Utility methods for Firebase operations
class FirebaseUtils {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Configure Firestore for offline capability
  void configureFirestore() {
    _firestore.settings = Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  /// Safely execute a Firebase operation with consistent error handling
  ///
  /// This wrapper provides standardized error handling for Firebase operations.
  /// It logs errors, reports to Crashlytics, and transforms Firebase exceptions
  /// into more user-friendly messages.
  Future<T> safeOperation<T>(
      Future<T> Function() operation,
      String operationName
      ) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      print('Error in $operationName: $e');

      // Log to Crashlytics if available
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace, reason: operationName);
      } catch (_) {
        // Crashlytics might not be initialized in debug mode
      }

      // Provide helpful error messages based on Firebase error codes
      if (e is FirebaseException) {
        switch (e.code) {
          case 'permission-denied':
            throw Exception('You don\'t have permission to perform this action');
          case 'not-found':
            throw Exception('The requested data was not found');
          case 'already-exists':
            throw Exception('This data already exists');
          case 'network-request-failed':
            throw Exception('Network error. Please check your connection');
          case 'unavailable':
            throw Exception('Service temporarily unavailable. Please try again later');
          default:
            throw Exception('Firebase error: ${e.message}');
        }
      }

      // For other errors, provide a generic message
      throw Exception('An error occurred while $operationName');
    }
  }
}