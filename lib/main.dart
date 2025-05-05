// Better approach for main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:project_navigo/services/user_provider.dart';
import 'package:project_navigo/themes/app_theme.dart';
import 'package:project_navigo/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/screens/authentication/splash_screen.dart';
import 'services/service_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyBocnJgrDPDhhMcAf6CUoi-lXVLkIILdrc",
      appId: "1:708119345203:android:c1705ab50c12e6b1950b46",
      messagingSenderId: "708119345203",
      projectId: "project-navigo",
      // and any other required fields
    ),
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: ServiceProvider(
        child: NaviGoApp(),
      ),
    ),
  );
}

class NaviGoApp extends StatelessWidget {
  const NaviGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the theme from the provider
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'NaviGo',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      // Set the SplashScreen as the initial route
      home: const AppInitializer(child: SplashScreen()),
      navigatorKey: navigatorKey,
    );
  }
}

// New widget to handle app initialization
class AppInitializer extends StatefulWidget {
  final Widget child;

  const AppInitializer({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to ensure widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
    });
  }

  Future<void> _initializeUserData() async {
    if (mounted) {
      try {
        // Access the UserProvider and load data if user is logged in
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.loadUserData();
        print('User data initialized at app startup');
      } catch (e) {
        print('Error initializing user data: $e');
      }

      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // We can show a loader here if needed while initializing
    // but for now we'll just return the child since splash screen already serves as a load screen
    return widget.child;
  }
}