import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/screens/hamburger_menu_screens/route-history_screen.dart';
import 'package:project_navigo/screens/hamburger_menu_screens/saved-location_screen.dart';
import 'package:project_navigo/themes/app_typography.dart';
import '../../main.dart';
import '../../widgets/profile_image.dart';
import 'profile.dart';
import 'settings.dart';
import 'package:project_navigo/services/user_provider.dart';
import 'package:project_navigo/services/auth_service.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:project_navigo/screens/login_screen.dart';

// Utility class for creating consistent menu icons
class MenuIcon {
  // Define standard size and color for all menu icons
  static const double iconSize = 22.0;
  static const Color iconColor = Colors.black87;

  static Widget profile() => FaIcon(FontAwesomeIcons.userCircle, size: iconSize, color: iconColor);
  static Widget route() => FaIcon(FontAwesomeIcons.route, size: iconSize, color: iconColor);
  static Widget saved() => FaIcon(FontAwesomeIcons.solidHeart, size: iconSize, color: iconColor);
  static Widget settings() => FaIcon(FontAwesomeIcons.gear, size: iconSize, color: iconColor);
  static Widget logout() => FaIcon(FontAwesomeIcons.rightFromBracket, size: iconSize, color: iconColor);
  static Widget shortcuts() => FaIcon(FontAwesomeIcons.star, size: iconSize, color: iconColor);
}

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
                // Updated icon for dialog
                FaIcon(FontAwesomeIcons.rightFromBracket, size: 32, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Confirm Log out?',
                  style: AppTypography.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Cancel',
                            style: AppTypography.textTheme.labelLarge?.copyWith(
                              color: Colors.black87,
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Log out',
                            style: AppTypography.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
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

          // Username and email with dynamic values and typography
          Text(
            username, // Dynamic username from Firestore
            style: AppTypography.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email, // Dynamic email from Firestore
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 30),

          /// Menu List with clickable options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                buildListTile(
                  MenuIcon.profile(),
                  'View Profile',
                  context,
                  ProfileScreen(),
                ),
                const Divider(height: 1),
                buildListTile(
                  MenuIcon.route(),
                  'Your Route Data',
                  context,
                  RouteHistoryScreen(),
                ),
                const Divider(height: 1),
                buildListTile(
                  MenuIcon.saved(),
                  'Saved Locations',
                  context,
                  SavedLocationsScreen(),
                ),
                const Divider(height: 1),
                buildListTile(
                  MenuIcon.settings(),
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
                  leading: MenuIcon.logout(),
                  title: Text(
                    'Log out',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
      Widget icon,
      String title,
      BuildContext context,
      Widget page,
      ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      leading: icon,
      title: Text(
        title,
        style: AppTypography.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
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
