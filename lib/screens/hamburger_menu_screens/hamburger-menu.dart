import 'package:project_navigo/screens/hamburger_menu_screens/route-history_screen.dart';
import 'package:project_navigo/screens/hamburger_menu_screens/saved-location_screen.dart';

import '../../widgets/profile_image.dart';
import 'profile.dart';
import 'settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_navigo/services/user_provider.dart';
import 'package:project_navigo/services/auth_service.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:project_navigo/screens/login_screen.dart';
import 'package:project_navigo/services/saved-map_services.dart';

class Hamburgmenu extends StatefulWidget {
  const Hamburgmenu({super.key});

  @override
  State<Hamburgmenu> createState() => _HamburgmenuState();
}

class _HamburgmenuState extends State<Hamburgmenu> {
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    // Using a post-frame callback ensures the widget tree is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      final userProvider = context.read<UserProvider>();

      // Skip loading if data is already present
      if (userProvider.userProfile == null) {
        await userProvider.loadUserData();
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Show error to user if needed
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  /// Function to navigate to a new page
  void navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  /// Function to navigate back to the map with a smooth transition
  void navigateBackToMap(BuildContext context) {
    try {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MyApp(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (e) {
      print('Navigation error: $e');
      // Fallback navigation
      Navigator.of(context).pop();
    }
  }

  /// Function to perform logout
  void performLogout(BuildContext context) async {
    try {
      // Get the required services
      final authService = context.read<AuthService>();
      final userProvider = context.read<UserProvider>();

      // Sign out the user from Firebase
      await authService.signOut();

      // Clear the cached user data
      userProvider.clearUserData();

      // Navigate to login screen with smooth transition
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      // Handle any errors during logout
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: $e')),
      );
    }
  }

  /// Function to show logout confirmation dialog
  void showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.white,
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon and title
                const Icon(Icons.logout, size: 32),
                const SizedBox(height: 12),
                const Text(
                  'Confirm Log out?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel button
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Log out button
                    SizedBox(
                      width: 120,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          performLogout(context);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Log out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the user provider to access user data
    final userProvider = Provider.of<UserProvider>(context);

    // Username and email with fallback values
    final username = userProvider.userProfile?.username ?? 'Guest User';
    final email = userProvider.userProfile?.email ?? 'No email available';
    final profileImageUrl = userProvider.userProfile?.profileImageUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          /// Header container with a gradient background
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                // Curved blue background
                ClipPath(
                  clipper: HeaderClipper(),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blue.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Close button
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black, size: 28),
                    onPressed: () {
                      // Use the smooth transition method to go back to the map
                      navigateBackToMap(context);
                    },
                  ),
                ),
                // Profile picture with image picker
                Align(
                  alignment: Alignment.center,
                  child: ProfileImageWidget(
                    imageUrl: profileImageUrl,
                    size: 100,
                  ),
                ),
              ],
            ),
          ),

          // Username and email with dynamic values
          Text(
            username, // Dynamic username from Firestore
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email, // Dynamic email from Firestore
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 30),

          /// Menu List with clickable options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                buildListTile(
                  Icons.person,
                  'View Profile',
                  context,
                  ProfileScreen(),
                ),
                const Divider(height: 1),
                buildListTile(
                  Icons.star_border,
                  'Saved Maps',
                  context,
                  const EmptyPage(),
                ),
                const Divider(height: 1),
                buildListTile(
                  Icons.map_outlined,
                  'Your Route Data',
                  context,
                  RouteHistoryScreen(),
                ),
                const Divider(height: 1),
                buildListTile(
                  Icons.star_border,
                  'Saved Locations',
                  context,
                  SavedLocationsScreen(), // Our new screen
                ),
                const Divider(height: 1),
                buildListTile(
                  Icons.settings,
                  'Settings',
                  context,
                  SettingsPage(),
                ),

                const Divider(height: 1),
                // Log out option with confirmation dialog
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  leading: const Icon(Icons.logout, size: 24, color: Colors.black),
                  title: const Text(
                    'Log out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    showLogoutConfirmDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Function to build each menu option as a clickable list tile
  Widget buildListTile(
      IconData icon,
      String title,
      BuildContext context,
      Widget page,
      ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      leading: Icon(icon, size: 24, color: Colors.black),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
    );
  }
}

/// Custom Clipper for Curved Gradient Background
class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class EmptyPage extends StatelessWidget {
  const EmptyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Page'), backgroundColor: Colors.blue),
      body: const Center(child: Text('This is an empty page')),
    );
  }
}