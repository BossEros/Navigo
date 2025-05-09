// Updated ThemeProvider with route preferences
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String THEME_KEY = 'isDarkMode';
  static const String TRAFFIC_KEY = 'isTrafficEnabled';
  static const String AVOID_TOLLS_KEY = 'avoidTolls';
  static const String AVOID_HIGHWAYS_KEY = 'avoidHighways';

  bool _isDarkMode = false;
  bool _isTrafficEnabled = true;
  bool _avoidTolls = false;
  bool _avoidHighways = false;

  bool get isDarkMode => _isDarkMode;
  bool get isTrafficEnabled => _isTrafficEnabled;
  bool get avoidTolls => _avoidTolls;
  bool get avoidHighways => _avoidHighways;

  ThemeData get themeData => _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  ThemeProvider() {
    _loadThemePreferences();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  Future<void> _loadThemePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load dark mode preference
      final savedDarkMode = prefs.getBool(THEME_KEY) ?? false;
      if (savedDarkMode != _isDarkMode) {
        _isDarkMode = savedDarkMode;
      }

      // Load traffic preference
      final savedTrafficEnabled = prefs.getBool(TRAFFIC_KEY) ?? true;
      if (savedTrafficEnabled != _isTrafficEnabled) {
        _isTrafficEnabled = savedTrafficEnabled;
      }

      // Load route preferences
      final savedAvoidTolls = prefs.getBool(AVOID_TOLLS_KEY) ?? false;
      if (savedAvoidTolls != _avoidTolls) {
        _avoidTolls = savedAvoidTolls;
      }

      final savedAvoidHighways = prefs.getBool(AVOID_HIGHWAYS_KEY) ?? false;
      if (savedAvoidHighways != _avoidHighways) {
        _avoidHighways = savedAvoidHighways;
      }

      notifyListeners();
    } catch (e) {
      print('Error loading theme preferences: $e');
    }
  }

  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(THEME_KEY, _isDarkMode);
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  Future<void> _saveTrafficPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(TRAFFIC_KEY, _isTrafficEnabled);
    } catch (e) {
      print('Error saving traffic preference: $e');
    }
  }

  Future<void> _saveAvoidTollsPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AVOID_TOLLS_KEY, _avoidTolls);
    } catch (e) {
      print('Error saving avoid tolls preference: $e');
    }
  }

  Future<void> _saveAvoidHighwaysPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AVOID_HIGHWAYS_KEY, _avoidHighways);
    } catch (e) {
      print('Error saving avoid highways preference: $e');
    }
  }

  void setDarkMode(bool value) {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      _saveThemePreference();
      notifyListeners();
    }
  }

  void setTrafficEnabled(bool value) {
    if (_isTrafficEnabled != value) {
      _isTrafficEnabled = value;
      _saveTrafficPreference();
      notifyListeners();
    }
  }

  void setAvoidTolls(bool value) {
    if (_avoidTolls != value) {
      _avoidTolls = value;
      _saveAvoidTollsPreference();
      notifyListeners();
    }
  }

  void setAvoidHighways(bool value) {
    if (_avoidHighways != value) {
      _avoidHighways = value;
      _saveAvoidHighwaysPreference();
      notifyListeners();
    }
  }
}