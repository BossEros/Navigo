import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:project_navigo/screens/hamburger_menu_screens/hamburger-menu.dart';
import 'package:project_navigo/services/user_service.dart';
import 'package:project_navigo/models/user_profile.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/services/google-api-services.dart' as api;
import 'package:project_navigo/services/storage_service.dart';

import '../../component/reusable-location-search_screen.dart';
import '../../services/user_provider.dart';
import '../../widgets/profile_image.dart';
import 'package:project_navigo/component/reusable-location-search_screen.dart'; // Import our new component

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State variables
  User? _currentUser;
  Map<String, dynamic>? _userProfileData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Address data for home and work
  Address _homeAddress = Address.empty();
  Address _workAddress = Address.empty();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUser != null) {
        // First try to get profile from UserProvider (more efficient)
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // If UserProvider already has the profile, use it
        if (userProvider.userProfile != null) {
          final profile = userProvider.userProfile!;
          setState(() {
            _userProfileData = {
              'username': profile.username,
              'email': profile.email,
              'homeAddress': {
                'formattedAddress': profile.homeAddress.formattedAddress,
                'lat': profile.homeAddress.lat,
                'lng': profile.homeAddress.lng,
                'placeId': profile.homeAddress.placeId,
              },
              'workAddress': {
                'formattedAddress': profile.workAddress.formattedAddress,
                'lat': profile.workAddress.lat,
                'lng': profile.workAddress.lng,
                'placeId': profile.workAddress.placeId,
              },
              'profileImageUrl': profile.profileImageUrl,
              'profileImagePath': profile.profileImagePath,
            };
            _isLoading = false;
          });

          // Set up the address objects
          _homeAddress = profile.homeAddress;
          _workAddress = profile.workAddress;

          return; // Early return if we got data from UserProvider
        }

        // Fall back to fetching from Firestore directly if needed
        final userService = Provider.of<UserService>(context, listen: false);
        final userProfile = await userService.getUserProfile(_currentUser!.uid);

        setState(() {
          _userProfileData = {
            'username': userProfile.username,
            'email': userProfile.email,
            'homeAddress': {
              'formattedAddress': userProfile.homeAddress.formattedAddress,
              'lat': userProfile.homeAddress.lat,
              'lng': userProfile.homeAddress.lng,
              'placeId': userProfile.homeAddress.placeId,
            },
            'workAddress': {
              'formattedAddress': userProfile.workAddress.formattedAddress,
              'lat': userProfile.workAddress.lat,
              'lng': userProfile.workAddress.lng,
              'placeId': userProfile.workAddress.placeId,
            },
            'profileImageUrl': userProfile.profileImageUrl,
            'profileImagePath': userProfile.profileImagePath,
          };

          // Initialize address objects
          _homeAddress = Address(
            formattedAddress: userProfile.homeAddress.formattedAddress,
            lat: userProfile.homeAddress.lat,
            lng: userProfile.homeAddress.lng,
            placeId: userProfile.homeAddress.placeId,
          );

          _workAddress = Address(
            formattedAddress: userProfile.workAddress.formattedAddress,
            lat: userProfile.workAddress.lat,
            lng: userProfile.workAddress.lng,
            placeId: userProfile.workAddress.placeId,
          );

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

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Get the UserService from Provider
      final userService = Provider.of<UserService>(context, listen: false);

      // Update the user profile with structured address data
      await userService.updateUserProfile(
        userId: _currentUser!.uid,
        homeAddress: _homeAddress,
        workAddress: _workAddress,
      );

      // Update local data
      setState(() {
        _userProfileData = {
          ..._userProfileData!,
          'homeAddress': {
            'formattedAddress': _homeAddress.formattedAddress,
            'lat': _homeAddress.lat,
            'lng': _homeAddress.lng,
            'placeId': _homeAddress.placeId,
          },
          'workAddress': {
            'formattedAddress': _workAddress.formattedAddress,
            'lat': _workAddress.lat,
            'lng': _workAddress.lng,
            'placeId': _workAddress.placeId,
          },
        };
        _isEditing = false;
        _isSaving = false;
      });

      // Refresh user provider data
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }

  // In profile.dart - _pickProfileImage method
  Future<void> _pickProfileImage() async {
    if (!_isEditing) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get the current user
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('No authenticated user');

        // Convert XFile to File
        final File imageFile = File(image.path);

        // Get services
        final storageService = Provider.of<StorageService>(context, listen: false);
        final userService = Provider.of<UserService>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // Get current profile data
        String? oldImagePath;

        // First check the UserProvider (most up-to-date source)
        if (userProvider.userProfile?.profileImagePath != null) {
          oldImagePath = userProvider.userProfile?.profileImagePath;
          print('Found image path in UserProvider: $oldImagePath');
        }
        // Fall back to local state if needed
        else if (_userProfileData != null &&
            _userProfileData!['profileImagePath'] != null &&
            _userProfileData!['profileImagePath'].isNotEmpty) {
          oldImagePath = _userProfileData!['profileImagePath'];
          print('Found image path in local state: $oldImagePath');
        }

        // Delete old profile picture if exists
        if (oldImagePath != null) {
          print('Deleting previous profile image...');
          await storageService.deleteProfileImage(oldImagePath);
        } else {
          print('No previous profile image found to delete');
        }

        // Upload new image
        final uploadResult = await storageService.uploadProfileImage(user.uid, imageFile);
        final downloadUrl = uploadResult['url']!;
        final storagePath = uploadResult['path']!;

        print('New image uploaded to: $storagePath');
        print('New image URL: $downloadUrl');

        // Update user profile with new image URL
        await userService.updateProfilePicture(
          userId: user.uid,
          imageUrl: downloadUrl,
          imagePath: storagePath,
        );

        // Refresh the UserProvider to update all UI components
        await userProvider.refreshUserData();

        // Update local state (important for profile screen)
        setState(() {
          if (_userProfileData != null) {
            _userProfileData = {
              ..._userProfileData!,
              'profileImageUrl': downloadUrl,
              'profileImagePath': storagePath,
            };
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      } catch (e) {
        print('Error updating profile picture: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile picture: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // New method to open location search screen
  Future<void> _openLocationSearch(String type) async {
    // First, hide keyboard if showing
    FocusScope.of(context).unfocus();

    try {
      // Get current location for distance calculations only
      LatLng? currentLocation;
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        currentLocation = LatLng(position.latitude, position.longitude);
      } catch (e) {
        print('Error getting current location: $e');
        // Continue without current location, distances won't be shown
      }

      // Navigate to our enhanced location search screen
      // Note: initialQuery is now an empty string, and showSuggestionButtons is false
      final api.Place? selectedPlace = await Navigator.push<api.Place>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationSearchScreen(
            title: type == 'home' ? 'Set Home Address' : 'Set Work Address',
            searchHint: 'Search for your ${type == 'home' ? 'home' : 'work'} address',
            initialQuery: '', // Always start with an empty search bar
            currentLocation: currentLocation, // For distance calculations only
            showSuggestionButtons: false, // Don't show 'Current Location' and 'Nearby Places' buttons
          ),
        ),
      );

      if (selectedPlace != null) {
        // Create address object from selected place
        final newAddress = Address(
          formattedAddress: selectedPlace.address,
          lat: selectedPlace.latLng.latitude,
          lng: selectedPlace.latLng.longitude,
          placeId: selectedPlace.id,
        );

        // Update the appropriate address
        setState(() {
          if (type == 'home') {
            _homeAddress = newAddress;
          } else if (type == 'work') {
            _workAddress = newAddress;
          }
        });

        // Show confirmation with enhanced animation and details
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(type == 'home' ? Icons.home : Icons.work, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        type == 'home' ? 'Home address updated' : 'Work address updated',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        selectedPlace.address,
                        style: TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error with place search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Use the username from _userProfileData if available, otherwise fallback
    final username = userProvider.userProfile?.username ??
        _userProfileData?['username'] ??
        'User';

    final email = userProvider.userProfile?.email ??
        _userProfileData?['email'] ??
        'No email available';

    final profileImageUrl = userProvider.userProfile?.profileImageUrl ??
        _userProfileData?['profileImageUrl'];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Shortened blue header with username and profile pic
            Container(
              height: 160, // Reduced height for shorter gradient
              width: double.infinity, // Ensure full width
              child: Stack(
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
                ],
              ),
            ),

            // Profile picture - improved positioning
            Transform.translate(
              offset: Offset(0, -70),
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Profile picture container
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: profileImageUrl != null && profileImageUrl.isNotEmpty
                            ? Image.network(
                          profileImageUrl,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading profile image: $error');
                            return Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[400],
                            );
                          },
                          cacheWidth: 240, // Set to double the display size for quality
                          key: ValueKey(DateTime.now().toString()),
                        )
                            : Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),

                    // Camera icon for editing
                    if (_isEditing && !_isLoading)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),

                    // Loading indicator overlay
                    if (_isLoading)
                      Positioned.fill(
                        child: ClipOval(
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Space to account for the overlapping profile picture (reduced since we use Transform)
            SizedBox(height: 0),

            // Profile details list
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(  // Changed from ListView to Column
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User detail items remain the same
                  buildProfileItem(
                    title: 'Username',
                    value: username,
                    icon: Icons.badge,
                    isEditable: false,
                  ),
                  Divider(height: 1),

                  buildProfileItem(
                    title: 'Email',
                    value: email,
                    icon: Icons.email,
                    isEditable: false,
                  ),
                  Divider(height: 1),

                  buildAddressItem(
                    title: 'Home Address',
                    address: _homeAddress,
                    icon: Icons.home,
                    isEditable: _isEditing,
                    onEditTap: () => _openLocationSearch('home'),
                  ),
                  Divider(height: 1),

                  buildAddressItem(
                    title: 'Work Address',
                    address: _workAddress,
                    icon: Icons.work,
                    isEditable: _isEditing,
                    onEditTap: () => _openLocationSearch('work'),
                  ),
                  Divider(height: 1),
                ],
              ),
            ),

            // Add spacer to push button to bottom while maintaining layout
            Spacer(),

            // Edit/Save button
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: buildEditButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for non-address profile items
  Widget buildProfileItem({
    required String title,
    required String value,
    required IconData icon,
    required bool isEditable,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: Colors.black),
          ),
          SizedBox(width: 20),

          // Text content
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

  // Special widget for address items - updated with new Material Design visuals
  Widget buildAddressItem({
    required String title,
    required Address address,
    required IconData icon,
    required bool isEditable,
    required VoidCallback onEditTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: Colors.black),
          ),
          SizedBox(width: 20),

          // Address content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, color: Colors.grey)),
                SizedBox(height: 4),

                // In edit mode, make this a button to open address picker
                if (isEditable)
                  InkWell(
                    onTap: onEditTap,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              address.formattedAddress.isEmpty
                                  ? 'Tap to set location'
                                  : address.formattedAddress,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: address.formattedAddress.isEmpty
                                    ? Colors.grey.shade600
                                    : Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.search,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    address.formattedAddress.isEmpty ? 'Not set' : address.formattedAddress,
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

  // Improved edit button with animation and state changes
  Widget buildEditButton() {
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading || _isSaving ? null : () {
          if (_isEditing) {
            _saveChanges();
          } else {
            setState(() => _isEditing = true);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEditing ? Colors.green : Colors.blue,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          // Add padding to ensure text stays centered
          padding: EdgeInsets.zero,
        ),
        child: _isSaving
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center, // Center the loading indicator
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text('Saving...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        )
            : Center( // Explicitly center the text
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center row contents
            mainAxisSize: MainAxisSize.min, // Use minimum size for row
            children: [
              Icon(_isEditing ? Icons.save : Icons.edit),
              SizedBox(width: 8),
              Text(
                _isEditing ? 'Save Changes' : 'Edit Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom path clipper for the curved header
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