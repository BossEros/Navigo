import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:project_navigo/services/onboarding_service.dart';

void main() {
  runApp(const OnboardingScreen());
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaviGo',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'Roboto'),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Shared decorations and styles
class AppStyles {
  static const Color primaryBlue = Color(0xFF4169E1); // Royal blue color from images
  static const Color lightBlue = Color(0xFFADD8E6);
  static const Color errorRed = Color(0xFFE53935);

  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    minimumSize: const Size(180, 48),
  );

  static ButtonStyle disabledButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.grey[400],
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    minimumSize: const Size(180, 48),
  );
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

    return Scaffold(
      backgroundColor: Colors.white,
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
                          const Text(
                            'Welcome to NaviGo',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppStyles.primaryBlue,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // Description text
                          Text(
                            'Let\'s set up your account to get you started with personalized navigation and real-time traffic updates.',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.08),

                  // Illustration with animation
                  FadeTransition(
                    opacity: _fadeInAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
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
                                  color: AppStyles.primaryBlue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppStyles.primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
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
                                children: const [
                                  Text(
                                    'Let\'s Get Started',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded),
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
          _errorMessage = 'Error saving username: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!))
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
    return Scaffold(
      backgroundColor: Colors.white,
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
                    const Text(
                      'What should we\ncall you?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your preferred username',
                        hintStyle: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic),
                        prefixIcon: Icon(Icons.person, color: AppStyles.primaryBlue.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppStyles.primaryBlue, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppStyles.errorRed, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppStyles.errorRed, width: 2),
                        ),
                        errorText: _errorMessage,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        isDense: false,
                        focusColor: AppStyles.primaryBlue,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        // Show a check mark if username is valid
                        suffixIcon: _isUsernameValid ?
                        Icon(Icons.check_circle, color: Colors.green) : null,
                      ),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      cursorColor: AppStyles.primaryBlue,
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
                      const Center(child: CircularProgressIndicator()),
                    const Spacer(),
                    ElevatedButton(
                      style: _isUsernameValid && !_isLoading ?
                      AppStyles.primaryButtonStyle : AppStyles.disabledButtonStyle,
                      onPressed: _isUsernameValid && !_isLoading ? _saveUsername : null,
                      child: _isLoading ?
                      const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      ) :
                      const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
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
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppStyles.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppStyles.primaryBlue,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
          _errorMessage = 'Error saving date of birth: ${e.toString()}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!))
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
    return Scaffold(
      backgroundColor: Colors.white,
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
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  const Text(
                    'When were you born?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This helps us personalize your experience',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Date selector card
                  InkWell(
                    onTap: _isLoading ? null : _showDatePicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _errorMessage != null ?
                          AppStyles.errorRed :
                          (_selectedDate != null ? AppStyles.primaryBlue : Colors.grey[300]!),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: _selectedDate != null
                                ? AppStyles.primaryBlue
                                : Colors.grey[500],
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedDate != null
                                    ? Colors.black87
                                    : Colors.grey[600],
                                fontWeight: _selectedDate != null
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppStyles.errorRed,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  // Loading indicator
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(),
                    ),

                  const Spacer(),
                  ElevatedButton(
                    style: _selectedDate != null && !_isLoading ?
                    AppStyles.primaryButtonStyle : AppStyles.disabledButtonStyle,
                    onPressed: _selectedDate != null && !_isLoading ? _saveDateOfBirth : null,
                    child: _isLoading ?
                    const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    ) :
                    const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
class FinalWelcomeScreen extends StatelessWidget {
  const FinalWelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4169E1), Color(0xFF1E3A8A)],
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
                        const Text(
                          'Welcome to',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'NaviGo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
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
                        foregroundColor: AppStyles.primaryBlue,
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
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const MyApp()),
                        );
                      },
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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