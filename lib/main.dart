import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:project_navigo/screens/login_screen.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:project_navigo/services/onboarding_service.dart';
import 'package:project_navigo/themes/app_theme.dart';
import 'screens/landing_page.dart';
import 'services/firebase_options.dart';
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
    ServiceProvider(
      child: NaviGoApp(),
    ),
  );
}

class NaviGoApp extends StatelessWidget {
  const NaviGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaviGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: IntroScreen(),
    );
  }
}