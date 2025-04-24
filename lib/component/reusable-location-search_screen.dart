import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/services/google-api-services.dart' as api;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/themes/theme_provider.dart';
import 'package:project_navigo/themes/app_theme.dart';
import 'package:project_navigo/themes/app_typography.dart';

/// A reusable location search screen that matches the main app's search experience.
/// Returns the selected [api.Place] when a location is chosen.
class LocationSearchScreen extends StatefulWidget {
  final String title;
  final String initialQuery;
  final String searchHint;
  final LatLng? currentLocation;
  final bool showSuggestionButtons; // New parameter to control suggestion buttons

  const LocationSearchScreen({
    Key? key,
    required this.title,
    this.initialQuery = '',
    this.searchHint = 'Search for a location',
    this.currentLocation,
    this.showSuggestionButtons = true, // Default to showing suggestion buttons
  }) : super(key: key);

  @override
  _LocationSearchScreenState createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<api.PlaceSuggestion> _placeSuggestions = [];
  bool _isSearching = false;
  Timer? _debounce;
  Map<String, String> _suggestionDistances = {};
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;

    // Initialize current location if provided
    if (widget.currentLocation != null) {
      _currentLocation = widget.currentLocation;
    } else {
      _getCurrentLocation();
    }

    // Auto-focus the search field when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Get current device location
  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
      });
    }

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Location permissions are denied, can't get current location
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Location permissions are permanently denied
        return;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    // Cancel any existing debounce timer
    _debounce?.cancel();

    // Set a new debounce timer
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isNotEmpty) {
        setState(() {
          _isSearching = true;
          _placeSuggestions = []; // Clear previous results while searching
        });

        try {
          // Fetch suggestions using the Google Places API
          final suggestions = await api.GoogleApiServices.getPlaceSuggestions(query);

          // Only update state if the component is still mounted and the search text hasn't changed
          if (mounted && _searchController.text == query) {
            setState(() {
              _placeSuggestions = suggestions;
              _isSearching = false;
            });

            // Calculate distances for all suggestions
            if (_currentLocation != null) {
              _updateAllSuggestionDistances();
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error getting place suggestions: $e',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isSearching = false;
            });
          }
        }
      } else {
        setState(() {
          _placeSuggestions = [];
          _isSearching = false;
        });
      }
    });
  }

  // Calculate distances for all displayed suggestions
  void _updateAllSuggestionDistances() {
    for (var suggestion in _placeSuggestions) {
      if (!_suggestionDistances.containsKey(suggestion.placeId)) {
        _calculateDistanceAsync(suggestion);
      }
    }
  }

  // Calculate distance for a single suggestion
  String _calculateDistance(api.PlaceSuggestion suggestion) {
    // Return cached distance if available
    if (_suggestionDistances.containsKey(suggestion.placeId)) {
      return _suggestionDistances[suggestion.placeId]!;
    }

    // Start a background calculation if we have location
    if (_currentLocation != null) {
      _calculateDistanceAsync(suggestion);
    }

    // Return a placeholder while calculating
    return "-";
  }

  // Asynchronously calculate the distance for a suggestion
  Future<void> _calculateDistanceAsync(api.PlaceSuggestion suggestion) async {
    try {
      // Get place details to access its coordinates
      final place = await api.GoogleApiServices.getPlaceDetails(suggestion.placeId);

      if (place != null && _currentLocation != null && mounted) {
        // Calculate distance using the Haversine formula
        final distanceInMeters = _calculateDistance2(
            _currentLocation!,
            place.latLng
        );

        // Format the distance appropriately
        String formattedDistance;
        if (distanceInMeters < 1000) {
          formattedDistance = "${distanceInMeters.toInt()} m";
        } else {
          formattedDistance = "${(distanceInMeters / 1000).toStringAsFixed(1)}";
        }

        // Update the cache and trigger a UI refresh
        if (mounted) {
          setState(() {
            _suggestionDistances[suggestion.placeId] = formattedDistance;
          });
        }
      }
    } catch (e) {
      print('Error calculating distance for ${suggestion.placeId}: $e');
    }
  }

  // Haversine formula for calculating distance between two coordinates
  double _calculateDistance2(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double lon1 = point1.longitude * pi / 180;
    final double lon2 = point2.longitude * pi / 180;

    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;

    final double a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) *
            sin(dLon/2) * sin(dLon/2);
    final double c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c;
  }

  Future<void> _selectPlace(api.PlaceSuggestion suggestion) async {
    try {
      // Close keyboard
      FocusScope.of(context).unfocus();

      setState(() {
        _isSearching = true;
      });

      // Get place details
      final place = await api.GoogleApiServices.getPlaceDetails(suggestion.placeId);

      if (place != null && mounted) {
        // Return the selected place to the calling screen
        Navigator.of(context).pop(place);
      } else {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });

          // Get theme state for proper styling
          final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
          final isDarkMode = themeProvider.isDarkMode;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not get details for the selected place',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              backgroundColor: isDarkMode ? Colors.red[700] : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });

        // Get theme state for proper styling
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        final isDarkMode = themeProvider.isDarkMode;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error getting place details: $e',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
            backgroundColor: isDarkMode ? Colors.red[700] : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply theme-aware background color
      backgroundColor: isDarkMode
          ? AppTheme.darkTheme.scaffoldBackgroundColor
          : AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        // Apply theme-aware AppBar styling
        backgroundColor: isDarkMode
            ? AppTheme.darkTheme.appBarTheme.backgroundColor
            : Colors.white,
        foregroundColor: isDarkMode
            ? AppTheme.darkTheme.appBarTheme.foregroundColor
            : Colors.black,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                // Theme-aware search bar background
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.search,
                      // Theme-aware icon color
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      // Theme-aware text styling
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        border: InputBorder.none,
                        // Theme-aware hint text
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      // Theme-aware icon color
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _placeSuggestions = [];
                        });
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.mic),
                      // Theme-aware icon color
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      onPressed: () {
                        // Voice search functionality
                      },
                    ),
                ],
              ),
            ),
          ),

          // Location status indicator (when getting current location)
          if (_isLoadingLocation)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      // Theme-aware progress indicator color
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDarkMode ? Colors.white : Colors.blue,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Getting your location for distance calculation...',
                    style: TextStyle(
                      fontSize: 14,
                      // Theme-aware text color
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          // Search results
          Expanded(
            child: _buildSearchResults(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDarkMode) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              // Theme-aware progress indicator color
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? Colors.white : Colors.blue,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Searching places...',
              style: TextStyle(
                // Theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return _buildSearchSuggestions(isDarkMode);
    }

    if (_placeSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              // Theme-aware icon color
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No places found for "${_searchController.text}"',
              style: TextStyle(
                fontSize: 16,
                // Theme-aware text color
                color: isDarkMode ? Colors.white : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or check your internet connection',
              style: TextStyle(
                // Theme-aware text color
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _placeSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _placeSuggestions[index];
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            // Theme-aware item background
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(10),
            // Theme-aware shadow
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            leading: Icon(
              Icons.location_on,
              // Theme-aware icon color
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            title: Text(
              suggestion.mainText,
              style: TextStyle(
                // Theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              suggestion.secondaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // Theme-aware subtitle color
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            trailing: Text(
              _calculateDistance(suggestion) == "-"
                  ? "-"
                  : "${_calculateDistance(suggestion)} km",
              style: TextStyle(
                // Theme-aware text color
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            onTap: () => _selectPlace(suggestion),
          ),
        );
      },
    );
  }

  Widget _buildSearchSuggestions(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 64,
              // Theme-aware icon color
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
            ),
            SizedBox(height: 16),
            Text(
              'Start typing to search for a location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                // Theme-aware text color
                color: isDarkMode ? Colors.white : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'You can search by address, neighborhood, or landmark',
              style: TextStyle(
                // Theme-aware text color
                color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}