import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:project_navigo/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'screens/landing_page.dart';
import 'services/service_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
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
      home: IntroScreen(),
    );
  }
}
