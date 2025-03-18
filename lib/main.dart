import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:project_navigo/screens/login_screen.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:project_navigo/screens/onboarding/dob_setup_screen.dart';
import 'package:project_navigo/screens/onboarding/username_setup_screen.dart';
import 'package:project_navigo/services/onboarding_service.dart';
import 'screens/landing_page.dart';
import 'services/firebase_options.dart';
import 'services/service_provider.dart';


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
      // Wrap your app with ServiceProvider
      ServiceProvider(
        child: NaviGoApp(),
      ),
    );
  }

  Future<Widget> getInitialScreen() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Not logged in, show login/register screen
      return LoginScreen();
    } else {
      // Check onboarding status
      try {
        String status = await OnboardingService().getUserOnboardingStatus(currentUser.uid);

        switch (status) {
          case 'incomplete':
          // First-time user, show username setup screen
            return UsernameSetupScreen();
          case 'username_completed':
          // Username done, show date of birth screen
            return DobSetupScreen();
          case 'complete':
          // Fully registered, show main app
            return MyApp();
          default:
          // Fallback to beginning of onboarding
            return UsernameSetupScreen();
        }
      } catch (e) {
        // Error fetching status, default to login
        await FirebaseAuth.instance.signOut();
        return LoginScreen();
      }
    }
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
