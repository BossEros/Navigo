import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_navigo/services/user_service.dart';
import 'package:project_navigo/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:project_navigo/themes/theme_provider.dart'; // Import ThemeProvider
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import 'navigo-map.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({Key? key}) : super(key: key);

  @override
  _RegisterFormState createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>(); // Form key for validation
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true; // To toggle password visibility
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false; // For terms and conditions checkbox

  // Email validation regex pattern
  final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Password strength check
  bool _isPasswordStrong(String password) {
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(
        RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    bool hasMinLength = password.length >= 8;

    return hasUppercase && hasDigits && hasSpecialCharacters && hasMinLength;
  }

  Future<void> completeUserRegistration({
    required String userId,
    required String email,
    required String username,
    required DateTime dateOfBirth,
    File? profileImage,
  }) async {
    try {
      // Get services using Provider
      final userService = Provider.of<UserService>(context, listen: false);
      final onboardingService = Provider.of<OnboardingService>(
          context, listen: false);

      // Calculate age from date of birth
      final now = DateTime.now();
      final age = now.year - dateOfBirth.year -
          (now.month > dateOfBirth.month ||
              (now.month == dateOfBirth.month && now.day >= dateOfBirth.day)
              ? 0
              : 1);

      // Update user profile with username and age
      await userService.updateUserProfile(
        userId: userId,
        username: username,
        age: age,
      );

      // Set date of birth and mark onboarding as complete
      await onboardingService.completeDobSetup(
        userId: userId,
        dateOfBirth: dateOfBirth,
      );

      // Note: If you need to handle profile image upload, you'd need to add
      // that functionality to the UserService or create a dedicated StorageService

    } catch (e) {
      print('Error completing user registration: $e');
      rethrow;
    }
  }

  void signUp() async {
    // Validate form
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the terms and conditions')),
      );
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      // Get auth service
      final authService = Provider.of<AuthService>(context, listen: false);

      // Register with email and password
      // This will create a minimal user profile with onboarding_status = "incomplete"
      await authService.registerWithEmailPassword(email, password);

      // Navigate to login screen after successful registration
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Registration successful! Please log in.')),
        );

        // Navigate to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _registerWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // Get auth service
      final authService = Provider.of<AuthService>(context, listen: false);

      // Sign in with Google (handles both new and returning users)
      final userCredential = await authService.signInWithGoogle();

      // For new users, navigate to onboarding
      if (userCredential.additionalUserInfo?.isNewUser == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else if (mounted) {
        // For existing users, check onboarding status in main app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyApp()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> registerUser(String email, String password, String username,
      int age) async {
    try {
      // Get services
      final authService = Provider.of<AuthService>(context, listen: false);
      final userService = Provider.of<UserService>(context, listen: false);

      // First, create the authentication account
      UserCredential userCredential = await authService
          .registerWithEmailPassword(email, password);

      // Then create or update the user profile with username and age
      await userService.createUserProfile(
        userId: userCredential.user!.uid,
        email: email,
        username: username,
        age: age,
      );

      // Registration successful
    } catch (e) {
      // Handle registration errors
      print('Registration error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme provider to determine dark mode status
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply theme-aware background color
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      // Set to false to prevent resizing when the keyboard appears
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Image.asset(
                'assets/abstract_corner_pattern.png',
                width: 140,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Transform.rotate(
                angle: 3.1416,
                child: Image.asset(
                  'assets/abstract_corner_pattern.png',
                  width: 140,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 30.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Image.asset('assets/logo.png', height: 70),
                      ),
                      const SizedBox(height: 22),

                      // Title using standardized typography with dark mode support
                      Text(
                        'Register',
                        style: AppTypography.authTitle.copyWith(
                          // Theme-aware color
                          color: isDarkMode ? Colors.white : null,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Subtitle using standardized typography with dark mode support
                      Text(
                        'Create your account',
                        style: AppTypography.authSubtitle.copyWith(
                          // Theme-aware color
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Email field with validation and dark mode support
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.email,
                            // Theme-aware icon color
                            color: isDarkMode ? Colors.grey[400] : null,
                          ),
                          // Theme-aware label color
                          labelStyle: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : null,
                          ),
                          // Theme-aware border color
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                        ),
                        style: AppTypography.authInputText.copyWith(
                          // Theme-aware text color
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!emailRegex.hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password field with visibility toggle, validation and dark mode support
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(
                            Icons.lock,
                            // Theme-aware icon color
                            color: isDarkMode ? Colors.grey[400] : null,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              // Theme-aware icon color
                              color: isDarkMode ? Colors.grey[400] : null,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          // Theme-aware label color
                          labelStyle: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : null,
                          ),
                          // Theme-aware border color
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                        ),
                        style: AppTypography.authInputText.copyWith(
                          // Theme-aware text color
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (!_isPasswordStrong(value)) {
                            return 'Password must be at least 8 characters with uppercase, number, and special character';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Confirm password field with validation and dark mode support
                      TextFormField(
                        controller: confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(
                            Icons.lock,
                            // Theme-aware icon color
                            color: isDarkMode ? Colors.grey[400] : null,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              // Theme-aware icon color
                              color: isDarkMode ? Colors.grey[400] : null,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                !_obscureConfirmPassword;
                              });
                            },
                          ),
                          // Theme-aware label color
                          labelStyle: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : null,
                          ),
                          // Theme-aware border color
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: isDarkMode
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                        ),
                        style: AppTypography.authInputText.copyWith(
                          // Theme-aware text color
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        obscureText: _obscureConfirmPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Terms and conditions checkbox with dark mode support
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            onChanged: (value) {
                              setState(() {
                                _acceptedTerms = value ?? false;
                              });
                            },
                            // Theme-aware checkbox colors
                            fillColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.blue;
                              }
                              return isDarkMode ? Colors.grey[700] : null;
                            }),
                            checkColor: Colors.white,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _acceptedTerms = !_acceptedTerms;
                                });
                              },
                              child: Text(
                                'I agree to the Terms and Conditions and Privacy Policy',
                                style: AppTypography.textTheme.bodySmall?.copyWith(
                                  // Theme-aware text color
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Sign up button with theme-aware styling
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: _isLoading ? null : signUp,
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            'Sign up',
                            style: AppTypography.authButton,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // OR separator with dark mode support
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              // Theme-aware divider color
                              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            child: Text(
                              'Or sign up with',
                              style: AppTypography.textTheme.bodyMedium
                                  ?.copyWith(
                                // Theme-aware text color
                                color: isDarkMode ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              // Theme-aware divider color
                              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Social login buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google Icon
                          InkWell(
                            onTap: _isLoading ? null : _registerWithGoogle,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey[800] : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode
                                        ? Colors.black26
                                        : Colors.black12,
                                    blurRadius: 5,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                    'assets/google_logo.png', height: 24),
                              ),
                            ),
                          ),
                          // Facebook button removed as requested
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Login link with dark mode support
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: AppTypography.textTheme.bodyMedium?.copyWith(
                              // Theme-aware text color
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                              );
                            },
                            child: Text(
                              'Login',
                              style: AppTypography.textTheme.labelMedium
                                  ?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}