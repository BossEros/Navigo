import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:project_navigo/screens/login_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:project_navigo/themes/app_typography.dart';

void main() {
  runApp(NaviGoApp());
}

class NaviGoApp extends StatelessWidget {
  const NaviGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaviGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: IntroScreen(),
    );
  }
}

class IntroScreen extends StatefulWidget {
  // Add parameter to allow starting at location page
  final bool startAtLocationPage;

  const IntroScreen({
    super.key,
    this.startAtLocationPage = false,
  });

  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final PageController _controller;
  int _currentPage = 0;
  bool _isRequestingPermission = false;
  bool _locationPermissionGranted = false;

  List<Map<String, String>> introData = [
    {
      "title": "NaviGo",
      "subtitle": "Your smart, real-time navigation assistant",
      "image": "assets/logo.png",
      "buttonText": "Get Started",
    },
    {
      "title": "Stay ahead with real-time updates",
      "image": "assets/real_time.gif",
      "buttonText": "Next",
    },
    {
      "title": "Customized navigation",
      "image": "assets/custom_navigation.gif",
      "buttonText": "Next",
    },
    {
      "title":
      "Navigate with options to reduce fuel consumption and carbon emissions.",
      "image": "assets/setting_lp.gif",
      "buttonText": "Next",
    },
    {
      "title": "Location Access",
      "image": "assets/location.gif",
      "subtitle": "To guide you effectively, allow us to access your location",
      "buttonText": "Allow",
      "isLocationAccessPage": "true",
    },
    {
      "title": "Let's Go!",
      "image": "assets/car.gif",
      "buttonText": "Start Exploring",
    },
  ];

