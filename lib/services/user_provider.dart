import 'package:flutter/material.dart';
import 'package:project_navigo/models/user_profile.dart';
import 'package:project_navigo/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class UserProvider extends ChangeNotifier {
  UserProfile? _userProfile;
  final UserService _userService = UserService();
  bool _isLoading = false;
  String? _error;
  StreamSubscription<User?>? _authStateSubscription;
  bool _isInitialized = false;

  UserProvider() {
    // Set up auth state listener in constructor
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // User is logged in, load their data if not already loaded
        if (!_isInitialized) {
          loadUserData();
        }
      } else {
        // User is logged out, clear their data
        clearUserData();
      }
    });
  }

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserData() async {
    // Skip if already loading or if data is already loaded
    if (_isLoading || (_userProfile != null && _isInitialized)) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _error = "No user logged in";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _userProfile = await _userService.getUserProfile(currentUser.uid);
      _error = null;
      _isInitialized = true;  // Mark as initialized after successful load
    } catch (e) {
      _error = "Failed to load user data: $e";
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearUserData() {
    _userProfile = null;
    _isInitialized = false;
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    _isInitialized = false;
    return loadUserData();
  }

  Future<void> updateProfileImage(String imageUrl, String imagePath) async {
    if (_userProfile == null) return;

    try {
      // Update the in-memory profile
      _userProfile = UserProfile(
        id: _userProfile!.id,
        username: _userProfile!.username,
        email: _userProfile!.email,
        homeAddress: _userProfile!.homeAddress,
        workAddress: _userProfile!.workAddress,
        age: _userProfile!.age,
        dateOfBirth: _userProfile!.dateOfBirth,
        createdAt: _userProfile!.createdAt,
        updatedAt: DateTime.now(),
        isActive: _userProfile!.isActive,
        schemaVersion: _userProfile!.schemaVersion,
        onboardingStatus: _userProfile!.onboardingStatus,
        profileImageUrl: imageUrl,
        profileImagePath: imagePath,
        profileImageUpdatedAt: DateTime.now(),
      );

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      print('Error updating profile image in provider: $e');
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}