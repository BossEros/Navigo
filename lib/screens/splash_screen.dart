import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_navigo/screens/landing_page.dart';
import 'package:project_navigo/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Keys for SharedPreferences
  static const String _firstLaunchKey = 'isFirstLaunch';

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    // Add a short delay to show splash screen
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    try {
      // Check if this is the first launch
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final bool isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;

      // Check if user is already logged in
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // User is already logged in, navigate to main app
        _navigateToMapScreen();
      } else if (isFirstLaunch) {
        // First launch flow
        await prefs.setBool(_firstLaunchKey, false);
        _navigateToLandingPage();
      } else {
        // Check location permission status
        final hasLocationPermission = await _checkLocationPermission();

        if (hasLocationPermission) {
          _navigateToLoginPage();
        } else {
          _navigateToLocationAccessPage();
        }
      }
    } catch (e) {
      print('Error during app state check: $e');
      _navigateToLandingPage();
    }
  }

  void _navigateToMapScreen() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyApp()),
    );
  }

  Future<bool> _checkLocationPermission() async {
    // First check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();

    // Return true only if permission is granted or grantedLimited
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void _navigateToLandingPage() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const IntroScreen()),
    );
  }

  void _navigateToLoginPage() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _navigateToLocationAccessPage() {
    if (!mounted) return;

    // Navigate to IntroScreen with a specific page index
    // The index should match the location access page in the intro slides
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const IntroScreen(startAtLocationPage: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/logo.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 24),
            // App name
            Text(
              'NaviGo',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4169E1),
              ),
            ),
            const SizedBox(height: 32),
            // Loading indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4169E1)),
            ),
          ],
        ),
      ),
    );
  }
}