import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_service.dart';

/// Handles all Firebase Authentication operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserService _userService;

  AuthService({required UserService userService}) : _userService = userService;

  // CURRENT USER

  /// Get the currently authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes for reactive UI updates
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // EMAIL/PASSWORD AUTHENTICATION

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Sign in error: $e');
      rethrow; // Let UI handle specific error cases
    }
  }

  /// Register with email and password
  Future<UserCredential> registerWithEmailPassword(String email, String password) async {
    try {
      // Create auth account
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create initial user profile
      await _userService.createInitialUserProfile(
        userId: credential.user!.uid,
        email: email,
      );

      // Optional: Send email verification
      await credential.user?.sendEmailVerification();

      return credential;
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // SOCIAL AUTHENTICATION

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger Google sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      // Get auth details from Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // If this is a new user, create their profile
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await _userService.createInitialUserProfile(
          userId: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
        );
      }

      return userCredential;
    } catch (e) {
      print('Google sign-in error: $e');
      rethrow;
    }
  }

  // ACCOUNT MANAGEMENT

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      // Sign out of Google if signed in with Google
      await _googleSignIn.signOut();
      // Sign out of Firebase
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }

  /// Update user email
  Future<void> updateEmail(String newEmail) async {
    try {
      if (currentUser == null) throw Exception('No authenticated user');
      await currentUser!.updateEmail(newEmail);
    } catch (e) {
      print('Update email error: $e');
      rethrow;
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      if (currentUser == null) throw Exception('No authenticated user');
      await currentUser!.updatePassword(newPassword);
    } catch (e) {
      print('Update password error: $e');
      rethrow;
    }
  }
}