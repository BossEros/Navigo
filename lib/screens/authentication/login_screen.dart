import 'package:flutter/material.dart';
import 'package:project_navigo/screens/map/navigo-map.dart';
import 'package:project_navigo/screens/authentication/register_form.dart';
import 'package:project_navigo/screens/authentication/forgotPasswordScreen.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/services/user_provider.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:project_navigo/themes/theme_provider.dart';
import 'package:project_navigo/utils/firebase_error_handler.dart';
import '../../services/auth_service.dart';
import '../../services/onboarding_service.dart';
import 'package:project_navigo/screens/onboarding/onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Email validation regex pattern
  final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');

  void _loginWithEmail() async {
    // Validate form
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      // Get auth service
      final authService = Provider.of<AuthService>(context, listen: false);

      // Login using auth service
      final userCredential = await authService.signInWithEmailPassword(email, password);

      // Check onboarding status after successful login
      if (mounted) {
        await _checkOnboardingStatus(userCredential.user!.uid);
      }
    } catch (e) {
      if (mounted) {
        // Convert Firebase error to user-friendly message
        final errorMessage = FirebaseErrorHandler.handleAuthError(e);

        // Show enhanced error dialog
        _showEnhancedErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userCredential = await authService.signInWithGoogle();

      // Check onboarding status after successful Google sign-in
      if (mounted) {
        await _checkOnboardingStatus(userCredential.user!.uid);
      }
    } catch (e) {
      if (mounted) {
        // Convert Firebase error to user-friendly message
        final errorMessage = FirebaseErrorHandler.handleAuthError(e);

        // Show improved error dialog
        _showEnhancedErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Method to show a modern, enhanced error dialog
  void _showEnhancedErrorDialog(String message) {
    // Get the theme provider to check dark mode status
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),

                // Error title
                Text(
                  'Login Failed',
                  style: AppTypography.textTheme.titleLarge?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Error message
                Text(
                  message,
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Single OK button (removed Reset Password button)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'OK',
                      style: AppTypography.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  Future<void> _checkOnboardingStatus(String userId) async {
    try {
      // Get onboarding service
      final onboardingService = Provider.of<OnboardingService>(context, listen: false);

      // Get current onboarding status
      final status = await onboardingService.getUserOnboardingStatus(userId);

      // Load user data before navigation
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserData();

      // Navigate based on onboarding status
      if (!mounted) return;

      if (status == 'incomplete') {
        // New user or incomplete profile - go to username setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UsernameScreen()),
        );
      } else if (status == 'username_completed') {
        // Username set but DOB missing - go to DOB setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DateOfBirthScreen()),
        );
      } else {
        // Profile is complete - go to main app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyApp()),
        );
      }
    } catch (e) {
      print('Error checking onboarding status: $e');

      if (!mounted) return;

      // Default to username setup if there's an error
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UsernameScreen()),
      );
    }
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme provider to check dark mode status
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Set to false to prevent resizing when the keyboard appears
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Upper-left corner decoration - matching registration form
            Positioned(
              top: 0,
              left: 0,
              child: Image.asset(
                'assets/abstract_corner_pattern.png',
                width: 140,
              ),
            ),

            // Lower-right corner decoration - matching registration form
            Positioned(
              bottom: 0,
              right: 0,
              child: Transform.rotate(
                angle: 3.1416, // 180 degrees in radians
                child: Image.asset(
                  'assets/abstract_corner_pattern.png',
                  width: 140,
                ),
              ),
            ),

            // Original login form content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: Form(  // Wrap in Form widget for validation
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/logo.png',
                          height: 80,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title - using our standardized typography
                      Text(
                        'Login',
                        style: AppTypography.authTitle,
                      ),

                      const SizedBox(height: 8),

                      // Subtitle - using our standardized typography with theme-aware color
                      Text(
                        'Welcome back!',
                        style: AppTypography.authSubtitle.copyWith(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Email field with validation
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: AppTypography.authInputText,
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

                      const SizedBox(height: 20),

                      // Password field with visibility toggle
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: AppTypography.authInputText,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginWithEmail,
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
                            'Login',
                            style: AppTypography.authButton,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Center(
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text(
                            'Forgot Password?',
                            style: AppTypography.textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Center(
                        child: Text(
                          'Or sign in with',
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Social login buttons - Only Google button remains
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google button
                          InkWell(
                            onTap: _isLoading ? null : _loginWithGoogle,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 5,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset('assets/google_logo.png', height: 24),
                              ),
                            ),
                          ),
                          // Facebook button removed but method preserved
                        ],
                      ),

                      const SizedBox(height: 40),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: AppTypography.textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? Colors.white70 : null,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterForm()),
                              );
                            },
                            child: Text(
                              'Register',
                              style: AppTypography.textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).primaryColor,
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