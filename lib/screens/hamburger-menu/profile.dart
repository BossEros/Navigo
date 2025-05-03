import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import 'package:project_navigo/services/user_service.dart';
import 'package:project_navigo/models/user_profile.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/services/google-api-services.dart' as api;
import 'package:project_navigo/services/storage_service.dart';
import '../../component/reusable-location-search_screen.dart';
import '../../services/user_provider.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:project_navigo/themes/theme_provider.dart';

import '../../widgets/profile_image.dart';

/// A utility class for profile screen icons to maintain consistency
class ProfileIcons {
  // Standard constants
  static const double size = 20.0;

  // Icon methods - Made theme-aware
  static Widget username(bool isDarkMode) => FaIcon(
    FontAwesomeIcons.idBadge,
    size: size,
    color: isDarkMode ? Colors.white70 : Colors.black87,
  );
  static Widget email(bool isDarkMode) => FaIcon(
    FontAwesomeIcons.envelope,
    size: size,
    color: isDarkMode ? Colors.white70 : Colors.black87,
  );
  static Widget home(bool isDarkMode) => FaIcon(
    FontAwesomeIcons.house,
    size: size,
    color: isDarkMode ? Colors.white70 : Colors.black87,
  );
  static Widget work(bool isDarkMode) => FaIcon(
    FontAwesomeIcons.briefcase,
    size: size,
    color: isDarkMode ? Colors.white70 : Colors.black87,
  );
  static Widget edit() => FaIcon(
    FontAwesomeIcons.penToSquare,
    size: size,
    color: Colors.white,
  );
  static Widget save() => FaIcon(
    FontAwesomeIcons.floppyDisk,
    size: size,
    color: Colors.white,
  );
  static Widget search() => FaIcon(
    FontAwesomeIcons.magnifyingGlass,
    size: size,
    color: Colors.blue,
  );
  static Widget camera() => FaIcon(
    FontAwesomeIcons.camera,
    size: 16,
    color: Colors.white,
  );
}

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
        SnackBar(
          content: Text(
            'Profile updated successfully',
            style: AppTypography.textTheme.bodyMedium,
          ),
        ),
      );
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: $e',
            style: AppTypography.textTheme.bodyMedium,
          ),
        ),
      );
    }
  }

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
          SnackBar(
            content: Text(
              'Profile picture updated successfully',
              style: AppTypography.textTheme.bodyMedium,
            ),
          ),
        );
      } catch (e) {
        print('Error updating profile picture: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating profile picture: $e',
              style: AppTypography.textTheme.bodyMedium,
            ),
          ),
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
                type == 'home'
                    ? ProfileIcons.home(false)
                    : ProfileIcons.work(false),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        type == 'home' ? 'Home address updated' : 'Work address updated',
                        style: AppTypography.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        selectedPlace.address,
                        style: AppTypography.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
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
        SnackBar(
          content: Text(
            'Error searching for location: $e',
            style: AppTypography.textTheme.bodyMedium,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme provider to check for dark mode
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final userProvider = Provider.of<UserProvider>(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
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
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTypography.textTheme.headlineSmall?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: FaIcon(
            FontAwesomeIcons.arrowLeft,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Shortened blue header with profile pic
            Container(
              height: 120, // Reduced height from 160 to 120
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
                            colors: isDarkMode
                                ? [Colors.blue.shade700, Colors.blue.shade900]
                                : [Colors.lightBlue.shade300, Colors.blue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Profile picture with improved positioning
            Transform.translate(
              offset: Offset(0, -60), // Changed from -70 to -60
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Use ProfileImageWidget instead of direct Image.network
                    ProfileImageWidget(
                      imageUrl: profileImageUrl,
                      size: 120,
                      isLoading: _isLoading,
                    ),

                    // Camera icon for editing (keep this part unchanged)
                    if (_isEditing && !_isLoading)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ProfileIcons.camera(),
                      ),

                    // Loading indicator overlay (keep this part unchanged)
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

            // No padding here - removing vertical space

            // Profile details list
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: ListView(
                  // Remove the physics property to use default scroll physics
                  children: [
                    // Username
                    buildProfileItem(
                      title: 'Username',
                      value: username,
                      icon: ProfileIcons.username(isDarkMode),
                      isEditable: false,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      height: 1,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    ),

                    // Email
                    buildProfileItem(
                      title: 'Email',
                      value: email,
                      icon: ProfileIcons.email(isDarkMode),
                      isEditable: false,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      height: 1,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    ),

                    // Home Address
                    buildAddressItem(
                      title: 'Home Address',
                      address: _homeAddress,
                      icon: ProfileIcons.home(isDarkMode),
                      isEditable: _isEditing,
                      onEditTap: () => _openLocationSearch('home'),
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      height: 1,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    ),

                    // Work Address
                    buildAddressItem(
                      title: 'Work Address',
                      address: _workAddress,
                      icon: ProfileIcons.work(isDarkMode),
                      isEditable: _isEditing,
                      onEditTap: () => _openLocationSearch('work'),
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      height: 1,
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    ),

                    // Add some bottom spacing for better appearance
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Edit/Save button at the bottom
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20), // Reduced vertical padding
                child: buildEditButton(isDarkMode),
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
    required Widget icon,
    required bool isEditable,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10), // Reduced from 12 to 10
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: icon,
          ),
          SizedBox(width: 20),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value.isEmpty ? ' ' : value,
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : null,
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
    required Widget icon,
    required bool isEditable,
    required VoidCallback onEditTap,
    required bool isDarkMode,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10), // Reduced from 12 to 10
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: icon,
          ),
          SizedBox(width: 20),

          // Address content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  ),
                ),
                SizedBox(height: 4),

                // In edit mode, make this a button to open address picker
                if (isEditable)
                  InkWell(
                    onTap: onEditTap,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey.shade50,
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
                              style: AppTypography.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: address.formattedAddress.isEmpty
                                    ? isDarkMode ? Colors.grey[400] : Colors.grey.shade600
                                    : isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          ProfileIcons.search(),
                        ],
                      ),
                    ),
                  )
                else
                  Text(
                    address.formattedAddress.isEmpty ? 'Not set' : address.formattedAddress,
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : null,
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
  Widget buildEditButton(bool isDarkMode) {
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
          elevation: isDarkMode ? 2 : 3,
          shadowColor: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.3),
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
            Text(
              'Saving...',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        )
            : Center( // Explicitly center the text
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center row contents
            mainAxisSize: MainAxisSize.min, // Use minimum size for row
            children: [
              _isEditing ? ProfileIcons.save() : ProfileIcons.edit(),
              SizedBox(width: 8),
              Text(
                _isEditing ? 'Save Changes' : 'Edit Profile',
                style: AppTypography.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
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