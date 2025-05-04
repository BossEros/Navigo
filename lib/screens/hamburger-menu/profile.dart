import 'dart:math';

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

class SuccessOverlay {
  static void show(
      BuildContext context, {
        required String title,
        required String message,
        required IconData icon,
        Color? color,
        Duration duration = const Duration(seconds: 2),
      }) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Create an overlay entry
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    // Set default color if not provided
    color = color ?? Colors.green;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Positioned(
              top: 100 + (40 * (1 - value)), // Slide down animation
              left: 20,
              right: 20,
              child: Opacity(
                opacity: value,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Color.lerp(Colors.grey[900], color, 0.15)
                          : Color.lerp(Colors.white, color, 0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: color!.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                      border: Border.all(
                          color: color.withOpacity(0.5),
                          width: 1.5
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animated icon
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: color?.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    icon,
                                    color: color,
                                    size: 28,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 16),

                        // Text content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: AppTypography.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: AppTypography.textTheme.bodyMedium?.copyWith(
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // Add the overlay
    overlayState.insert(overlayEntry);

    // Remove after the specified duration
    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}

class AnimatedProfileSuccessDialog extends StatefulWidget {
  final String title;
  final String message;

  const AnimatedProfileSuccessDialog({
    Key? key,
    required this.title,
    required this.message
  }) : super(key: key);

  @override
  _AnimatedProfileSuccessDialogState createState() => _AnimatedProfileSuccessDialogState();
}

class _AnimatedProfileSuccessDialogState extends State<AnimatedProfileSuccessDialog>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: AppTypography.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

      // Show success overlay instead of SnackBar
      SuccessOverlay.show(
        context,
        title: 'Profile Updated',
        message: 'Your profile has been updated successfully.',
        icon: Icons.check_circle,
        color: Colors.green,
      );
    } catch (e) {
      print('Error updating profile: $e');
      setState(() {
        _isSaving = false;
      });

      // Show error overlay
      SuccessOverlay.show(
        context,
        title: 'Update Failed',
        message: 'There was an error updating your profile.',
        icon: Icons.error_outline,
        color: Colors.red,
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

        // Show success overlay with avatar icon
        SuccessOverlay.show(
          context,
          title: 'Profile Picture Updated',
          message: 'Your profile picture has been updated successfully.',
          icon: Icons.person,
          color: Colors.blue,
        );
      } catch (e) {
        print('Error updating profile picture: $e');

        // Show error overlay
        SuccessOverlay.show(
          context,
          title: 'Update Failed',
          message: 'There was an error updating your profile picture.',
          icon: Icons.error_outline,
          color: Colors.red,
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

        // Show success overlay with appropriate icon
        SuccessOverlay.show(
          context,
          title: type == 'home' ? 'Home Address Updated' : 'Work Address Updated',
          message: selectedPlace.address,
          icon: type == 'home' ? Icons.home : Icons.work,
          color: type == 'home' ? Colors.green : Colors.blue,
        );
      }
    } catch (e) {
      print('Error with place search: $e');

      // Show error overlay
      SuccessOverlay.show(
        context,
        title: 'Update Failed',
        message: 'There was an error updating your address.',
        icon: Icons.error_outline,
        color: Colors.red,
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