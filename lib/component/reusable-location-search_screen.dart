import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/services/google-api-services.dart' as api;
import 'package:geolocator/geolocator.dart';

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
              SnackBar(content: Text('Error getting place suggestions: $e')),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not get details for the selected place')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting place details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.search, color: Colors.grey[600]),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[600]),
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
                      color: Colors.grey[600],
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
                      color: Colors.grey[600],
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Getting your location for distance calculation...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Search results
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching places...'),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return _buildSearchSuggestions();
    }

    if (_placeSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No places found for "${_searchController.text}"',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or check your internet connection',
              style: TextStyle(color: Colors.grey[600]),
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
        return ListTile(
          leading: Icon(Icons.location_on, color: Colors.grey[600]),
          title: Text(suggestion.mainText),
          subtitle: Text(
            suggestion.secondaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            _calculateDistance(suggestion) == "-"
                ? "-"
                : "${_calculateDistance(suggestion)} km",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          onTap: () => _selectPlace(suggestion),
        );
      },
    );
  }

  Widget _buildSearchSuggestions() {
    // If we shouldn't show suggestion buttons, just show a placeholder message
    if (!widget.showSuggestionButtons) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey[300]),
              SizedBox(height: 16),
              Text(
                'Start typing to search for a location',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'You can search by address, neighborhood, or landmark',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Otherwise, show the standard suggestion buttons
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          // Recent searches or common locations
          _buildSuggestionItem(
            'Current Location',
            Icons.my_location,
                () {
              // Handle current location selection
            },
          ),
          _buildSuggestionItem(
            'Nearby Places',
            Icons.place,
                () {
              // Handle nearby places selection
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String text, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(text),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}