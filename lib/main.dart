import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:project_navigo/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
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
      home: const SplashScreen(),
      navigatorKey: navigatorKey,
    );
  }
}