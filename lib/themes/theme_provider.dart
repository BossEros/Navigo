import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String THEME_KEY = 'isDarkMode';
  static const String TRAFFIC_KEY = 'isTrafficEnabled';

  bool _isDarkMode = false;
  bool _isTrafficEnabled = false; // Changed default to false per requirements

  bool get isDarkMode => _isDarkMode;
  bool get isTrafficEnabled => _isTrafficEnabled;

  ThemeData get themeData => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  // Initialize with the saved preference or default to light mode
  ThemeProvider() {
    _loadThemePreference();
    _loadTrafficPreference();
  }

  // Load the saved theme preference
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDarkMode = prefs.getBool(THEME_KEY) ?? false;

      if (savedDarkMode != _isDarkMode) {
        _isDarkMode = savedDarkMode;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }

  // Load the saved traffic preference
  Future<void> _loadTrafficPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTrafficEnabled = prefs.getBool(TRAFFIC_KEY) ?? false; // Default to false

      if (savedTrafficEnabled != _isTrafficEnabled) {
        _isTrafficEnabled = savedTrafficEnabled;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading traffic preference: $e');
    }
  }

  // Save the theme preference
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(THEME_KEY, _isDarkMode);
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  // Save the traffic preference
  Future<void> _saveTrafficPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(TRAFFIC_KEY, _isTrafficEnabled);
    } catch (e) {
      print('Error saving traffic preference: $e');
    }
  }

  // Set the dark mode value
  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      _saveThemePreference();
      notifyListeners();
    }
  }

  // Set the traffic enabled value
  void setTrafficEnabled(bool value) {
    if (_isTrafficEnabled != value) {
      _isTrafficEnabled = value;
      _saveTrafficPreference();
      notifyListeners();
    }
  }
}