  @override
  void initState() {
    super.initState();

    // Initialize controller with initial page based on startAtLocationPage
    if (widget.startAtLocationPage) {
      // Find the index of the location access page
      int locationPageIndex = 4; // Default to the 5th page (index 4)

      for (int i = 0; i < introData.length; i++) {
        if (introData[i]['isLocationAccessPage'] == "true") {
          locationPageIndex = i;
          break;
        }
      }

      _controller = PageController(initialPage: locationPageIndex);
      _currentPage = locationPageIndex;
    } else {
      _controller = PageController();
      _currentPage = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < introData.length - 1) {
      _controller.animateToPage(
        _currentPage + 1,
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      // If we're on the last page, go to login instead of cycling through pages
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _skipIntro() {
    // Find the index of the location access page
    int locationPageIndex = -1;
    for (int i = 0; i < introData.length; i++) {
      if (introData[i]['isLocationAccessPage'] == "true") {
        locationPageIndex = i;
        break;
      }
    }

    // Navigate to the location access page (or last page if not found)
    if (locationPageIndex != -1) {
      _controller.animateToPage(
        locationPageIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      // Fallback to original behavior if location page not found
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isRequestingPermission = true;
    });

    try {
      // First check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled
        if (mounted) {
          setState(() {
            _isRequestingPermission = false;
          });

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) => AlertDialog(
              title: Text(
                'Location Services Disabled',
                style: TextStyle(color: Colors.black87),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please enable location services to use navigation features.',
                    style: TextStyle(color: Colors.black87),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Without location services, Navigo won\'t be able to:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildFeatureItem(Icons.navigation, 'Provide turn-by-turn navigation'),
                  _buildFeatureItem(Icons.route, 'Calculate optimal routes'),
                  _buildFeatureItem(Icons.traffic, 'Alert you about traffic conditions'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _nextPage(); // Still allow to continue without location
                  },
                  child: Text(
                    'CONTINUE ANYWAY',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Open location settings if possible
                    if (!kIsWeb) {
                      Geolocator.openLocationSettings();
                    }
                    // We don't move to next page here since user needs to enable location first
                  },
                  child: Text('OPEN SETTINGS', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission - This works on web and will show the browser's
        // permission dialog on web platforms
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          // Permission denied
          if (mounted) {
            setState(() {
              _isRequestingPermission = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Location permission is needed for navigation',
                  style: TextStyle(color: Colors.white), // Snackbar always uses white text
                ),
                action: SnackBarAction(
                  label: 'Try Again',
                  onPressed: _requestLocationPermission,
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are permanently denied
        if (mounted) {
          setState(() {
            _isRequestingPermission = false;
          });

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) => AlertDialog(
              title: Text(
                'Location Permission Required',
                style: TextStyle(color: Colors.black87),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location permissions are permanently denied. Please enable them in device settings to use all navigation features.',
                    style: TextStyle(color: Colors.black87),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Navigation features that require location:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildFeatureItem(Icons.my_location, 'Real-time position tracking'),
                  _buildFeatureItem(Icons.directions, 'Turn-by-turn directions'),
                  _buildFeatureItem(Icons.alt_route, 'Route recalculation'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _nextPage(); // Still allow to continue without location
                  },
                  child: Text(
                    'CONTINUE ANYWAY',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (!kIsWeb) {
                      Geolocator.openAppSettings();
                    }
                    // We don't move to next page since user needs to change settings first
                  },
                  child: Text('OPEN SETTINGS', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
        return;
      }

      // If we get here, permission is granted
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
          _locationPermissionGranted = true;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permission granted',
              style: TextStyle(color: Colors.white), // Snackbar always uses white text
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Try to get location to ensure the permission is working
        try {
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          );
        } catch (e) {
          // Just log if there's an error getting position
          print('Error getting position: $e');
        }

        // Move to next page
        _nextPage();
      }
    } catch (e) {
      // Handle errors and continue
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error accessing location: $e',
              style: TextStyle(color: Colors.white), // Snackbar always uses white text
            ),
            action: SnackBarAction(
              label: 'Try Again',
              onPressed: _requestLocationPermission,
            ),
          ),
        );

        // Continue anyway after error
        _nextPage();
      }
    }
  }

  // Helper widget to display feature items in dialogs
  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Keep background white
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: introData.length,
            itemBuilder: (context, index) => IntroContent(
              title: introData[index]['title'],
              subtitle: introData[index]['subtitle'],
              image: introData[index]['image'],
              buttonText: introData[index]['buttonText'],
              onNext: introData[index]['isLocationAccessPage'] == "true"
                  ? _requestLocationPermission
                  : _nextPage,
              isFirstPage: index == 0,
              isLocationAccessPage: introData[index]['isLocationAccessPage'] == "true",
              onDenyLocation: _showLocationImportanceDialog,
              isRequestingPermission: _isRequestingPermission,
            ),
          ),

          if (_currentPage != 0 && _currentPage != introData.length - 1 && introData[_currentPage]['isLocationAccessPage'] != "true") // Hide Skip on First Page
            Positioned(
              top: 40,
              right: 20,
              child: TextButton(
                onPressed: _skipIntro,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Skip",
                      style: AppTypography.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black, // Always black
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.black, // Always black
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          if (_currentPage != 0 && _currentPage != introData.length - 1 && introData[_currentPage]['isLocationAccessPage'] != "true") //hide page control
            Positioned(
              bottom: 80 + MediaQuery.of(context).viewInsets.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _controller,
                  count: introData.length,
                  effect: WormEffect(
                    dotHeight: 10,
                    dotWidth: 10,
                    activeDotColor: Colors.blue,
                    dotColor: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Enhanced dialog shown when user denies location permission
  void _showLocationImportanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Wrap( // Use Wrap instead of Row to handle overflow
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8, // Add spacing between items
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            Text(
              'Location Enhances Navigation',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87, // Always black
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Navigo works best with location access. Without it, you\'ll miss out on:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87, // Always black
              ),
            ),
            SizedBox(height: 16),
            _buildFeatureItem(Icons.my_location, 'Real-time position tracking'),
            _buildFeatureItem(Icons.navigation, 'Turn-by-turn directions'),
            _buildFeatureItem(Icons.traffic, 'Live traffic updates'),
            _buildFeatureItem(Icons.electric_car, 'Suggested routes based on road conditions'),
            SizedBox(height: 12),
            Text(
              'You can always enable location permissions later in Settings.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: Colors.grey[700], // Slightly lighter but still dark
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _nextPage(); // Continue anyway
            },
            child: Text(
              'Continue Without Location',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _requestLocationPermission(); // Try again
            },
            child: Text('Grant Permission', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class IntroContent extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? image;
  final String? buttonText;
  final VoidCallback onNext;
  final bool isFirstPage;
  final bool isLocationAccessPage;
  final VoidCallback? onDenyLocation;
  final bool isRequestingPermission;

  const IntroContent({
    super.key,
    this.title,
    this.subtitle,
    this.image,
    this.buttonText,
    required this.onNext,
    required this.isFirstPage,
    this.isLocationAccessPage = false,
    this.onDenyLocation,
    this.isRequestingPermission = false,
  });

  @override
  Widget build(BuildContext context) {
    // Special UI for the location permission page
    if (isLocationAccessPage) {
      return Container(
        color: Colors.white, // Keep background white
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Location animation/image
              if (image != null)
                Image.asset(image!, width: 150, height: 150, fit: BoxFit.contain),
              SizedBox(height: 24),

              // Title with icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, color: Colors.blue, size: 28),
                  SizedBox(width: 8),
                  if (title != null)
                    Text(
                      title!,
                      style: AppTypography.onboardingTitle.copyWith(
                        color: Colors.black, // Always black
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),

              SizedBox(height: 16),

              // Enhanced subtitle explaining why location is needed
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.onboardingDescription.copyWith(
                    color: Colors.black, // Always black
                  ),
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: 8),

              // Location features list
              Container(
                margin: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3))
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Location enables Navigo to:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black, // Always black
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildFeatureRow(Icons.navigation, "Provide turn-by-turn directions"),
                    SizedBox(height: 8),
                    _buildFeatureRow(Icons.traffic, "Alert you about traffic conditions"),
                    SizedBox(height: 8),
                    _buildFeatureRow(Icons.speed, "Estimate arrival times accurately"),
                    SizedBox(height: 8),
                    _buildFeatureRow(Icons.pin_drop, "Show nearby places and services"),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Permission buttons
              isRequestingPermission
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                children: [
                  ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4169E1),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: Size(250, 50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(buttonText ?? "Allow Location", style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Icon(Icons.location_on),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  TextButton(
                    onPressed: onDenyLocation ?? () {},
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: Text(
                        "Not Now",
                        style: TextStyle(color: Colors.grey[700])
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "You can change this later in app settings",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Regular intro page layout for non-location pages
    return Container(
      color: Colors.white, // Keep background white
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (image != null)
              Image.asset(image!, width: 250, height: 250, fit: BoxFit.contain),
            SizedBox(height: 20),
            if (title != null)
              Text(
                title!,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Always black
                ),
                textAlign: TextAlign.center,
              ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black, // Always black
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4169E1),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                  buttonText ?? "Next",
                  style: AppTypography.onboardingButton
              ),
            ),
            if (isLocationAccessPage)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: TextButton(
                  onPressed: onDenyLocation ?? () {},
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  child: Text("Deny", style: TextStyle(color: Colors.black)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper method to build feature rows in the location permission page
  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: Colors.black, // Always black
            ),
          ),
        ),
      ],
    );
  }
}