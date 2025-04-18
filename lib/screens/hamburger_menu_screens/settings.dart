import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../themes/theme_provider.dart';
import '../login_screen.dart';
import 'faq_screen.dart';
import 'terms_of_service.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/themes/app_typography.dart'; // Import typography

void main() {
  runApp(NaviGoApp());
}

class NaviGoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NaviGo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        textTheme: AppTypography.textTheme, // Use the custom text theme
      ),
      home: SettingsPage(),
    );
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get the theme provider to access dark mode state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply theme-aware background color
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        // Apply theme-aware AppBar styling
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Settings',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            // Apply theme-aware text color
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        leading: IconButton(
          // Apply theme-aware icon color
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            // Apply theme-aware icon color
            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false, // Don't add padding at the top since AppBar already handles it
        bottom: true, // Add padding at the bottom to avoid navigation bar
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildSettingItem(
                    icon: Icons.accessibility_new,
                    title: "Accessibility",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AccessibilityPage(),
                        ),
                      );
                    },
                    isDarkMode: isDarkMode, // Pass theme state
                  ),
                  _buildSettingItem(
                    icon: Icons.help_outline,
                    title: "FAQ",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => FAQScreen()),
                      );
                    },
                    isDarkMode: isDarkMode, // Pass theme state
                  ),
                  _buildSettingItem(
                    icon: Icons.description_outlined,
                    title: "Terms of Service",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TermsOfServiceScreen(),
                        ),
                      );
                    },
                    isDarkMode: isDarkMode, // Pass theme state
                  ),
                  _buildSettingItem(
                    icon: Icons.privacy_tip_outlined,
                    title: "Privacy Policy",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivacyPolicyPage(),
                        ),
                      );
                    },
                    isDarkMode: isDarkMode, // Pass theme state
                  ),
                  _buildSettingItem(
                    icon: Icons.delete_outline,
                    title: "Delete Account",
                    onTap: () {
                      _showDeleteAccountDialog(context, isDarkMode);
                    },
                    isDestructive: true,
                    isDarkMode: isDarkMode, // Pass theme state
                  ),
                ],
              ),
            ),
            // Decorative wave - enhanced with gradient and theme-aware colors
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // Apply theme-aware gradient colors
                  colors: isDarkMode
                      ? [Colors.blue.shade800, Colors.blue.shade900]
                      : [Colors.blue.shade400, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(300),
                  topRight: Radius.circular(300),
                ),
                boxShadow: [
                  BoxShadow(
                    // Apply theme-aware shadow color
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.5)
                        : Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    required bool isDarkMode, // Add theme state parameter
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            icon,
            color: isDestructive ? Colors.red : Colors.blue.shade700,
            size: 24,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
          title: Text(
            title,
            style: AppTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              // Apply theme-aware text color
              color: isDestructive
                  ? Colors.red
                  : (isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            // Apply theme-aware icon color
            color: isDestructive
                ? Colors.red.withOpacity(0.5)
                : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        // Apply theme-aware divider color
        Divider(
            height: 1,
            indent: 24,
            endIndent: 24,
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200]
        ),
      ],
    );
  }
}

