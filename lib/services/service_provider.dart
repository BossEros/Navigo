// lib/services/service_provider.dart
import 'package:project_navigo/services/storage_service.dart';
import 'package:project_navigo/services/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'user_service.dart';
import 'onboarding_service.dart';
import 'utils/firebase_utils.dart';
import 'user_provider.dart';

/// Provides all services to the app using Provider pattern
class ServiceProvider extends StatelessWidget {
  final Widget child;

  const ServiceProvider({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Firebase utilities (independent)
        Provider<FirebaseUtils>(
          create: (_) => FirebaseUtils(),
          lazy: false, // Initialize immediately
        ),

        // User Service (no dependencies)
        Provider<UserService>(
          create: (_) => UserService(),
        ),

        // Onboarding Service (no dependencies)
        Provider<OnboardingService>(
          create: (_) => OnboardingService(),
        ),

        // Auth Service (depends on UserService)
        ProxyProvider<UserService, AuthService>(
          update: (_, userService, __) => AuthService(userService: userService),
        ),

        // Add UserProvider (Change Notifier)
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),

        // Storage Service (no dependencies)
        Provider<StorageService>(
          create: (_) => StorageService(),
        ),
      ],
      child: child,
    );
  }
}