import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:async';
import '../config/config.dart';
import '../services/google-api-services.dart' as api hide Duration;
import 'package:project_navigo/screens/hamburger_menu_screens/hamburger-menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

enum NavigationState {
  idle,           // Initial state, no destination selected
  placeSelected,  // A destination is selected, showing place details
  routePreview,   // Showing route options before starting navigation
  activeNavigation // Actively navigating
}

class PulsatingMarkerPainter extends CustomPainter {
  final double radius;
  final Color color;
  final AnimationController controller;

  PulsatingMarkerPainter({
    required this.radius,
    required this.color,
    required this.controller,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(1 - controller.value)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius * (1 + controller.value),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigo',
      theme: ThemeData(
        primaryColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          primary: Colors.blue,
          secondary: Colors.amber,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const NavigoMapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NavigoMapScreen extends StatefulWidget {
  const NavigoMapScreen({Key? key}) : super(key: key);

  @override
  State<NavigoMapScreen> createState() => _NavigoMapScreenState();
}

// A state variable to control traffic visibility
bool _trafficEnabled = true;
String? _currentMapStyle;

final String? dayMapStyle = null; // Use null for default Google styling with traffic
final String navigationMapStyle = '''
[
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "weight": 3
      }
    ]
  }
]
''';
final String nightMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#38414e"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#212a37"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9ca5b3"
      }
    ]
  }
]
''';

class _NavigoMapScreenState extends State<NavigoMapScreen> with TickerProviderStateMixin {
  // Controllers
  GoogleMapController? _mapController;
  final PanelController _panelController = PanelController();
  final TextEditingController _searchController = TextEditingController();
  final Location _location = Location();

  // Location tracking
  LocationData? _currentLocation;
  final LatLng _defaultLocation = const LatLng(10.3157, 123.8854); // Cebu coordinates
  StreamSubscription<LocationData>? _locationSubscription;

  // Map elements
  final Map<MarkerId, Marker> _markersMap = {};
  final Map<PolylineId, Polyline> _polylinesMap = {};
  MapType _currentMapType = MapType.normal;
  bool _isLoadingPhotos = false;

  // Search state
  List<api.PlaceSuggestion> _placeSuggestions = [];
  bool _isSearching = false;
  Timer? _debounce;
  Map<String, String> _suggestionDistances = {};


  // Panel state
  double _panelPosition = 0.0;
  bool _isFullyExpanded = false;

  // Navigation state
  api.Place? _destinationPlace;
  bool _isNavigating = false;
  api.RouteDetails? _routeDetails;
  bool _isNavigationInProgress = false;

  bool _showingRouteAlternatives = false;
  int _selectedRouteIndex = 0;
  List<api.RouteDetails> _routeAlternatives = [];

  final PanelController _routePanelController = PanelController();
  bool _isRoutePanelExpanded = false;

  // Navigation state tracking
  bool _isInNavigationMode = false;
  int _currentStepIndex = 0;
  LatLng? _lastKnownLocation;
  double _navigationZoom = 17.5;
  double _navigationTilt = 45.0;
  double _navigationBearing = 0.0;
  Timer? _locationSimulationTimer; // For testing or demo purposes
  StreamSubscription<LocationData>? _navigationLocationSubscription;


  NavigationState _navigationState = NavigationState.idle;


  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initLocationService();
    _trafficEnabled = true;
    _currentMapStyle = _trafficEnabled ? null : dayMapStyle;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    _locationSubscription?.cancel();
    _navigationLocationSubscription?.cancel();
    _locationSimulationTimer?.cancel();
    _dummyFocusNode.dispose();
    super.dispose();
  }

  // A method to ensure consistent state
  void _updateNavigationState(NavigationState newState) {
    // Only update if the state is actually changing
    if (_navigationState == newState) return;

    setState(() {
      _navigationState = newState;

      // Ensure other flags are synchronized with the navigation state
      if (newState == NavigationState.placeSelected) {
        _showingRouteAlternatives = false;
        _isNavigating = false;
        _isInNavigationMode = false;
      } else if (newState == NavigationState.routePreview) {
        _showingRouteAlternatives = true;
        _isNavigating = false;
        _isInNavigationMode = false;
      } else if (newState == NavigationState.activeNavigation) {
        _showingRouteAlternatives = false;
        _isNavigating = true;
        _isInNavigationMode = true;
      } else if (newState == NavigationState.idle) {
        _showingRouteAlternatives = false;
        _isNavigating = false;
        _isInNavigationMode = false;
      }
    });

    // Debug logging to track state transitions
    print('Navigation state changed to: $newState');
  }

  Widget _buildSelectedPlaceCard() {
    if (_navigationState != NavigationState.placeSelected) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(  // Make the card scrollable to handle keyboard overlap
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Location name and address
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _destinationPlace!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _destinationPlace!.address,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Actions row - simplified to just Save and Navigate
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.bookmark_border,
                    label: 'Save',
                    onPressed: () {
                      // Save location functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${_destinationPlace!.name} saved to favorites')),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.navigation,
                    label: 'Navigate',
                    onPressed: _startNavigation,
                    isPrimary: true,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Photos section - only show place images, no add photo option
              Container(
                height: 120,
                padding: const EdgeInsets.only(left: 16),
                child: _destinationPlace!.photoUrls.isEmpty && _isLoadingPhotos
                    ? Center(
                  child: CircularProgressIndicator(),
                )
                    : _destinationPlace!.photoUrls.isEmpty
                    ? Center(
                  child: Text(
                    'No photos available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _destinationPlace!.photoUrls.length,
                  itemBuilder: (context, index) {
                    return _buildPhotoItem(_destinationPlace!.photoUrls[index]);
                  },
                ),
              ),

              // Information section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Operating hours may vary',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Display location type if available
                    if (_destinationPlace!.types.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            _getFormattedType(_destinationPlace!.types.first),
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to format place types for display
  String _getFormattedType(String type) {
    // Convert 'place_of_worship' to 'Place of Worship'
    return type.split('_').map((word) =>
    word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : ''
    ).join(' ');
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isPrimary ? Colors.blue : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isPrimary ? Colors.white : Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.blue : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPlacePhotos() async {
    if (_destinationPlace == null || _destinationPlace!.photoUrls.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingPhotos = true;
    });

    // Set a timeout for the entire operation
    try {
      final photos = await api.GoogleApiServices.getPlacePhotos(_destinationPlace!.id)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        // Return any photos loaded so far or empty list
        print('Photo loading timed out, returning partial results');
        return <String>[];
      });

      if (mounted) {
        setState(() {
          _destinationPlace!.photoUrls = photos;
          _isLoadingPhotos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPhotos = false;
        });
      }
    }
  }

  Widget _buildAddPhotoItem() {
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, color: Colors.blue, size: 32),
          const SizedBox(height: 8),
          Text(
            'Add photo',
            style: TextStyle(color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoItem(String imageUrl) {
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          headers: {
            'X-Goog-Api-Key': AppConfig.apiKey,
          },
          // Add loading and error handling
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.grey[400]),
              ),
            );
          },
        ),
      ),
    );
  }

  // 2. Add this utility method to your class
  void _ensureKeyboardHidden(BuildContext context) {
    // Hide keyboard by removing focus from any text field
    FocusScope.of(context).unfocus();

    // Additional safety - force native keyboard to dismiss using platform channel
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  // 3. Create a dummy focus node to redirect focus if needed
  final FocusNode _dummyFocusNode = FocusNode();

  Widget _buildNavigationTopButtons() {
    if (_navigationState != NavigationState.placeSelected)
      return const SizedBox.shrink();

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircularButton(
            icon: Icons.arrow_back,
            onPressed: () {
              // Handle back navigation - maybe a special case of _clearDestination
              _clearDestination();
              // Optionally open the panel (if it should always open on back press)
              if (mounted && _panelController != null) {
                Future.delayed(Duration(milliseconds: 100), () {
                  if (mounted && _panelController != null) {
                    _panelController.open();
                  }
                });
              }
            },
          ),

          _buildCircularButton(
            icon: Icons.close,
            onPressed: _handleCloseButtonPressed,
          ),
        ],
      ),
    );
  }

  void _handleCloseButtonPressed() {
    // 1. Capture the current state of important objects before changes
    final bool panelWasFullyOpen = _panelController.isPanelOpen && _panelPosition > 0.8;

    // 2. Update UI state - wrap in setState to trigger rebuild
    setState(() {
      // Clear the destination place (removes Location Details Card)
      _destinationPlace = null;

      // Reset navigation state to idle
      _navigationState = NavigationState.idle;

      // Clear route-related data if present
      _routeDetails = null;
      _routeAlternatives = [];
      _showingRouteAlternatives = false;
      _selectedRouteIndex = 0;

      // Remove any route visuals
      _polylinesMap.clear();

      // Remove destination markers
      if (_markersMap.containsKey(const MarkerId('destination'))) {
        _markersMap.remove(const MarkerId('destination'));
      }

      // Clear search text
      _searchController.clear();
      _placeSuggestions = [];
      _isSearching = false;
    });

    // 4. Set the panel position properly - after a small delay to ensure smooth transition
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return; // Safety check

      // Ensure panel is in the right position - minimize but don't close completely
      if (_panelController.isPanelShown) {
        if (panelWasFullyOpen) {
          // If panel was fully open, animate to minimized position
          _panelController.animatePanelToPosition(
            0.1, // Minimized position (adjust value to match your needs)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else if (!_panelController.isPanelShown) {
          // If panel was fully closed, open to minimized position
          _panelController.animatePanelToPosition(
            0.1, // Minimized position
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        // If panel isn't showing at all, show it minimized
        _panelController.animatePanelToPosition(
          0.1, // Minimized position
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Alternative approach using a cleaner state management pattern
  void _clearDestination() {
    // 1. First capture any values we need before cleaning up
    final panelWasOpen = _panelController?.isPanelOpen ?? false;

    // 2. Update the state synchronously
    setState(() {
      // Clear the destination
      _destinationPlace = null;

      // Clear the route data if present
      _routeDetails = null;
      _routeAlternatives = [];
      _showingRouteAlternatives = false;

      // Update navigation state
      _navigationState = NavigationState.idle;

      // Safely clean up markers
      if (_markersMap.containsKey(const MarkerId('destination'))) {
        _markersMap.remove(const MarkerId('destination'));
      }

      // Clear polylines
      _polylinesMap.clear();
    });

    // 3. Handle panel state changes after a short delay
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;

        // Safely handle panel controller actions
        if (_panelController != null) {
          try {
            if (panelWasOpen) {
              _panelController.close();
            } else {
              _panelController.open();
            }
          } catch (e) {
            print('Panel controller error: $e');
          }
        }

        // Safely clear search text
        if (_searchController != null) {
          _searchController.clear();
        }
      });
    }
  }

  Widget _buildRouteSelectionTopButtons() {
    if (_navigationState != NavigationState.routePreview)
      return const SizedBox.shrink();

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button to go to location details
          _buildCircularButton(
            icon: Icons.arrow_back,
            onPressed: () {
              // Go back to location details screen
              setState(() {
                _navigationState = NavigationState.placeSelected;
                _showingRouteAlternatives = false;
              });
            },
          ),

          // Close button (optional)
          _buildCircularButton(
            icon: Icons.close,
            onPressed: _handleCloseButtonPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationIndicator() {
    if (_destinationPlace == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          painter: PulsatingMarkerPainter(
            radius: 10,
            color: Colors.red.withOpacity(0.5),
            controller: _pulseController,
          ),
          child: child,
        );
      },
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // Get markers as a Set from the Map for the GoogleMap widget
  Set<Marker> get _markers => Set.of(_markersMap.values);

  // Get polylines as a Set from the Map for the GoogleMap widget
  Set<Polyline> get _polylines => Set.of(_polylinesMap.values);

  Future<void> _initLocationService() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          _showErrorSnackBar('Location services are disabled');
          return;
        }
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          _showErrorSnackBar('Location permission denied');
          return;
        }
      }

      // Configure location settings for better battery performance
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 10000, // 10 seconds
        distanceFilter: 10, // 10 meters
      );

      _locationSubscription = _location.onLocationChanged.listen(_updateCurrentLocation);
    } catch (e) {
      _showErrorSnackBar('Error initializing location: $e');
    }
  }

  void _updateCurrentLocation(LocationData locationData) {
    setState(() {
      _currentLocation = locationData;
      _updateCurrentLocationMarker();
    });
  }

  void _updateCurrentLocationMarker() {
    if (_currentLocation != null) {
      final LatLng position = LatLng(
        _currentLocation!.latitude ?? _defaultLocation.latitude,
        _currentLocation!.longitude ?? _defaultLocation.longitude,
      );

      final markerId = const MarkerId('currentLocation');

      final marker = Marker(
        markerId: markerId,
        position: position,
        infoWindow: const InfoWindow(title: 'Current Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );

      setState(() {
        _markersMap[markerId] = marker;

        if (!_isNavigating && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: position,
                zoom: 15,
              ),
            ),
          );
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    // Cancel any existing debounce timer.
    _debounce?.cancel();

    // Set a new debounce timer.
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isNotEmpty) {
        setState(() {
          _isSearching = true;
          _placeSuggestions = []; // Clear previous results while searching
        });

        try {
          print('Searching for: "$query"');
          // Fetch suggestions using the Google Places API.
          final suggestions = await api.GoogleApiServices.getPlaceSuggestions(query);

          // Only update state if the component is still mounted and the search text hasn't changed
          if (mounted && _searchController.text == query) {
            setState(() {
              _placeSuggestions = suggestions;
              _isSearching = false;
            });

            // Start calculating distances for all suggestions
            _updateAllSuggestionDistances();

            print('Found ${suggestions.length} suggestions for "$query"');
          }
        } catch (e) {
          if (mounted) {
            print('Search error caught in UI: $e');
            _showErrorSnackBar('Error getting place suggestions: $e');
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

  Future<void> _selectPlace(api.PlaceSuggestion suggestion) async {
    try {
      // Close keyboard
      FocusScope.of(context).unfocus();

      // Close the sliding panel
      _panelController.close();

      setState(() {
        _isSearching = true;
      });

      print('Getting details for place: ${suggestion.placeId}');
      final place = await api.GoogleApiServices.getPlaceDetails(suggestion.placeId);

      if (place != null && mounted) {
        // Load photos for the place
        try {
          final photos = await api.GoogleApiServices.getPlacePhotos(place.id);
          place.photoUrls = photos;
        } catch (e) {
          print('Error loading place photos: $e');
        }

        setState(() {
          _destinationPlace = place;
          _navigationState = NavigationState.placeSelected;  // Set the navigation state
          _searchController.text = place.name;
          _placeSuggestions = [];
          _isSearching = false;
        });

        _addDestinationMarker(place);
        _loadPlacePhotos();

        // Single smooth camera animation to the location
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: place.latLng,
              zoom: 16,
              tilt: 30,
            ),
          ),
        );

        print('Successfully set destination: ${place.name}');
      } else {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
          _showErrorSnackBar('Could not get details for the selected place.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _showErrorSnackBar('Error getting place details: $e');
      }
    }
  }

  void _addDestinationMarker(api.Place place) {
    final markerId = const MarkerId('destination');

    final marker = Marker(
      markerId: markerId,
      position: place.latLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      zIndex: 2,
    );

    // Add a bounce effect
    if (_mapController != null) {
      final markerId = const MarkerId('destination');

      // You could implement a simple bounce animation here
      // For a proper bouncing effect, you'd need to create a custom marker
      // with animation capabilities
    }

    setState(() {
      _markersMap[markerId] = marker;
    });
  }

  void _fitBoundsToDestination(api.Place place) {
    final currentLocation = _currentLocation != null
        ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
        : _defaultLocation;

    // This provides a tighter zoom when places are close
    _fitBounds([currentLocation, place.latLng], padding: 100);
  }


  Future<void> _startNavigation() async {
    _logNavigationEvent("Starting navigation");

    // Check prerequisites
    if (_destinationPlace == null || _currentLocation == null) {
      _showErrorSnackBar('Please select a destination first');
      return;
    }

    // Prevent duplicate navigation attempts
    if (_isNavigationInProgress) {
      _logNavigationEvent("Navigation already in progress - ignoring request");
      return;
    }

    _isNavigationInProgress = true;

    try {
      // Update UI state first
      setState(() {
        _navigationState = NavigationState.routePreview;
        _showingRouteAlternatives = true;
        _routeAlternatives = [];
      });

      // Close the panel if it's open
      try {
        if (_panelController.isPanelOpen) {
          _panelController.close();
        }
      } catch (panelError) {
        _logNavigationEvent("Panel close error", panelError);
        // Continue despite panel errors
      }

      // Prepare the origin point
      final origin = LatLng(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );

      _logNavigationEvent("Requesting directions", "${origin.latitude},${origin.longitude} -> ${_destinationPlace!.latLng.latitude},${_destinationPlace!.latLng.longitude}");

      // Request routes with alternatives set to true
      final routeDetails = await api.GoogleApiServices.getDirections(
        origin,
        _destinationPlace!.latLng,
        alternatives: true,
      );

      // Check if we're still mounted
      if (!mounted) {
        _logNavigationEvent("Widget no longer mounted after API call");
        return;
      }

      // Validate the response
      if (routeDetails == null) {
        _logNavigationEvent("Null route details received");
        throw Exception("No route data received from the API");
      }

      if (routeDetails.routes.isEmpty) {
        _logNavigationEvent("Empty routes list received");
        throw Exception("No routes available for this destination");
      }

      _logNavigationEvent("Received routes", "${routeDetails.routes.length} routes");

      // Process the route data
      try {
        setState(() {
          _routeAlternatives = [routeDetails];
          _selectedRouteIndex = 0;
          _routeDetails = routeDetails;
          _updateDisplayedRoute(0);
        });
        _logNavigationEvent("Route data updated");
      } catch (stateError) {
        _logNavigationEvent("Error updating route state", stateError);
        throw Exception("Failed to update route display: $stateError");
      }

      // Update the camera
      try {
        if (_mapController != null) {
          _logNavigationEvent("Updating camera");
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(routeDetails.routes[0].bounds, 50),
          );
          _logNavigationEvent("Camera updated");
        }
      } catch (cameraError) {
        _logNavigationEvent("Camera update error", cameraError);
        // Continue despite camera errors
      }

      // Handle the route panel
      try {
        if (_routePanelController.isAttached) {
          _routePanelController.close();
        }
      } catch (panelError) {
        _logNavigationEvent("Route panel handling error", panelError);
        // Continue despite panel errors
      }

    } catch (e) {
      _logNavigationEvent("Navigation error", e);

      // Only update UI if still mounted
      if (mounted) {
        _showErrorSnackBar('Failed to get directions. Please try again.');
        setState(() {
          _navigationState = NavigationState.placeSelected;
          _showingRouteAlternatives = false;
        });
      }
    } finally {
      // Always reset progress flag
      _isNavigationInProgress = false;
      _logNavigationEvent("Navigation process completed");
    }
  }

  // Method to update the displayed route
  void _updateDisplayedRoute(int routeIndex) {
    if (routeIndex < 0 || _routeAlternatives.isEmpty ||
        routeIndex >= _routeAlternatives[0].routes.length) return;

    setState(() {
      _selectedRouteIndex = routeIndex;
      _polylinesMap.clear();

      // Add all routes with different styles
      for (int i = 0; i < _routeAlternatives[0].routes.length; i++) {
        final route = _routeAlternatives[0].routes[i];
        final polylineId = PolylineId('route_$i');

        // Selected route gets primary color and higher width
        final isSelected = i == _selectedRouteIndex;

        final polyline = Polyline(
          polylineId: polylineId,
          points: route.polylinePoints,
          color: isSelected ? Colors.blue : Colors.grey,
          width: isSelected ? 7 : 4,
          zIndex: isSelected ? 2 : 1,
        );

        _polylinesMap[polylineId] = polyline;
      }
    });
  }

  void _stopNavigation() {
    _completeNavigationReset();
  }

  void _fitBounds(List<LatLng> points, {double padding = 50}) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    // Add some buffer for a smoother look
    final span = maxLat - minLat;
    final buffer = span * 0.1; // 10% buffer

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - buffer, minLng - buffer),
          northeast: LatLng(maxLat + buffer, maxLng + buffer),
        ),
        padding,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _defaultLocation,
                  zoom: 15,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  _updateCurrentLocationMarker();
                },
                markers: _markers,
                polylines: _polylines,
                mapType: _currentMapType,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                // Disable user gestures during navigation to prevent accidental map movement
                trafficEnabled: _trafficEnabled,
                style: _currentMapStyle,
                scrollGesturesEnabled: !_isInNavigationMode,
                zoomGesturesEnabled: !_isInNavigationMode,
                tiltGesturesEnabled: !_isInNavigationMode,
                rotateGesturesEnabled: !_isInNavigationMode
            ),

            // Original SlidingUpPanel for location search
            SlidingUpPanel(
              controller: _panelController,
              minHeight: (_destinationPlace != null || _showingRouteAlternatives) ? 0 : 100,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              onPanelSlide: (position) {
                setState(() {
                  _panelPosition = position;
                  _isFullyExpanded = position > 0.8;
                });
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              panel: _buildSearchPanel(),
              body: _buildMapView(),
            ),

            // Conditionally show the route selection panel
            if (_showingRouteAlternatives && _routeAlternatives.isNotEmpty)
              _buildRouteSelectionPanel(),

            // Navigation info panel - positioned at top of screen
            if (_isInNavigationMode)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildNavigationInfoPanel(),
              ),
          ],
        ),
      ),
    );
  }

  void _startLocationSimulation() {
    if (_routeDetails == null || _routeDetails!.routes.isEmpty) return;

    final route = _routeDetails!.routes[0];
    final points = route.polylinePoints;

    if (points.isEmpty) return;

    int pointIndex = 0;

    _locationSimulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (pointIndex >= points.length) {
        timer.cancel();
        return;
      }

      final point = points[pointIndex];

      // Calculate bearing to next point for realistic simulation
      double bearing = 0;
      if (pointIndex < points.length - 1) {
        bearing = _calculateBearing(
          points[pointIndex],
          points[pointIndex + 1],
        );
      }

      // Simulate a LocationData object
      final locationData = LocationData.fromMap({
        'latitude': point.latitude,
        'longitude': point.longitude,
        'heading': bearing,
        'accuracy': 5.0,
        'altitude': 0.0,
        'speed': 15.0, // simulate ~50 km/h
        'speed_accuracy': 1.0,
        'time': DateTime.now().millisecondsSinceEpoch,
      });

      _handleNavigationLocationUpdate(locationData);

      pointIndex++;
    });
  }

  // Calculate bearing between two points
  double _calculateBearing(LatLng start, LatLng end) {
    final double startLat = start.latitude * pi / 180;
    final double startLng = start.longitude * pi / 180;
    final double endLat = end.latitude * pi / 180;
    final double endLng = end.longitude * pi / 180;

    final double dLng = endLng - startLng;

    final double y = sin(dLng) * cos(endLat);
    final double x = cos(startLat) * sin(endLat) -
        sin(startLat) * cos(endLat) * cos(dLng);

    final double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360; // Normalize to 0-360
  }

  Widget _buildRouteSelectionPanel() {
    // Only show if we have routes
    if (!_showingRouteAlternatives || _routeAlternatives.isEmpty) {
      return const SizedBox.shrink();
    }

    return SlidingUpPanel(
      controller: _routePanelController,
      minHeight: 80, // Small preview height (adjust as needed)
      maxHeight: MediaQuery.of(context).size.height * 0.6, // Max 60% of screen
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      onPanelSlide: (position) {
        setState(() {
          _isRoutePanelExpanded = position > 0.5;
        });
      },
      collapsed: _buildCollapsedRoutePanel(),
      panel: _buildFullRoutePanel(),
    );
  }

  Widget _buildCollapsedRoutePanel() {
    if (_routeAlternatives.isEmpty) return const SizedBox.shrink();

    final route = _routeAlternatives[0].routes[_selectedRouteIndex];
    final leg = route.legs[0];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Route summary - concise information
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Navigation instructions
                Row(
                  children: [
                    Icon(Icons.directions, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      leg.duration.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      leg.distance.text,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),

                // Go button
                ElevatedButton(
                  onPressed: () {
                    _startActiveNavigation();
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('GO'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullRoutePanel() {
    if (_routeAlternatives.isEmpty) return const SizedBox.shrink();

    final routes = _routeAlternatives[0].routes;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Route info header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Your location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _destinationPlace?.name ?? 'Destination',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Routes list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                final leg = route.legs[0];

                // Determine if it's the best route
                final isBest = index == 0;

                return GestureDetector(
                  onTap: () {
                    _updateDisplayedRoute(index);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedRouteIndex == index
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: _selectedRouteIndex == index
                            ? Colors.blue
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time and distance row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  leg.duration.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                if (isBest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: const Text(
                                      'Best',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              leg.distance.text,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Route details
                        Text(
                          'Via ${_getRouteDescription(route)}',
                          style: TextStyle(
                            color: Colors.grey[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Traffic info
                        Text(
                          'Typical traffic',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    _showLeaveLaterDialog();
                  },
                  child: const Text('Leave later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _startActiveNavigation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(150, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Go now'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesPanel() {
    if (_routeAlternatives.isEmpty) return const SizedBox.shrink();

    final routes = _routeAlternatives[0].routes;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Route info header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Your location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _destinationPlace?.name ?? 'Destination',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Routes list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                final leg = route.legs[0];

                // Determine if it's the best route
                final isBest = index == 0;

                return GestureDetector(
                  onTap: () {
                    _updateDisplayedRoute(index);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedRouteIndex == index
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.white,
                      border: Border.all(
                        color: _selectedRouteIndex == index
                            ? Colors.blue
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time and distance row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  leg.duration.text,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                if (isBest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: const Text(
                                      'Best',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              leg.distance.text,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Route details
                        Text(
                          'Via ${_getRouteDescription(route)}',
                          style: TextStyle(
                            color: Colors.grey[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Traffic info
                        Text(
                          'Typical traffic',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getRouteDescription(api.Route route) {
    // This is a placeholder - in a real app, you'd extract the main roads
    // from the route instructions
    if (route.summary.isNotEmpty) {
      return route.summary;
    }

    // If no summary, try to extract from legs/steps
    if (route.legs.isNotEmpty && route.legs[0].steps.isNotEmpty) {
      // Get the longest step which is likely a major road
      var longestStep = route.legs[0].steps[0];
      for (var step in route.legs[0].steps) {
        if (step.distance.value > longestStep.distance.value) {
          longestStep = step;
        }
      }
      return extractRoadName(longestStep.instruction);
    }

    return "Unknown route";
  }

  String extractRoadName(String instruction) {
    // Simple algorithm to extract road names from instructions
    // This is a placeholder that should be improved for a real app
    if (instruction.contains(" onto ")) {
      return instruction.split(" onto ")[1].split("<")[0].trim();
    }
    if (instruction.contains(" on ")) {
      return instruction.split(" on ")[1].split("<")[0].trim();
    }
    return instruction.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  void _startActiveNavigation() {
    if (_routeAlternatives.isEmpty || _selectedRouteIndex >= _routeAlternatives[0].routes.length) {
      _showErrorSnackBar('No route selected');
      return;
    }

    // Use the helper method to ensure consistent state
    _updateNavigationState(NavigationState.activeNavigation);

    setState(() {
      // Additional state updates specific to active navigation
      _polylinesMap.clear();
      final polylineId = const PolylineId('active_route');
      final polyline = Polyline(
        polylineId: polylineId,
        points: _routeAlternatives[0].routes[_selectedRouteIndex].polylinePoints,
        color: Colors.blue,
        width: 7,
      );
      _polylinesMap[polylineId] = polyline;

      // Update route details to use the selected route
      _routeDetails = api.RouteDetails(
        routes: [_routeAlternatives[0].routes[_selectedRouteIndex]],
      );
    });

    print("Starting navigation mode. Traffic enabled: $_trafficEnabled");

    // Start more frequent location updates for navigation
    _startNavigationLocationTracking();

    // Initialize with current position
    if (_currentLocation != null) {
      _lastKnownLocation = LatLng(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );
      _updateNavigationCamera();
    }
  }

  void _completeNavigationReset() {
    // First, cancel any active navigation subscriptions or timers
    _navigationLocationSubscription?.cancel();
    _locationSimulationTimer?.cancel();

    // Restore normal location tracking settings
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000, // 10 seconds
      distanceFilter: 10, // 10 meters
    );

    // Update navigation state to idle (using our centralized method)
    _updateNavigationState(NavigationState.idle);

    setState(() {
      // Clear all navigation-related state
      _routeDetails = null;
      _routeAlternatives = [];
      _selectedRouteIndex = 0;
      _destinationPlace = null;
      _polylinesMap.clear();
      _currentStepIndex = 0;
      _lastKnownLocation = null;

      // Reset map view parameters
      _navigationZoom = 17.5;
      _navigationTilt = 45.0;
      _navigationBearing = 0.0;

      // Reset search-related state
      _searchController.clear();
      _placeSuggestions = [];
      _isSearching = false;

      // Clear all markers except current location
      final currentLocationMarkerId = const MarkerId('currentLocation');
      final currentLocationMarker = _markersMap[currentLocationMarkerId];
      _markersMap.clear();
      if (currentLocationMarker != null) {
        _markersMap[currentLocationMarkerId] = currentLocationMarker;
      }

      // Reset panel states
      _isRoutePanelExpanded = false;
      _isFullyExpanded = false;
      _panelPosition = 0.0;
    });

    // Reset map camera to current location
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentLocation!.latitude!,
              _currentLocation!.longitude!,
            ),
            zoom: 15,
            tilt: 0, // Reset tilt
            bearing: 0, // Reset bearing
          ),
        ),
      );
    }

    // Ensure the panel is in the proper initial state
    // First close the route panel if it's open
    if (_routePanelController.isAttached && _routePanelController.isPanelOpen) {
      _routePanelController.close();
    }

    // Then handle the main panel - make sure it's visible but minimized
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _panelController != null) {
        try {
          // First show the panel if it's hidden
          if (!_panelController.isPanelShown) {
            _panelController.open();
          }

          // Then set it to the exact minimized position
          _panelController.animatePanelToPosition(
            0.0, // Exact minimized position - adjust if needed
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (e) {
          print("Error handling search panel: $e");
        }
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _panelController.open();
            _panelController.animatePanelToPosition(
              0, // Minimized position
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // Ensure the keyboard is hidden
    _ensureKeyboardHidden(context);

    // Reset map style if needed
    if (_mapController != null) {
      _mapController!.setMapStyle(_currentMapStyle);
    }
  }

  // Setup more frequent location updates for navigation
  void _startNavigationLocationTracking() {
    // Cancel existing subscription if any
    _locationSubscription?.cancel();
    _navigationLocationSubscription?.cancel();

    // Configure high accuracy, frequent updates for navigation
    _location.changeSettings(
      accuracy: LocationAccuracy.navigation, // Highest accuracy
      interval: 1000, // Updates every second
      distanceFilter: 5, // Or when moved 5 meters
    );

    // Subscribe to location updates
    _navigationLocationSubscription = _location.onLocationChanged.listen(_handleNavigationLocationUpdate);
  }

  // Handle location updates during navigation
  void _handleNavigationLocationUpdate(LocationData locationData) {
    if (!_isInNavigationMode || !mounted) return;

    final newLocation = LatLng(
      locationData.latitude!,
      locationData.longitude!,
    );

    // Only update if we have a valid bearing
    double bearing = locationData.heading ?? _navigationBearing;

    setState(() {
      _lastKnownLocation = newLocation;
      _navigationBearing = bearing;

      // Update current location marker
      final markerId = const MarkerId('currentLocation');
      final marker = Marker(
        markerId: markerId,
        position: newLocation,
        // Use a custom marker that shows direction
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        // You could also use a custom asset for a directional arrow:
        // icon: await BitmapDescriptor.fromAssetImage(
        //   ImageConfiguration(size: Size(48, 48)),
        //   'assets/navigation_arrow.png',
        // ),
        rotation: bearing, // Rotate marker to show direction
        flat: true, // Keep marker flat on the map
        anchor: const Offset(0.5, 0.5), // Center the marker
      );
      _markersMap[markerId] = marker;
    });

    // Update the camera to follow the user
    _updateNavigationCamera();

    // Check if we've reached the next instruction point
    _checkRouteProgress(newLocation);
  }

  // Update the camera to follow the user in navigation mode
  void _updateNavigationCamera() {
    if (_mapController == null || _lastKnownLocation == null) return;

    // Adjust zoom level based on speed (if available)
    if (_currentLocation != null && _currentLocation!.speed != null) {
      // Higher speed = zoom out more to see ahead
      final speed = _currentLocation!.speed! * 3.6; // Convert m/s to km/h

      if (speed > 80) {
        _navigationZoom = 15.0; // Highway speeds
      } else if (speed > 40) {
        _navigationZoom = 16.0; // Moderate speeds
      } else {
        _navigationZoom = 17.5; // Slow/city speeds
      }
    }

    // Also adjust zoom based on distance to next maneuver
    if (_routeDetails != null &&
        _currentStepIndex < _routeDetails!.routes[0].legs[0].steps.length) {
      final currentStep = _routeDetails!.routes[0].legs[0].steps[_currentStepIndex];
      final distanceToNextTurn = _calculateDistance2(
          _lastKnownLocation!,
          currentStep.endLocation
      );

      // If approaching a turn, zoom in more
      if (distanceToNextTurn < 100) {
        _navigationZoom = 18.0; // Very close to turn
      } else if (distanceToNextTurn < 300) {
        _navigationZoom = 17.0; // Approaching turn
      }
    }

    final CameraPosition cameraPosition = CameraPosition(
      target: _lastKnownLocation!,
      zoom: _navigationZoom,
      tilt: _navigationTilt,
      bearing: _navigationBearing,
    );

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(cameraPosition),
    );
  }

  // Check progress along the route and update current step if needed
  void _checkRouteProgress(LatLng currentLocation) {
    if (_routeDetails == null ||
        _routeDetails!.routes.isEmpty ||
        _routeDetails!.routes[0].legs.isEmpty) {
      return;
    }

    final route = _routeDetails!.routes[0];
    final leg = route.legs[0];

    if (leg.steps.isEmpty || _currentStepIndex >= leg.steps.length) {
      return;
    }

    // Get current and next step
    final currentStep = leg.steps[_currentStepIndex];

    // Calculate distance to the end of current step
    final distanceToStepEnd = _calculateDistance2(
        currentLocation,
        currentStep.endLocation
    );

    // If we're close to the end of the current step, move to the next one
    // Use a threshold based on GPS accuracy - typically 20-50 meters
    if (distanceToStepEnd < 30) { // 30 meters threshold
      if (_currentStepIndex < leg.steps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });
      } else {
        // We've reached the last step, check if we're close to destination
        final distToDestination = _calculateDistance2(
            currentLocation,
            leg.endLocation
        );

        if (distToDestination < 30) {
          _handleArrival();
        }
      }
    }
  }

  void _logNavigationEvent(String event, [dynamic data]) {
    print("NAVIGATION: $event ${data != null ? '- $data' : ''}");
  }

  // Calculate straight-line distance between two points (in meters)
  double _calculateDistance2(LatLng point1, LatLng point2) {
    // Haversine formula for calculating distance between two coordinates
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

  // Handle arrival at destination
  void _handleArrival() {
    if (!mounted) return;

    setState(() {
      _isInNavigationMode = false;
    });

    // Stop navigation-specific location tracking
    _navigationLocationSubscription?.cancel();
    _navigationLocationSubscription = null;

    // Restore normal location tracking settings
    _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 10000, // 10 seconds
      distanceFilter: 10, // 10 meters
    );

    // Show arrival dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('You\'ve Arrived'),
        content: Text('You\'ve reached ${_destinationPlace?.name ?? 'your destination'}.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeNavigationReset();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  Widget _buildMapView() {
    return Stack(
      children: [
        // Map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _defaultLocation,
            zoom: 15,
          ),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _updateCurrentLocationMarker();
          },
          markers: _markers,
          polylines: _polylines,
          mapType: _currentMapType,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
        ),

        // Top menu buttons only in idle state
        if (_navigationState == NavigationState.idle)
          _buildTopMenuButtons(),

        // Back and close buttons only in placeSelected state and not during route preview
        if (_navigationState == NavigationState.placeSelected && !_showingRouteAlternatives)
          _buildNavigationTopButtons(),

        // Add the new buttons for route preview state
        if (_navigationState == NavigationState.routePreview)
          _buildRouteSelectionTopButtons(),

        // Map action buttons (conditional based on navigation state)
        _buildMapActionButtons(),

        // Report button (conditional based on navigation state)
        _buildReportButton(),

        // Selected place card - only in placeSelected state and not during route preview
        if (_navigationState == NavigationState.placeSelected && !_showingRouteAlternatives)
          _buildSelectedPlaceCard(),

        // Conditionally show the route selection panel
        if (_showingRouteAlternatives && _routeAlternatives.isNotEmpty)
          _buildRouteSelectionPanel(),

        // Navigation info panel only when in activeNavigation state
        if (_navigationState == NavigationState.activeNavigation && _routeDetails != null)
          _buildNavigationInfoPanel(),
      ],
    );
  }

  void _showLeaveLaterDialog() {
    // Implementation for departure time selection
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => Container(
        height: 300,
        child: Column(
          children: [
            ListTile(
              title: const Text('Leave now'),
              leading: const Icon(Icons.directions_car),
              onTap: () {
                Navigator.pop(context);
                _startActiveNavigation();
              },
            ),
            ListTile(
              title: const Text('Leave in 30 minutes'),
              leading: const Icon(Icons.access_time),
              onTap: () {
                Navigator.pop(context);
                // You would implement delayed routing here
              },
            ),
            ListTile(
              title: const Text('Leave in 1 hour'),
              leading: const Icon(Icons.access_time),
              onTap: () {
                Navigator.pop(context);
                // You would implement delayed routing here
              },
            ),
            ListTile(
              title: const Text('Choose departure time'),
              leading: const Icon(Icons.calendar_today),
              onTap: () {
                Navigator.pop(context);
                // Show date/time picker
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMenuButtons() {
    return Positioned(
      top: 40,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircularButton(
            icon: Icons.menu,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Hamburgmenu()),
              );
            },
          ),
          _buildCircularButton(
            icon: Icons.my_location,
            onPressed: () {
              if (_currentLocation != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        _currentLocation!.latitude ?? _defaultLocation.latitude,
                        _currentLocation!.longitude ?? _defaultLocation.longitude,
                      ),
                      zoom: 15,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        color: color != null ? Colors.white : null,
        onPressed: onPressed,
      ),
    );
  }

  // Toggle function
  void _toggleTrafficLayer() {
    setState(() {
      _trafficEnabled = !_trafficEnabled;
      _currentMapStyle = _trafficEnabled ? null : navigationMapStyle;

      print("Traffic Enabled: $_trafficEnabled");
      print("Current Map Style: " + (_currentMapStyle == null ? "NULL (Default Google)" : "Custom Style"));
    });
  }

  Widget _buildMapActionButtons() {
    // When in route selection mode (_showingRouteAlternatives is true),
    // we'll display only the recenter button
    if (_showingRouteAlternatives) {
      return Positioned(
        top: 16,
        right: 16,
        child: _buildCircularButton(
          icon: Icons.my_location,
          onPressed: () {
            if (_currentLocation != null) {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(
                      _currentLocation!.latitude ?? _defaultLocation.latitude,
                      _currentLocation!.longitude ?? _defaultLocation.longitude,
                    ),
                    zoom: 15,
                  ),
                ),
              );
            }
          },
        ),
      );
    }

    // For navigation mode, we show the centered recenter button
    if (_isInNavigationMode) {
      return Positioned(
        right: 16,
        bottom: MediaQuery.of(context).size.height / 2 - 28, // Center vertically
        child: FloatingActionButton(
          heroTag: "recenterButton",
          backgroundColor: Colors.white,
          elevation: 4.0,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 24),
          onPressed: () {
            if (_lastKnownLocation != null) {
              _updateNavigationCamera();
            }
          },
        ),
      );
    }

    // For other states, show the original buttons
    return Positioned(
      bottom: 200,
      right: 16,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: "toggleTraffic",
            mini: true,
            backgroundColor: _trafficEnabled ? Colors.blue : Colors.white,
            onPressed: _toggleTrafficLayer,
            child: Icon(
              Icons.traffic,
              color: _trafficEnabled ? Colors.white : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),

          _buildCircularButton(
            icon: _isNavigating ? Icons.close : Icons.navigation,
            color: _isNavigating ? Colors.red : null,
            onPressed: _isNavigating ? _stopNavigation : _startNavigation,
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton() {
    // Skip rendering the report button if we're in route selection mode
    if (_showingRouteAlternatives) {
      return const SizedBox.shrink(); // Return an empty widget
    }

    // For navigation mode, show the report button at bottom left
    if (_isInNavigationMode) {
      return Positioned(
        bottom: 100, // Position at bottom with padding
        left: 16, // Position at left
        child: FloatingActionButton(
          heroTag: "reportButton",
          backgroundColor: Colors.white,
          elevation: 4.0,
          child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
          onPressed: () {
            // Implement Hazard Reporting here
          },
        ),
      );
    }

    // For other states, show the regular report button
    return Positioned(
      bottom: 200,
      left: 16,
      child: _buildCircularButton(
        icon: Icons.warning_amber_rounded,
        onPressed: () {
          // Implement Hazard Reporting here
        },
      ),
    );
  }

  Widget _buildNavigationInfoPanel() {
    if (!_isInNavigationMode || _routeDetails == null) {
      return const SizedBox.shrink();
    }

    final route = _routeDetails!.routes[0];
    final leg = route.legs[0];

    if (leg.steps.isEmpty || _currentStepIndex >= leg.steps.length) {
      return const SizedBox.shrink();
    }

    final currentStep = leg.steps[_currentStepIndex];

    // Calculate distance to next maneuver
    String distanceText = currentStep.distance.text;
    if (_lastKnownLocation != null) {
      final distanceToStepEnd = _calculateDistance2(
          _lastKnownLocation!,
          currentStep.endLocation
      );
      distanceText = _formatDistance(distanceToStepEnd.toInt());
    }

    // Calculate ETA
    final eta = _calculateETA();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main instruction panel
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status bar with ETA and arrival time
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Distance to destination
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            leg.distance.text,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // ETA
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            eta,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main instruction with maneuver icon
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Maneuver icon
                      _buildManeuverIcon(currentStep.instruction),
                      const SizedBox(width: 16),

                      // Instruction text and distance
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _cleanInstruction(currentStep.instruction),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'In $distanceText',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Options button
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          _showNavigationOptions();
                        },
                      ),
                    ],
                  ),
                ),

                // Preview next maneuver if available
                if (_currentStepIndex < leg.steps.length - 1)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Then ${_cleanInstruction(leg.steps[_currentStepIndex + 1].instruction)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to create the appropriate maneuver icon
  Widget _buildManeuverIcon(String instruction) {
    // Determine icon based on instruction text
    IconData iconData = Icons.arrow_forward;
    Color iconColor = Colors.blue;

    final String lowerInstruction = instruction.toLowerCase();

    if (lowerInstruction.contains('turn right')) {
      iconData = Icons.turn_right;
    } else if (lowerInstruction.contains('turn left')) {
      iconData = Icons.turn_left;
    } else if (lowerInstruction.contains('u-turn')) {
      iconData = Icons.u_turn_left; // Or create a custom U-turn icon
    } else if (lowerInstruction.contains('merge') ||
        lowerInstruction.contains('take exit')) {
      iconData = Icons.merge_type;
    } else if (lowerInstruction.contains('destination')) {
      iconData = Icons.place;
      iconColor = Colors.red;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 30,
      ),
    );
  }

  // Helper to clean HTML from instructions
  String _cleanInstruction(String instruction) {
    // Remove HTML tags
    String cleaned = instruction.replaceAll(RegExp(r'<[^>]*>'), '');

    // Simplify common phrases
    cleaned = cleaned
        .replaceAll('Proceed to', 'Go to')
        .replaceAll('Continue onto', 'Continue on');

    return cleaned;
  }

  // Calculate estimated arrival time
  String _calculateETA() {
    if (_routeDetails == null ||
        _routeDetails!.routes.isEmpty ||
        _routeDetails!.routes[0].legs.isEmpty) {
      return 'ETA: --:--';
    }

    final route = _routeDetails!.routes[0];
    final leg = route.legs[0];

    // Get duration in seconds from the leg
    int remainingSeconds = leg.duration.value;

    // If we have steps, calculate more precisely using step durations
    if (leg.steps.isNotEmpty) {
      remainingSeconds = 0;

      // Sum up remaining step durations
      for (int i = _currentStepIndex; i < leg.steps.length; i++) {
        // Ensure we have valid duration values
        if (leg.steps[i].duration.value > 0) {
          remainingSeconds += leg.steps[i].duration.value;
        }
      }

      // If we're in the middle of a step, adjust for progress
      if (_currentStepIndex < leg.steps.length && _lastKnownLocation != null) {
        final currentStep = leg.steps[_currentStepIndex];
        final distanceToStepEnd = _calculateDistance2(
            _lastKnownLocation!,
            currentStep.endLocation
        );
        final totalStepDistance = _calculateDistance2(
            currentStep.startLocation,
            currentStep.endLocation
        );

        if (totalStepDistance > 0) {
          // Calculate how far through the current step we are (0 to 1)
          // Need to invert since distanceToStepEnd measures remaining distance
          double progressRatio = 1.0 - (distanceToStepEnd / totalStepDistance);

          // Ensure progressRatio is within valid range to prevent calculation errors
          progressRatio = progressRatio.clamp(0.0, 1.0);

          // Adjust the current step time based on progress
          final adjustedStepTime = (1.0 - progressRatio) * currentStep.duration.value;

          // Update the remaining seconds by removing the completed portion
          remainingSeconds = remainingSeconds - currentStep.duration.value + adjustedStepTime.toInt();
        }
      }
    }

    // Validate: If remaining time is suspiciously short, use leg duration as fallback
    // This ensures we don't show the current time as ETA
    if (remainingSeconds < 60) {  // Less than a minute remaining seems unlikely
      print('ETA calculation warning: Calculated time too short ($remainingSeconds seconds). Using route duration instead.');
      remainingSeconds = leg.duration.value;
    }

    // Calculate arrival time
    final now = DateTime.now();
    final arrivalTime = now.add(Duration(seconds: remainingSeconds));

    // Format as HH:MM
    final hour = arrivalTime.hour.toString().padLeft(2, '0');
    final minute = arrivalTime.minute.toString().padLeft(2, '0');

    return 'ETA: $hour:$minute';
  }

  // Show a dialog with navigation options
  void _showNavigationOptions() {
    // Ensure keyboard is hidden before showing options
    _ensureKeyboardHidden(context);

    // Set focus to dummy node to prevent text fields from getting focus
    FocusScope.of(context).requestFocus(_dummyFocusNode);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // Options
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Show all steps'),
              onTap: () {
                Navigator.pop(context);
                _showAllSteps();
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Overview map'),
              onTap: () {
                Navigator.pop(context);
                _showRouteOverview();
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle),
              title: const Text('End navigation'),
              onTap: () {
                Navigator.pop(context);
                _showEndNavigationDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show all navigation steps
  void _showAllSteps() {
    if (_routeDetails == null) return;

    // Ensure keyboard is hidden
    _ensureKeyboardHidden(context);

    // Set focus to dummy node
    FocusScope.of(context).requestFocus(_dummyFocusNode);

    final route = _routeDetails!.routes[0];
    final leg = route.legs[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the sheet to be larger
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, // Start at 60% of screen height
        minChildSize: 0.3, // Min 30%
        maxChildSize: 0.9, // Max 90%
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Title with back button
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            Navigator.pop(context);
                            // Ensure keyboard remains hidden when returning
                            _ensureKeyboardHidden(context);
                          },
                        ),
                        const Text(
                          'All Steps',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // List of steps
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: leg.steps.length,
                  itemBuilder: (context, index) {
                    final step = leg.steps[index];
                    final bool isCurrent = index == _currentStepIndex;

                    return Container(
                      color: isCurrent ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      child: ListTile(
                        leading: _buildManeuverIcon(step.instruction),
                        title: Text(
                          _cleanInstruction(step.instruction),
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(step.distance.text),
                        trailing: isCurrent
                            ? const Icon(Icons.navigation, color: Colors.blue)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Show a route overview
  void _showRouteOverview() {
    if (_routeDetails == null || _mapController == null) return;

    // Ensure keyboard is hidden
    _ensureKeyboardHidden(context);

    // Set focus to dummy node
    FocusScope.of(context).requestFocus(_dummyFocusNode);

    // Save current camera position to restore later
    _mapController!.getVisibleRegion().then((region) {
      // Temporarily disable follow mode
      setState(() {
        _isInNavigationMode = false;
      });

      // Zoom out to show the entire route
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          _routeDetails!.routes[0].bounds,
          50,
        ),
      );

      // Show a floating button to return to navigation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          content: const Text('Overview mode'),
          action: SnackBarAction(
            label: 'Return to Navigation',
            onPressed: () {
              // Resume navigation mode
              setState(() {
                _isInNavigationMode = true;
              });

              // Return to following the user
              if (_lastKnownLocation != null) {
                _updateNavigationCamera();
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      // Automatically return to navigation after a delay
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && !_isInNavigationMode) {
          setState(() {
            _isInNavigationMode = true;
          });

          if (_lastKnownLocation != null) {
            _updateNavigationCamera();
          }
        }
      });
    });
  }

  // 2. Map styles for navigation mode

// Function to set a night mode map style for better visibility at night
  void _setNightModeMapStyle() {
    if (_mapController == null) return;

    // This is a simplified example - you would typically load this from a JSON file
    const String nightMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#242f3e"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#746855"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#38414e"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#212a37"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#9ca5b3"
        }
      ]
    }
  ]
  ''';

    _mapController!.setMapStyle(nightMapStyle);
  }

  // Function to set a simplified map style for navigation
  void _setNavigationMapStyle() {
    if (_mapController == null) return;

    // This is a simplified example - you would typically load this from a JSON file
    const String navigationMapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "weight": 3
        }
      ]
    }
  ]
  ''';

    _mapController!.setMapStyle(navigationMapStyle);
  }



  // Helper method to format distances from meters
  String _formatDistance(int meters) {
    if (meters < 1000) {
      return '$meters m';
    } else {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  // Show a confirmation dialog before ending navigation
  void _showEndNavigationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Navigation'),
        content: const Text('Are you sure you want to end navigation?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeNavigationReset();
            },
            child: const Text('End'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          _buildDragHandle(),

          // Search bar
          _buildSearchBar(),

          // Content area - changes based on search state
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildDefaultContent()
                : _buildSearchResults(),
          )
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
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
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                onEditingComplete: () {
                  // Handle search completion and explicitly hide keyboard
                  _ensureKeyboardHidden(context);
                },
                decoration: InputDecoration(
                  hintText: 'Where to?',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                ),
                onChanged: _onSearchChanged,
                onTap: () {
                  _panelController.open();
                },
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
    );
  }

  Widget _buildDefaultContent() {
    return Column(
      children: [
        // Quick access buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickAccessButton(Icons.home, 'Home'),
              _buildQuickAccessButton(Icons.work, 'Work'),
              _buildQuickAccessButton(Icons.add, 'New'),
            ],
          ),
        ),

        // Recent locations
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Recent',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildRecentLocationItem('TechShack', '158 St H Abellana, Mandaue City, Central ...'),
              _buildRecentLocationItem('Cebu IT Park', 'Cebu City, Central Visayas'),
              _buildRecentLocationItem('Sugbo Mercado - IT Park', 'Inez Villa, Cebu City'),
            ],
          ),
        ),
      ],
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
      return _buildDefaultContent();
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
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _onSearchChanged(_searchController.text);
              },
              child: const Text('Try Again'),
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

  String _calculateDistance(api.PlaceSuggestion suggestion) {
    // Return cached distance if available
    if (_suggestionDistances.containsKey(suggestion.placeId)) {
      return _suggestionDistances[suggestion.placeId]!;
    }

    // Start a background calculation for this suggestion if we have location
    if (_currentLocation != null) {
      _calculateDistanceAsync(suggestion);
    }

    // Return a placeholder while calculating
    return "-";
  }

  Future<void> _calculateDistanceAsync(api.PlaceSuggestion suggestion) async {
    try {
      // Get place details to access its coordinates
      final place = await api.GoogleApiServices.getPlaceDetails(suggestion.placeId);

      if (place != null && _currentLocation != null && mounted) {
        // Calculate distance using the Haversine formula
        final distanceInMeters = _calculateDistance2(
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
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
        setState(() {
          _suggestionDistances[suggestion.placeId] = formattedDistance;
        });
      }
    } catch (e) {
      print('Error calculating distance for ${suggestion.placeId}: $e');
    }
  }

  void _updateAllSuggestionDistances() {
    if (_placeSuggestions.isEmpty || _currentLocation == null) return;

    for (var suggestion in _placeSuggestions) {
      if (!_suggestionDistances.containsKey(suggestion.placeId)) {
        _calculateDistanceAsync(suggestion);
      }
    }
  }

  Widget _buildQuickAccessButton(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildRecentLocationItem(String title, String subtitle) {
    return ListTile(
      leading: const Icon(Icons.location_on_outlined),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      contentPadding: EdgeInsets.zero,
      onTap: () {
        _panelController.close();
      },
    );
  }
}