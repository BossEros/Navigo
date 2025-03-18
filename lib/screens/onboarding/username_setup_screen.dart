// In username_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_navigo/services/onboarding_service.dart';
import 'package:project_navigo/services/user_service.dart';
import 'dob_setup_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({Key? key}) : super(key: key);

  @override
  _UsernameSetupScreenState createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingUsername();
  }

  // Check if user already has a username (useful if they closed the app during onboarding)
  Future<void> _checkExistingUsername() async {
    try {
      setState(() => _isLoading = true);

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Not logged in - should not happen, but handle anyway
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      // Get user profile
      final userService = Provider.of<UserService>(context, listen: false);
      final userProfile = await userService.getUserProfile(currentUser.uid);

      // If username already exists, pre-fill the field
      if (userProfile.username.isNotEmpty) {
        _usernameController.text = userProfile.username;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error checking existing username: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setUsername() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get the current user ID
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('No authenticated user found');
      }

      // Update username and mark this step as completed
      final onboardingService = Provider.of<OnboardingService>(context, listen: false);
      await onboardingService.completeUsernameSetup(
        userId: userId,
        username: username,
      );

      // Navigate to DOB setup
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DobSetupScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Profile'),
        automaticallyImplyLeading: false, // Prevent going back
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a Username',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will be displayed to other users of the app.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter a unique username',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _setUsername,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}