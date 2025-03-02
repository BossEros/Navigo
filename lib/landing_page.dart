import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:project_navigo/login_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

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
  const IntroScreen({super.key});

  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

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
      "title": "A quick guide on how to use the application",
      "image": "assets/search_lp.png",
      "subtitle": "Step 1: Search for your destination",
      "buttonText": "Next",
    },
    {
      "image": "assets/destination_lp.png",
      "subtitle":
      "Step 2: Click the check ✓ button to confirm your destination",
      "buttonText": "Next",
    },
    {
      "image": "assets/transpo_lp.png",
      "subtitle": "Step 3: Choose your mode of transportation",
      "buttonText": "Next",
    },
    {
      "image": "assets/go_lp.png",
      "subtitle": "Step 4: Click the 'Start Session' & your route is ready!",
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

  void _nextPage() {
    if (_currentPage < introData.length - 1) {
      _controller.animateToPage(
        _currentPage + 1,
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } else {
      _skipIntro();
    }
  }

  void _skipIntro() {
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

  Future<void> _requestLocationPermission() async {
    // First check if location service is enabled
    try {
      LocationPermission permission;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Location Services Disabled'),
            content: Text('Please enable location services to continue.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Check current permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission - This works on web and will show the browser's
      // permission dialog on web platforms
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        // Permission denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permission is needed for navigation')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text('Location Permission'),
            content: Text('Location permissions are permanently denied. Please enable in browser settings or app settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (!kIsWeb) {
                    Geolocator.openAppSettings();
                  }
                  Navigator.of(context).pop();
                },
                child: Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // If we get here, permission is granted
    if (mounted) {
      // Try to get location to ensure the permission is working
      try {
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        );
      } catch (e) {
        // Just continue if there's an error getting position
        print('Error getting position: $e');
      }

      // Move to next page
      _nextPage();
    }
    } catch (e) {
      // Handle errors and continue
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accessing location: $e')),
        );
        _nextPage(); // Continue anyway after error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
              onDenyLocation: () {
                // Show custom dialog explaining why location is important
                showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: Text('Location is Important'),
                    content: Text('NaviGo needs your location to provide turn-by-turn navigation. Without it, some features will be limited.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _nextPage(); // Continue anyway if they insist
                        },
                        child: Text('Continue without Location'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _requestLocationPermission(); // Try again
                        },
                        child: Text('Grant Access'),
                      ),
                    ],
                  ),
                );
              },
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.black,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          if (_currentPage != 0 && _currentPage != introData.length - 1 && introData[_currentPage]['isLocationAccessPage'] != "true") //hide page control
            Positioned(
              bottom: 40,
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
}

class IntroContent extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? image;
  final String? buttonText;
  final VoidCallback onNext;
  final bool isFirstPage;
  final bool isLocationAccessPage;

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
  });

  final VoidCallback? onDenyLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
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
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  subtitle!,
                  style: TextStyle(fontSize: 16),
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
              child: Text(buttonText ?? "Next", style: TextStyle(fontSize: 16)),
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
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Register")),
      backgroundColor: Colors.white,
      body: Center(
        child: Text("Registration Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}