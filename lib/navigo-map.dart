import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:async';
import 'dart:math' as math;
import 'services/google-api-services.dart' hide Duration;
import 'package:project_navigo/hamburger-menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
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

  // Search state
  List<PlaceSuggestion> _placeSuggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Panel state
  double _panelPosition = 0.0;
  bool _isFullyExpanded = false;

  // Navigation state
  Place? _destinationPlace;
  bool _isNavigating = false;
  RouteDetails? _routeDetails;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _initLocationService();

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
    super.dispose();
  }

  Widget _buildSelectedPlaceCard() {
    if (_destinationPlace == null || _isNavigating) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.white,
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
                  Text(
                    _destinationPlace!.address,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  onPressed: () {
                    // Save location functionality
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

            // Photos section
            Container(
              height: 120,
              padding: const EdgeInsets.only(left: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildPhotoItem(),
                  _buildPhotoItem(),
                  _buildAddPhotoItem(),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
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

  Widget _buildPhotoItem() {
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: const DecorationImage(
          image: NetworkImage('https://via.placeholder.com/120'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildNavigationTopButtons() {
    if (_destinationPlace == null || _isNavigating) return const SizedBox.shrink();

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
              // Use delayed setState for a smoother transition
              Future.delayed(const Duration(milliseconds: 300), () {
                setState(() {
                  _destinationPlace = null;
                  _markersMap.remove(const MarkerId('destination'));
                });

                // Wait a tiny bit more before showing the panel
                Future.delayed(const Duration(milliseconds: 100), () {
                  _panelController.open();
                  _searchController.clear(); // Clear search text
                });
              });
            },
          ),

          _buildCircularButton(
            icon: Icons.close,
            onPressed: () {
              Future.delayed(const Duration(milliseconds: 300), () {
                setState(() {
                  _destinationPlace = null;
                  _markersMap.remove(const MarkerId('destination'));
                });

                Future.delayed(const Duration(milliseconds: 100), () {
                  _panelController.close();
                  _searchController.clear(); // Clear search text
                });
              });
            },
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
          final suggestions = await GoogleApiServices.getPlaceSuggestions(query);

          // Only update state if the component is still mounted and the search text hasn't changed
          if (mounted && _searchController.text == query) {
            setState(() {
              _placeSuggestions = suggestions;
              _isSearching = false;
            });

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

  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    try {
      // Close keyboard
      FocusScope.of(context).unfocus();

      // Close the sliding panel
      _panelController.close();

      setState(() {
        _isSearching = true;
      });

      print('Getting details for place: ${suggestion.placeId}');
      final place = await GoogleApiServices.getPlaceDetails(suggestion.placeId);

      if (place != null && mounted) {
        setState(() {
          _destinationPlace = place;
          _searchController.text = place.name;
          _placeSuggestions = [];
          _isSearching = false;
        });

        _addDestinationMarker(place);

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

  void _addDestinationMarker(Place place) {
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

  void _fitBoundsToDestination(Place place) {
    final currentLocation = _currentLocation != null
        ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
        : _defaultLocation;

    // This provides a tighter zoom when places are close
    _fitBounds([currentLocation, place.latLng], padding: 100);
  }


  Future<void> _startNavigation() async {
    if (_destinationPlace == null || _currentLocation == null) {
      _showErrorSnackBar('Please select a destination first');
      return;
    }

    setState(() {
      _isNavigating = true;
      // Close the panel if it's open
      if (_panelController.isPanelOpen) {
        _panelController.close();
      }
    });

    try {
      final origin = LatLng(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );

      final routeDetails = await GoogleApiServices.getDirections(
        origin,
        _destinationPlace!.latLng,
      );

      if (routeDetails != null && routeDetails.routes.isNotEmpty && mounted) {
        setState(() {
          _routeDetails = routeDetails;
          _polylinesMap.clear();

          final polylineId = const PolylineId('route');
          final polyline = Polyline(
            polylineId: polylineId,
            points: routeDetails.routes[0].polylinePoints,
            color: Colors.blue,
            width: 5,
          );

          _polylinesMap[polylineId] = polyline;
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(routeDetails.routes[0].bounds, 50),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to get directions. Please try again.');
      setState(() {
        _isNavigating = false;
      });
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _routeDetails = null;
      _polylinesMap.clear();
      _markersMap.remove(const MarkerId('destination'));
      _destinationPlace = null;
      _searchController.clear();
    });

    if (_currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentLocation!.latitude!,
              _currentLocation!.longitude!,
            ),
            zoom: 15,
          ),
        ),
      );
    }

    // Add this to ensure panel shows up after navigation stops
    Future.delayed(const Duration(milliseconds: 300), () {
      _panelController.open();
    });
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
        child: SlidingUpPanel(
          controller: _panelController,
          minHeight: _destinationPlace != null ? 0 : 100, // Hide panel when destination is selected
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

        // Top menu buttons when no destination is selected
        if (_destinationPlace == null)
          _buildTopMenuButtons(),

        // Back and close buttons when a destination is selected
        if (_destinationPlace != null && !_isNavigating)
          _buildNavigationTopButtons(),

        // Map action buttons
        _buildMapActionButtons(),

        // Selected place card
        if (_destinationPlace != null && !_isNavigating)
          _buildSelectedPlaceCard(),

        // Navigation info panel (conditionally shown)
        if (_isNavigating && _routeDetails != null)
          _buildNavigationInfoPanel(),
      ],
    );  }



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

  Widget _buildMapActionButtons() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: Column(
        children: [
          _buildCircularButton(
            icon: _isNavigating ? Icons.close : Icons.navigation,
            color: _isNavigating ? Colors.red : null,
            onPressed: _isNavigating ? _stopNavigation : _startNavigation,
          ),
          const SizedBox(height: 8),
          _buildCircularButton(
            icon: Icons.warning_amber_rounded,
            onPressed: () {
              // Hazard reporting
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfoPanel() {
    final route = _routeDetails!.routes[0];
    final leg = route.legs[0];

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _destinationPlace?.name ?? 'Destination',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(leg.duration.text),
                const SizedBox(width: 16),
                const Icon(Icons.straighten, size: 16),
                const SizedBox(width: 4),
                Text(leg.distance.text),
              ],
            ),
          ],
        ),
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
            "${_calculateDistance(suggestion)} km",
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

  String _calculateDistance(PlaceSuggestion suggestion) {
    // This is a placeholder - you'll need to implement actual distance calculation
    // based on the suggestion's location and current location
    return "2.9"; // Example value
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