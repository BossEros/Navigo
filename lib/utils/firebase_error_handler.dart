import 'package:firebase_auth/firebase_auth.dart';

/// Utility class for handling Firebase authentication errors
/// Converts technical Firebase error codes to user-friendly messages
class FirebaseErrorHandler {
  /// Converts Firebase authentication errors to user-friendly messages
  static String handleAuthError(dynamic error) {
    String errorMessage = 'An error occurred. Please try again.';

    if (error is FirebaseAuthException) {
      switch (error.code) {
      // Login errors
        case 'invalid-credential':
        case 'wrong-password':
          errorMessage = 'Your email or password is incorrect. Please check and try again.';
          break;
        case 'user-not-found':
          errorMessage = 'No account found with this email. Please create an account first.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed login attempts. Please try again later or reset your password.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid. Please enter a valid email.';
          break;

      // Registration errors
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Please try logging in instead.';
          break;
        case 'weak-password':
          errorMessage = 'This password is too weak. Please choose a stronger password.';
          break;

      // Network errors
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection and try again.';
          break;

      // General errors
        case 'operation-not-allowed':
          errorMessage = 'This operation is not allowed. Please contact support.';
          break;
        case 'account-exists-with-different-credential':
          errorMessage = 'An account already exists with the same email but different sign-in credentials.';
          break;

        default:
        // If we have a message from Firebase, use it, otherwise use generic message
          errorMessage = error.message != null && error.message.toString().isNotEmpty
              ? 'Authentication error: ${error.message}'
              : 'An unknown authentication error occurred. Please try again.';
      }
    }

    return errorMessage;
  }

  /// Determines if an error is related to password issues
  static bool isPasswordError(dynamic error) {
    if (error is FirebaseAuthException) {
      return ['wrong-password', 'weak-password', 'invalid-credential'].contains(error.code);
    }
    return false;
  }
}