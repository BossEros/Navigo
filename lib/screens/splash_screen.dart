import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

      if (isFirstLaunch) {
        // If it's the first launch, navigate to the landing page
        // and update the first launch flag
        await prefs.setBool(_firstLaunchKey, false);
        _navigateToLandingPage();
      } else {
        // Check location permission status
        final hasLocationPermission = await _checkLocationPermission();

        if (hasLocationPermission) {
          // If location permission is granted, go directly to login
          _navigateToLoginPage();
        } else {
          // If location permission is not granted, go to the location access page
          _navigateToLocationAccessPage();
        }
      }
    } catch (e) {
      print('Error during app state check: $e');
      // In case of error, default to the landing page
      _navigateToLandingPage();
    }
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