import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'hamburger-menu.dart';
import 'package:project_navigo/screens/login_screen.dart';
import 'package:project_navigo/services/user_service.dart';
import 'package:project_navigo/models/user_profile.dart';
void main() {
  runApp(NavigoApp());
}

class NavigoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProfileScreen(),
    );
  }
}

// Changed to StatefulWidget to manage state
class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Add necessary variables
  User? _currentUser;
  Map<String, dynamic>? _userProfileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserProfile();
  }

  // Add the missing _loadUserProfile method
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUser != null) {
        // Get the UserService from Provider
        final userService = Provider.of<UserService>(context, listen: false);

        // Fetch the user profile
        final userProfile = await userService.getUserProfile(_currentUser!.uid);

        // Update state with the profile data
        setState(() {
          _userProfileData = {
            'username': userProfile.username,
            'email': userProfile.email,
            'homeAddress': {
              'formattedAddress': userProfile.homeAddress.formattedAddress,
            },
            'workAddress': {
              'formattedAddress': userProfile.workAddress.formattedAddress,
            },
            // Add other fields as needed
          };
          _isLoading = false;
        });
      } else {
        // No user is logged in
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Use the username from _userProfileData if available, otherwise fallback
    final username = _userProfileData?['username'] ?? 'janedoe';
    final email = _userProfileData?['email'] ?? 'janedoe202024@gmail.com';
    final homeAddress = _userProfileData?['homeAddress']?['formattedAddress'] ?? 'Cebu N Rd, Consolacion, Cebu';
    final workAddress = _userProfileData?['workAddress']?['formattedAddress'] ?? 'Set up Work Address';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Shortened blue header with username and profile pic
          Container(
            height: 200, // Reduced height for shorter gradient
            width: double.infinity, // Ensure full width
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Blue curved background - no left/right padding to reach edges
                Positioned.fill(
                  child: ClipPath(
                    clipper: HeaderClipper(),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.lightBlue.shade300, Colors.blue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                // Back button (left arrow)
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black, size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                // Username text positioned above profile picture
                Positioned(
                  top: 80, // Adjusted for shorter gradient
                  child: Text(
                    username,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Profile picture - positioned to overlap the curved edge by 50%
                Positioned(
                  bottom: -60, // This makes it overlap by 50%
                  child: GestureDetector(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      backgroundImage: _userProfileData?['profilePictureUrl']?.isNotEmpty == true
                          ? NetworkImage(_userProfileData!['profilePictureUrl'])
                          : AssetImage('assetsprofile/.jpg') as ImageProvider,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Space to account for the overlapping profile picture
          SizedBox(height: 70),

          // Profile details list
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              children: [
                buildProfileItem(
                  'assets/icons/user_id.png',
                  'Username',
                  username,
                ),
                Divider(height: 1),
                buildProfileItem(
                  'assets/icons/email.png',
                  'Email',
                  email,
                ),
                Divider(height: 1),
                GestureDetector(
                  child: buildProfileItem(
                    'assets/icons/home.png',
                    'Home Address',
                    homeAddress,
                  ),
                ),
                Divider(height: 1),
                buildProfileItem(
                  'assets/icons/work.png',
                  'Work Address',
                  workAddress,
                ),
                Divider(height: 1),
                buildProfileItem(
                  'assets/icons/connected.png',
                  'Connected Accounts',
                  '',
                ),
              ],
            ),
          ),

          // Edit button
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Changed navigation to redirect to AccountLoginPage instead
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: Text(
                    'Edit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Bottom space to account for navigation bar or home indicator
          SizedBox(height: 10),
        ],
      ),
    );
  }

  // Custom widget for profile items with custom icons
  Widget buildProfileItem(String iconAsset, String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Since the design appears to use custom icons, we'll use Image instead of Icon
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: getIconForTitle(title),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, color: Colors.grey)),
                SizedBox(height: 4),
                Text(
                  value.isEmpty ? ' ' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get the appropriate icon for each profile item
  Widget getIconForTitle(String title) {
    // You should replace these with custom icons that match the design
    switch (title) {
      case 'Username':
        return Icon(Icons.badge, size: 24, color: Colors.black);
      case 'Email':
        return Icon(Icons.email, size: 24, color: Colors.black);
      case 'Home Address':
        return Icon(Icons.home, size: 24, color: Colors.black);
      case 'Work Address':
        return Icon(Icons.work, size: 24, color: Colors.black);
      case 'Connected Accounts':
        return Icon(Icons.people, size: 24, color: Colors.black);
      default:
        return Icon(Icons.circle, size: 24, color: Colors.black);
    }
  }
}

// The rest of your code (AccountLoginPage, etc.) remains unchanged