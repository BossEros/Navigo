// Updated user_provider.dart with fixed precaching approach
import 'package:flutter/material.dart';
import 'package:project_navigo/models/user_profile.dart';
import 'package:project_navigo/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? _userProfile;
  final UserService _userService = UserService();
  bool _isLoading = false;
  String? _error;

  // Image preloading state
  bool _isProfileImagePreloaded = false;
  bool _isPreloadingImage = false;

  // Cached image provider
  NetworkImage? _profileImageProvider;

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isProfileImagePreloaded => _isProfileImagePreloaded;
  NetworkImage? get profileImageProvider => _profileImageProvider;

  // Load user data from Firestore
  Future<void> loadUserData() async {
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

      // Initialize image provider if URL is available
      if (_userProfile?.profileImageUrl != null &&
          _userProfile!.profileImageUrl!.isNotEmpty) {
        _initProfileImageProvider();
      }
    } catch (e) {
      _error = "Failed to load user data: $e";
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear user data on logout
  void clearUserData() {
    _userProfile = null;
    _isProfileImagePreloaded = false;
    _profileImageProvider = null;
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    return loadUserData();
  }

  // Add a method to update profile image
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

      // Reset image state and initialize with new URL
      _isProfileImagePreloaded = false;
      _profileImageProvider = null;
      _initProfileImageProvider();

      // Notify listeners to update UI
      notifyListeners();
    } catch (e) {
      print('Error updating profile image in provider: $e');
    }
  }

  // Initialize and prepare the image provider
  void _initProfileImageProvider() {
    if (_userProfile?.profileImageUrl == null ||
        _userProfile!.profileImageUrl!.isEmpty ||
        _isPreloadingImage) {
      return;
    }

    _isPreloadingImage = true;

    try {
      // Create the network image provider
      final imageUrl = _userProfile!.profileImageUrl!;
      _profileImageProvider = NetworkImage(imageUrl);

      // Pre-start the image loading in the background
      // This doesn't need a BuildContext
      final imageConfig = ImageConfiguration();
      final imageStream = _profileImageProvider!.resolve(imageConfig);

      late final ImageStreamListener listener;
      listener = ImageStreamListener(
            (ImageInfo info, bool _) {
          // Image is now in memory cache
          _isProfileImagePreloaded = true;
          _isPreloadingImage = false;
          imageStream.removeListener(listener);
          print('Profile image loaded in memory: $imageUrl');
          notifyListeners();
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          _isPreloadingImage = false;
          imageStream.removeListener(listener);
          print('Error loading profile image: $exception');
          notifyListeners();
        },
      );

      // Start listening to load the image
      imageStream.addListener(listener);
    } catch (e) {
      _isPreloadingImage = false;
      print('Error initializing profile image provider: $e');
      notifyListeners();
    }
  }
}