// lib/providers/user_provider.dart
import 'package:flutter/material.dart';
import 'package:project_navigo/models/user_profile.dart';
import 'package:project_navigo/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProvider extends ChangeNotifier {
  UserProfile? _userProfile;
  final UserService _userService = UserService();
  bool _isLoading = false;
  String? _error;

  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    return loadUserData();
  }

}