import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/screens/hamburger_menu_screens/route-history_screen.dart';
import 'package:project_navigo/screens/hamburger_menu_screens/saved-location_screen.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:project_navigo/themes/theme_provider.dart'; // Import the ThemeProvider
import '../../widgets/profile_image.dart';
import 'profile.dart';
import 'settings.dart';
import 'package:project_navigo/services/user_provider.dart';
import 'package:project_navigo/services/auth_service.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:project_navigo/screens/login_screen.dart';

// Utility class for creating consistent menu icons
class MenuIcon {
  // Define standard size for all menu icons
  static const double iconSize = 22.0;

  // Get the appropriate icon color based on theme
  static Color getIconColor(BuildContext context) {
    // Check if we're in dark mode using ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return themeProvider.isDarkMode ? Colors.white : Colors.black87;
  }

  // Theme-aware icon builders
  static Widget profile(BuildContext context) =>
      FaIcon(FontAwesomeIcons.userCircle, size: iconSize, color: getIconColor(context));

  static Widget route(BuildContext context) =>
      FaIcon(FontAwesomeIcons.route, size: iconSize, color: getIconColor(context));

  static Widget saved(BuildContext context) =>
      FaIcon(FontAwesomeIcons.solidHeart, size: iconSize, color: getIconColor(context));

  static Widget settings(BuildContext context) =>
      FaIcon(FontAwesomeIcons.gear, size: iconSize, color: getIconColor(context));

  static Widget logout(BuildContext context) =>
      FaIcon(FontAwesomeIcons.rightFromBracket, size: iconSize, color: getIconColor(context));
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
  /// This ensures theme provider context is properly passed to new screens
  void navigateTo(BuildContext context, Widget page) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => page,
          // Preserve the existing state by setting maintainState to true
          maintainState: true,
        )
    );
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
    // Get theme state from the provider to ensure we have the latest value
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final ThemeData theme = themeProvider.themeData;
    final bool isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: theme.cardColor,
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
                    color: theme.textTheme.headlineMedium?.color,
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
                          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          foregroundColor: isDarkMode ? Colors.white : Colors.black,
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
                              color: isDarkMode ? Colors.white : Colors.black87,
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

    // Get the theme provider to actively listen for theme changes
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);

    // Get the current theme
    final ThemeData theme = themeProvider.themeData;
    final bool isDarkMode = themeProvider.isDarkMode;

    // Username and email with fallback values
    final username = userProvider.userProfile?.username ?? 'Guest User';
    final email = userProvider.userProfile?.email ?? 'No email available';
    final profileImageUrl = userProvider.userProfile?.profileImageUrl;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
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
                        colors: [
                          theme.colorScheme.primary,
                          isDarkMode
                              ? theme.colorScheme.primary.withOpacity(0.7)
                              : Colors.blue.shade300
                        ],
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
                    icon: Icon(
                        Icons.close,
                        color: isDarkMode ? Colors.white : Colors.black,
                        size: 28
                    ),
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
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email, // Dynamic email from Firestore
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),

          /// Menu List with clickable options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                buildListTile(
                  MenuIcon.profile(context),
                  'View Profile',
                  context,
                  ProfileScreen(),
                ),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                buildListTile(
                  MenuIcon.route(context),
                  'Your Route Data',
                  context,
                  RouteHistoryScreen(),
                ),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                buildListTile(
                  MenuIcon.saved(context),
                  'Saved Locations',
                  context,
                  SavedLocationsScreen(),
                ),
                Divider(height: 1, color: isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                buildListTile(
                  MenuIcon.settings(context),
                  'Settings',
                  context,
                  SettingsPage(),
                ),

                Divider(height: 1, color: isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                // Log out option with confirmation dialog
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  leading: MenuIcon.logout(context),
                  title: Text(
                    'Log out',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  trailing: Icon(
                      Icons.chevron_right,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600]
                  ),
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

  // We've now replaced this with the updated MenuIcon class methods

  /// Function to build each menu option as a clickable list tile
  Widget buildListTile(
      Widget icon,
      String title,
      BuildContext context,
      Widget page,
      ) {
    // Get theme from the provider to ensure we respond to theme changes
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = themeProvider.themeData;
    final isDarkMode = themeProvider.isDarkMode;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      leading: icon,
      title: Text(
        title,
        style: AppTypography.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.textTheme.titleMedium?.color,
        ),
      ),
      trailing: Icon(
          Icons.chevron_right,
          color: isDarkMode ? Colors.grey[500] : Colors.grey[600]
      ),
      onTap: () {
        // Use navigateTo function for consistent navigation with theme persistence
        navigateTo(context, page);
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