void _showDeleteAccountDialog(BuildContext context, bool isDarkMode) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // Apply theme-aware background color
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          "Delete Account Permanently?",
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This action cannot be undone. All your data will be permanently deleted, including:",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            _buildDeleteInfoItem(Icons.person, "Your profile information", isDarkMode),
            _buildDeleteInfoItem(Icons.route, "Your navigation history", isDarkMode),
            _buildDeleteInfoItem(Icons.map, "Your saved locations", isDarkMode),
            _buildDeleteInfoItem(Icons.photo, "Your profile picture", isDarkMode),
            SizedBox(height: 16),
            Text(
              "Are you sure you want to proceed?",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "CANCEL",
              style: AppTypography.textTheme.labelLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.grey[400] : Colors.grey[800],
              ),
            ),
          ),
          TextButton(
            onPressed: () => _proceedWithAccountDeletion(context),
            child: Text(
              "DELETE",
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}

void _proceedWithAccountDeletion(BuildContext context) async {
  await _performAccountDeletion(context);
}

Future<void> _performAccountDeletion(BuildContext context) async {
  // Get theme status for dialog styling
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final isDarkMode = themeProvider.isDarkMode;

  // This will help us navigate even after the user is signed out
  final navigatorKey = GlobalKey<NavigatorState>();
  BuildContext? dialogContext;

  // Show a loading dialog and save its context
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      dialogContext = context; // Save the dialog context
      return WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // Apply theme-aware background color
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Use theme-aware CircularProgressIndicator color
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    isDarkMode ? Colors.white : Colors.blue),
              ),
              SizedBox(height: 16),
              Text(
                "Deleting your account...",
                style: AppTypography.textTheme.bodyLarge?.copyWith(
                  // Apply theme-aware text color
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  try {
    // Get necessary services
    final userService = Provider.of<UserService>(context, listen: false);

    // Get current user ID before deletion
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('No user is currently logged in');
    }

    // Store the user ID since we'll lose access to currentUser after deletion
    final userId = currentUser.uid;

    // First, reauthenticate the user
    await _reauthenticateUser(context, isDarkMode);

    // Set a flag to track successful deletion
    bool deletionSuccessful = false;

    try {
      // Then perform the deletion
      await userService.deleteAccount(userId);
      deletionSuccessful = true;
    } finally {
      // Close the loading dialog regardless of success or failure
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }
    }

    print(deletionSuccessful);

    // If deletion was successful, show success message and navigate to login
    if (deletionSuccessful) {
      showDialog(
        context: context,
        barrierDismissible: false, // User must tap button to close
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            // Apply theme-aware background color
            backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
            title: Text(
              "Account Deleted Successfully",
              style: AppTypography.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your account and all associated data have been permanently deleted.",
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    // Apply theme-aware text color
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Redirecting you back to the login page.",
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    // Apply theme-aware text color
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Navigate to login page after user acknowledges
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false,
                  );
                },
                child: Text(
                  "OK",
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  } catch (e) {
    print('Account deletion error: $e');

    // Make sure to close the loading dialog
    if (dialogContext != null && Navigator.canPop(dialogContext!)) {
      Navigator.pop(dialogContext!);
    }


    // Show error dialog
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            // Apply theme-aware background color
            backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
            title: Text(
              "Error Deleting Account",
              style: AppTypography.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Text(
              "We encountered an error while trying to delete your account: $e\n\nPlease try again later or contact support.",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  "CLOSE",
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }
}

Future<void> _reauthenticateUser(BuildContext context, bool isDarkMode) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) throw Exception('No user is logged in');
  if (currentUser.email == null) throw Exception('User has no email');

  final TextEditingController passwordController = TextEditingController();
  bool authenticated = false;

  // Show reauthentication dialog
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // Apply theme-aware background color
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          'Security Verification',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            // Apply theme-aware text color
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please enter your password to confirm account deletion:',
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: AppTypography.textTheme.bodyMedium?.copyWith(
                  // Apply theme-aware label color
                  color: isDarkMode ? Colors.grey[400] : null,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                // Apply theme-aware fill color
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              ),
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              throw Exception('Authentication cancelled by user');
            },
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              authenticated = true;
            },
            child: Text(
              'VERIFY',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );

  if (!authenticated) {
    throw Exception('Authentication cancelled');
  }

  // Create credential
  AuthCredential credential = EmailAuthProvider.credential(
    email: currentUser.email!,
    password: passwordController.text,
  );

  // Reauthenticate
  try {
    await currentUser.reauthenticateWithCredential(credential);
  } catch (e) {
    throw Exception('Failed to authenticate: $e');
  }
}

