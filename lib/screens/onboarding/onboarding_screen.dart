import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/screens/map/navigo-map.dart';
import 'package:project_navigo/services/onboarding_service.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:project_navigo/themes/theme_provider.dart';
import 'package:project_navigo/themes/app_theme.dart';

import '../../services/user_provider.dart';

void main() {
  runApp(const OnboardingScreen());
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaviGo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Shared styles and utilities for onboarding screens
class AppStyles {
  /// Gets primary button style based on theme
  static ButtonStyle getPrimaryButtonStyle(bool isDarkMode) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      minimumSize: const Size(180, 48),
      elevation: isDarkMode ? 2 : 3,
      shadowColor: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.3),
    );
  }

  /// Gets disabled button style based on theme
  static ButtonStyle getDisabledButtonStyle(bool isDarkMode) {
    return ElevatedButton.styleFrom(
      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[400],
      foregroundColor: isDarkMode ? Colors.grey[400] : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      minimumSize: const Size(180, 48),
      elevation: isDarkMode ? 1 : 2,
    );
  }

  /// Enhanced error dialog for better error visualization
  static void showErrorDialog(BuildContext context, String message) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red[400],
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Error',
                style: AppTypography.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppTypography.textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: AppTypography.textTheme.labelLarge?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// 1. Initial Welcome Screen
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Create fade-in animation
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Create slide-up animation
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Start the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Get theme mode from provider
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply theme-aware background color
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: Stack(
        children: [
          // Top left corner decoration with animation
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                top: 0,
                left: 0,
                child: Opacity(
                  opacity: _controller.value * 0.9,
                  child: Image.asset(
                    'assets/abstract_corner_pattern.png',
                    width: 180,
                    // Apply color filter in dark mode
                    color: isDarkMode ? Colors.white.withOpacity(0.3) : null,
                    colorBlendMode: isDarkMode ? BlendMode.srcATop : null,
                  ),
                ),
              );
            },
          ),

          // Bottom right corner decoration with animation
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                bottom: 0,
                right: 0,
                child: Opacity(
                  opacity: _controller.value * 0.9,
                  child: Transform.rotate(
                    angle: 3.1416, // 180 degrees in radians
                    child: Image.asset(
                      'assets/abstract_corner_pattern.png',
                      width: 180,
                      // Apply color filter in dark mode
                      color: isDarkMode ? Colors.white.withOpacity(0.3) : null,
                      colorBlendMode: isDarkMode ? BlendMode.srcATop : null,
                    ),
                  ),
                ),
              );
            },
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: screenSize.height * 0.08),

                  // App logo with animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.8 + (0.2 * _controller.value),
                        child: Opacity(
                          opacity: _fadeInAnimation.value,
                          child: Image.asset(
                            'assets/logo.png',
                            height: 100,
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: screenSize.height * 0.06),

                  // Welcome text with animation
                  FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Welcome to NaviGo',
                            style: AppTypography.authTitle.copyWith(
                              color: isDarkMode ? Colors.white : AppTheme.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // Description text
                          Text(
                            'Let\'s set up your account to get you started with personalized navigation and real-time traffic updates.',
                            style: AppTypography.authSubtitle.copyWith(
                              color: isDarkMode ? Colors.white70 : Colors.grey[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.08),

                  // Illustration with animation - keep GIF regardless of theme
                  FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode
                                  ? Colors.black.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: isDarkMode ? 15 : 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/location.gif',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Button with animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - _controller.value)),
                        child: Opacity(
                          opacity: _controller.value,
                          child: Container(
                            width: double.infinity,
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 30),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(isDarkMode ? 0.2 : 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: AppStyles.getPrimaryButtonStyle(isDarkMode),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                    const UsernameScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      const begin = Offset(1.0, 0.0);
                                      const end = Offset.zero;
                                      const curve = Curves.easeInOutCubic;

                                      var tween = Tween(begin: begin, end: end)
                                          .chain(CurveTween(curve: curve));

                                      return SlideTransition(
                                        position: animation.drive(tween),
                                        child: child,
                                      );
                                    },
                                    transitionDuration: const Duration(milliseconds: 500),
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Let\'s Get Started',
                                    style: AppTypography.authButton,
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 2. Username Input Screen with Firebase Integration
class UsernameScreen extends StatefulWidget {
  const UsernameScreen({Key? key}) : super(key: key);

  @override
  _UsernameScreenState createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isUsernameValid = false;

  // Debounce timer for username validation
  DateTime? _lastUsernameCheck;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // Check if username is already taken
  Future<bool> _isUsernameTaken(String username) async {
    try {
      // Check if at least 500ms have passed since the last check to avoid too many Firestore calls
      final now = DateTime.now();
      if (_lastUsernameCheck != null &&
          now.difference(_lastUsernameCheck!).inMilliseconds < 500) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      _lastUsernameCheck = now;

      // Query Firestore for the username
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking username: $e');
      return false; // Assume it's not taken if there's an error
    }
  }

  // Validate the username input
  Future<void> _validateUsername(String value) async {
    // Skip empty usernames
    if (value.isEmpty) {
      setState(() {
        _isUsernameValid = false;
        _errorMessage = null;
      });
      return;
    }

    // Basic validation rules
    if (value.length < 3) {
      setState(() {
        _isUsernameValid = false;
        _errorMessage = 'Username must be at least 3 characters';
      });
      return;
    }

    if (value.length > 20) {
      setState(() {
        _isUsernameValid = false;
        _errorMessage = 'Username must be less than 20 characters';
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_\.]+$').hasMatch(value)) {
      setState(() {
        _isUsernameValid = false;
        _errorMessage = 'Username can only contain letters, numbers, underscore and dot';
      });
      return;
    }

    // Check if username is already taken
    final isTaken = await _isUsernameTaken(value);
    if (isTaken) {
      setState(() {
        _isUsernameValid = false;
        _errorMessage = 'This username is already taken';
      });
      return;
    }

    // Username is valid and available
    setState(() {
      _isUsernameValid = true;
      _errorMessage = null;
    });
  }

  // Save username to Firestore and update onboarding status
  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate() || !_isUsernameValid) {
      return;
    }

    final username = _usernameController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Get onboarding service
      final onboardingService = Provider.of<OnboardingService>(context, listen: false);

      // Update username and onboarding status
      await onboardingService.completeUsernameSetup(
        userId: user.uid,
        username: username,
      );

      // Navigate to DOB screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DateOfBirthScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = null; // Clear inline error as we'll show a dialog
        });

        // Show enhanced error dialog instead of snackbar
        AppStyles.showErrorDialog(
            context,
            'Error saving username: ${e.toString()}'
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply theme-aware background
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Top left corner decoration
            Positioned(
              top: 0,
              left: 0,
              child: Image.asset(
                'assets/abstract_corner_pattern.png',
                width: 150,
                // Apply color filter in dark mode
                color: isDarkMode ? Colors.white.withOpacity(0.3) : null,
                colorBlendMode: isDarkMode ? BlendMode.srcATop : null,
              ),
            ),

            // Bottom right corner decoration
            Positioned(
              bottom: 0,
              right: 0,
              child: Transform.rotate(
                angle: 3.1416, // 180 degrees in radians
                child: Image.asset(
                  'assets/abstract_corner_pattern.png',
                  width: 150,
                  // Apply color filter in dark mode
                  color: isDarkMode ? Colors.white.withOpacity(0.3) : null,
                  colorBlendMode: isDarkMode ? BlendMode.srcATop : null,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 120),
                    Text(
                      'What should we\ncall you?',
                      style: AppTypography.authTitle.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your preferred username',
                        hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                            fontStyle: FontStyle.italic
                        ),
                        prefixIcon: Icon(
                            Icons.person,
                            color: isDarkMode
                                ? AppTheme.primaryColor.withOpacity(0.6)
                                : AppTheme.primaryColor.withOpacity(0.7)
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[850] : Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                              width: 1.5
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDarkMode ? Colors.red[300]! : AppTheme.errorColor,
                              width: 1.5
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDarkMode ? Colors.red[300]! : AppTheme.errorColor,
                              width: 2
                          ),
                        ),
                        errorText: _errorMessage,
                        errorStyle: AppTypography.textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.red[300] : AppTheme.errorColor,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        isDense: false,
                        focusColor: AppTheme.primaryColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        // Show a check mark if username is valid
                        suffixIcon: _isUsernameValid
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : null,
                      ),
                      style: AppTypography.authInputText.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      cursorColor: AppTheme.primaryColor,
                      onChanged: _validateUsername,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        return null;
                      },
                      // Disable auto validation to prevent premature error messages
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (_isUsernameValid && !_isLoading) {
                          _saveUsername();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkMode ? Colors.white : AppTheme.primaryColor
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      style: _isUsernameValid && !_isLoading
                          ? AppStyles.getPrimaryButtonStyle(isDarkMode)
                          : AppStyles.getDisabledButtonStyle(isDarkMode),
                      onPressed: _isUsernameValid && !_isLoading ? _saveUsername : null,
                      child: _isLoading
                          ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2
                          )
                      )
                          : Text(
                        'Continue',
                        style: AppTypography.authButton,
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. Date of Birth Input Screen with Firebase Integration
class DateOfBirthScreen extends StatefulWidget {
  const DateOfBirthScreen({Key? key}) : super(key: key);

  @override
  _DateOfBirthScreenState createState() => _DateOfBirthScreenState();
}

class _DateOfBirthScreenState extends State<DateOfBirthScreen> {
  // Selected date with null initial value
  DateTime? _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;

  // Calculate minimum allowed date (13 years ago) and maximum (100 years ago)
  final DateTime _minDate = DateTime(DateTime.now().year - 100, 1, 1);
  final DateTime _maxDate = DateTime(DateTime.now().year - 13, 12, 31);

  // Function to show date picker
  Future<void> _showDatePicker() async {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000, 1, 1),
      firstDate: _minDate,
      lastDate: _maxDate,
      helpText: 'SELECT YOUR DATE OF BIRTH',
      cancelText: 'CANCEL',
      confirmText: 'CONFIRM',
      fieldLabelText: 'Date of Birth',
      fieldHintText: 'MM/DD/YYYY',
      errorFormatText: 'Enter a valid date',
      errorInvalidText: 'You must be at least 13 years old',
      builder: (context, child) {
        return Theme(
          data: isDarkMode
              ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.grey[850]!,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          )
              : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Save date of birth to Firestore and update onboarding status
  Future<void> _saveDateOfBirth() async {
    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'Please select your date of birth';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      // Get onboarding service
      final onboardingService = Provider.of<OnboardingService>(context, listen: false);

      // Update date of birth and complete onboarding
      await onboardingService.completeDobSetup(
        userId: user.uid,
        dateOfBirth: _selectedDate!,
      );

      // Navigate to final welcome screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FinalWelcomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = null; // Clear inline error to use dialog
        });

        // Show enhanced error dialog
        AppStyles.showErrorDialog(
            context,
            'Error saving date of birth: ${e.toString()}'
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Format the selected date
  String get formattedDate {
    if (_selectedDate == null) return 'Please select your date of birth';

    final month = _selectedDate!.month.toString().padLeft(2, '0');
    final day = _selectedDate!.day.toString().padLeft(2, '0');
    final year = _selectedDate!.year.toString();

    return '$month/$day/$year';
  }

  @override
  Widget build(BuildContext context) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply theme-aware background
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Top left corner decoration
            Positioned(
              top: 0,
              left: 0,
              child: Image.asset(
                'assets/abstract_corner_pattern.png',
                width: 150,
                // Apply color filter in dark mode
                color: isDarkMode ? Colors.white.withOpacity(0.3) : null,
                colorBlendMode: isDarkMode ? BlendMode.srcATop : null,
              ),
            ),

            // Bottom right corner decoration
            Positioned(
              bottom: 0,
              right: 0,
              child: Transform.rotate(
                angle: 3.1416, // 180 degrees in radians
                child: Image.asset(
                  'assets/abstract_corner_pattern.png',
                  width: 150,
                  // Apply color filter in dark mode
                  color: isDarkMode ? Colors.white.withOpacity(0.3) : null,
                  colorBlendMode: isDarkMode ? BlendMode.srcATop : null,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Text(
                    'When were you born?',
                    style: AppTypography.authTitle.copyWith(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This helps us personalize your experience',
                    style: AppTypography.authSubtitle.copyWith(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Date selector card
                  InkWell(
                    onTap: _isLoading ? null : _showDatePicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _errorMessage != null
                              ? (isDarkMode ? Colors.red[300]! : AppTheme.errorColor)
                              : (_selectedDate != null
                              ? AppTheme.primaryColor
                              : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? Colors.black.withOpacity(0.2)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: _selectedDate != null
                                  ? AppTheme.primaryColor
                                  : (isDarkMode ? Colors.grey[400] : Colors.grey[500]),
                              size: 24,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                formattedDate,
                                style: AppTypography.textTheme.bodyLarge?.copyWith(
                                  color: _selectedDate != null
                                      ? (isDarkMode ? Colors.white : Colors.black87)
                                      : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                  fontWeight: _selectedDate != null
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.red[300] : AppTheme.errorColor,
                        ),
                      ),
                    ),

                  // Loading indicator
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isDarkMode ? Colors.white : AppTheme.primaryColor
                        ),
                      ),
                    ),

                  const Spacer(),
                  ElevatedButton(
                    style: _selectedDate != null && !_isLoading
                        ? AppStyles.getPrimaryButtonStyle(isDarkMode)
                        : AppStyles.getDisabledButtonStyle(isDarkMode),
                    onPressed: _selectedDate != null && !_isLoading ? _saveDateOfBirth : null,
                    child: _isLoading
                        ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2
                        )
                    )
                        : Text(
                      'Continue',
                      style: AppTypography.authButton,
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. Final Welcome Screen
class FinalWelcomeScreen extends StatefulWidget {
  const FinalWelcomeScreen({Key? key}) : super(key: key);

  @override
  State<FinalWelcomeScreen> createState() => _FinalWelcomeScreenState();
}

class _FinalWelcomeScreenState extends State<FinalWelcomeScreen> {
  bool _isLoading = false; // Define the loading state variable

  @override
  Widget build(BuildContext context) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient that works in both light and dark modes
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [Colors.blue.shade900, Colors.indigo.shade900]
                    : [Color(0xFF4169E1), Color(0xFF1E3A8A)],
              ),
            ),
          ),

          // Top left corner decoration - with color overlay to blend with gradient
          Positioned(
            top: 0,
            left: 0,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.3)],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Image.asset(
                'assets/abstract_corner_pattern.png',
                width: 200,
              ),
            ),
          ),

          // Bottom right corner decoration - with color overlay
          Positioned(
            bottom: 0,
            right: 0,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.85)],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Transform.rotate(
                angle: 3.1416, // 180 degrees in radians
                child: Image.asset(
                  'assets/abstract_corner_pattern.png',
                  width: 200,
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with subtle animation
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.8, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/logo.png',
                      width: 120,
                      height: 120,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Welcome text with fade-in animation
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          'Welcome to',
                          style: AppTypography.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'NaviGo',
                          style: AppTypography.textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 180,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Button with slide-up animation
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 30.0, end: 0.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, value),
                        child: Opacity(
                          opacity: 1 - (value / 30),
                          child: child,
                        ),
                      );
                    },
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                        shadowColor: Colors.black38,
                        minimumSize: const Size(220, 58),
                      ),
                      onPressed: _isLoading ? null : () async {
                        setState(() {
                          _isLoading = true;
                        });

                        try {
                          // Get UserProvider instance
                          final userProvider = Provider.of<UserProvider>(context, listen: false);

                          // Refresh user data from Firestore
                          await userProvider.loadUserData();

                          // Navigate to main app only after data is loaded
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MyApp()),
                            );
                          }
                        } catch (e) {
                          print('Error loading user data: $e');

                          if (mounted) {
                            // Show error dialog for better error visualization
                            AppStyles.showErrorDialog(
                                context,
                                'Error loading user data: ${e.toString()}'
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      },
                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 2,
                        ),
                      )
                          : Text(
                        'Get Started',
                        style: AppTypography.authButton.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}