Widget _buildDeleteInfoItem(IconData icon, String text, bool isDarkMode) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Row(
      children: [
        // Apply theme-aware icon color
        Icon(icon, size: 20, color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              // Apply theme-aware text color
              color: isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}

class AccessibilityPage extends StatefulWidget {
  @override
  _AccessibilityPageState createState() => _AccessibilityPageState();
}

class _AccessibilityPageState extends State<AccessibilityPage> {
  bool isLargeFont = false;

  @override
  Widget build(BuildContext context) {
    // Get the theme provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Accessibility',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),

      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Font size option with improved styling
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey[900]
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLargeFont
                      ? Colors.blue
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Font Size',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      fontSize: isLargeFont ? 24 : null,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isLargeFont = !isLargeFont;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLargeFont
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLargeFont ? 'Large' : 'Normal',
                        style: AppTypography.textTheme.labelMedium?.copyWith(
                          fontSize: isLargeFont ? 20 : 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Dark mode option with improved styling
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey[900]
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.blue
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dark Mode',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      fontSize: isLargeFont ? 24 : null,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Switch(
                    value: isDarkMode,
                    onChanged: (bool? value) {
                      if (value != null) {
                        // Update theme provider which will propagate changes app-wide
                        themeProvider.setDarkMode(value);
                        // No need to call setState as the provider will trigger a rebuild
                      }
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Traffic layer option with matching styling
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey[900]
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeProvider.isTrafficEnabled
                      ? Colors.blue
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Traffic Layer',
                    style: AppTypography.textTheme.titleMedium?.copyWith(
                      fontSize: isLargeFont ? 24 : null,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Switch(
                    value: themeProvider.isTrafficEnabled,
                    onChanged: (bool? value) {
                      if (value != null) {
                        // Update theme provider which will propagate changes app-wide
                        themeProvider.setTrafficEnabled(value);
                        // No need to call setState as the provider will trigger a rebuild
                      }
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get the theme provider to access dark mode state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply theme-aware background color
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        // Apply theme-aware AppBar styling
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            // Apply theme-aware text color
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        leading: IconButton(
          // Apply theme-aware icon color
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            // Apply theme-aware icon color
            icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Privacy Policy",
              style: AppTypography.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Effective Date: December 5, 2024",
              style: AppTypography.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            Text(
              "At NaviGo, your privacy is important to us. This Privacy Policy outlines how we collect, use, and protect your personal information when you use our app and services. By using the app, you agree to the terms of this policy.",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                height: 1.5,
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),
            SizedBox(height: 24),

            _buildPrivacySectionTitle("1. Information We Collect", isDarkMode),
            Text(
              "We collect information to provide and improve our services. This includes: ",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),
            SizedBox(height: 12),

            _buildPrivacySubsectionTitle("a. Information You Provide", isDarkMode),
            _buildPrivacyBulletPoint("Account Information: Name, email address, and any other details you provide during registration.", isDarkMode),
            _buildPrivacyBulletPoint("Reports and Feedback: Information submitted through traffic reports or feedback forms.", isDarkMode),
            SizedBox(height: 12),

            _buildPrivacySubsectionTitle("b. Automatically Collected Information", isDarkMode),
            _buildPrivacyBulletPoint("Location Data: Real-time GPS location to generate personalized routes and traffic updates.", isDarkMode),
            _buildPrivacyBulletPoint("Usage Data: Information about how you use the app, including clicks, routes generated, and time spent.", isDarkMode),
            _buildPrivacyBulletPoint("Device Information: Details about your device such as model, operating system, and app version.", isDarkMode),
            SizedBox(height: 12),

            _buildPrivacySubsectionTitle("c. Cookies and Tracking Technologies", isDarkMode),
            _buildPrivacyBulletPoint("We use cookies and similar technologies to enhance your experience and gather analytics data.", isDarkMode),

            _buildPrivacySectionDivider(isDarkMode),

            _buildPrivacySectionTitle("2. How We Use Your Information", isDarkMode),
            Text("We use the information collected for purposes such as: ",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),
            SizedBox(height: 12),

            _buildPrivacyBulletPoint("Providing Services: Generating routes, real-time traffic updates, and personalized recommendations.", isDarkMode),
            _buildPrivacyBulletPoint("Improving the App: Analyzing usage patterns to enhance features and performance.", isDarkMode),
            _buildPrivacyBulletPoint("Communication: Sending notifications, updates, and responding to feedback.", isDarkMode),
            _buildPrivacyBulletPoint("Safety and Security: Detecting and preventing fraudulent and unauthorized activities.", isDarkMode),

            _buildPrivacySectionDivider(isDarkMode),

            _buildPrivacySectionTitle("3. Sharing Your Information", isDarkMode),
            Text("We do not sell your information. We may share information: ",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),
            SizedBox(height: 12),

            _buildPrivacyBulletPoint("With Service Providers: Third-party services that help us operate the application (e.g., hosting, analytics).", isDarkMode),
            _buildPrivacyBulletPoint("For Legal Reasons: If required by law or to protect rights, safety, and property.", isDarkMode),
            _buildPrivacyBulletPoint("With Your Consent: When you explicitly agree to share your information for specific purposes.", isDarkMode),

            _buildPrivacySectionDivider(isDarkMode),

            _buildPrivacySectionTitle("4. Data Security", isDarkMode),
            Text(
              "We implement industry-standard security measures to protect your information from unauthorized access, loss, or misuse. However, no system is completely secure, and we cannot guarantee absolute security.",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),

            _buildPrivacySectionDivider(isDarkMode),

            _buildPrivacySectionTitle("5. Your Rights and Choices", isDarkMode),
            Text("You have the right to: ",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),
            SizedBox(height: 12),

            _buildPrivacyBulletPoint("Access and Update: View and update your personal information through your account settings.", isDarkMode),
            _buildPrivacyBulletPoint("Delete Data: Request deletion of your account and associated data.", isDarkMode),
            _buildPrivacyBulletPoint("Opt-Out: Disable location tracking or notification through your device settings.", isDarkMode),

            _buildPrivacySectionDivider(isDarkMode),

            _buildPrivacySectionTitle("6. Data Retention", isDarkMode),
            Text(
              "We retain your data only as long as necessary to provide services or comply with legal obligations. Once data is no longer needed, we securely delete or anonymize it.",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),

            _buildPrivacySectionDivider(isDarkMode),

            _buildPrivacySectionTitle("7. Children's Privacy", isDarkMode),
            Text(
              "Our services are not intended for children under 13. We do not knowingly collect personal information from children. If you believe a child has provided us with information, please contact us to remove it.",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),

            _buildPrivacySectionDivider(isDarkMode),

            _buildPrivacySectionTitle("8. Changes to This Policy", isDarkMode),
            Text(
              "We may update this Privacy Policy from time to time. Any changes will be posted within the application, and your continued use of the application signifies acceptance of the updated terms.",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),

            _buildPrivacySectionDivider(isDarkMode),

            _buildPrivacySectionTitle("9. Contact Us", isDarkMode),
            Text(
              "If you have questions or concerns about this Privacy Policy or how we handle your data, please contact us at: ",
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),
            SizedBox(height: 12),

            Text(
              "Email: support@navigo.com",
              style: AppTypography.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              "Address: navigosupport@gmail.com",
              style: AppTypography.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helper methods for consistent Privacy Policy styling with dark mode support
  Widget _buildPrivacySectionTitle(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        text,
        style: AppTypography.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          // Apply theme-aware text color
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPrivacySubsectionTitle(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTypography.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          // Apply theme-aware text color
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPrivacyBulletPoint(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                // Apply theme-aware text color
                color: isDarkMode ? Colors.white.withOpacity(0.9) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySectionDivider(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        height: 1,
        // Apply theme-aware divider color
        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
      ),
    );
  }
}