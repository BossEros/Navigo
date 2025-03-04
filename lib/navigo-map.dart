import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'services/google-api-services.dart' hide Duration;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
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

class _NavigoMapScreenState extends State<NavigoMapScreen> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;
  final Location _location = Location();
  final PanelController _panelController = PanelController();
  final TextEditingController _searchController = TextEditingController();

  // Default location (can be set to a default location like Cebu)
  final LatLng _defaultLocation = const LatLng(10.3157, 123.8854); // Cebu coordinates

  // Map UI configurations
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  MapType _currentMapType = MapType.normal;

  // Search results
  List<PlaceSuggestion> _placeSuggestions = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Selected location and navigation
  Place? _destinationPlace;
  bool _isNavigating = false;
  RouteDetails? _routeDetails;

  @override
  void initState() {
    super.initState();
    _initLocationService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Initialize location services and request permissions
  Future<void> _initLocationService() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Check if location services are enabled
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    // Check location permissions
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    // Get current location
    _location.onLocationChanged.listen((LocationData locationData) {
      setState(() {
        _currentLocation = locationData;
        _updateCurrentLocationMarker();
      });
    });
  }

  // Update marker for current location
  void _updateCurrentLocationMarker() {
    if (_currentLocation != null) {
      final LatLng position = LatLng(
        _currentLocation!.latitude ?? _defaultLocation.latitude,
        _currentLocation!.longitude ?? _defaultLocation.longitude,
      );

      setState(() {
        // Update or add current location marker
        _markers.removeWhere((marker) => marker.markerId.value == 'currentLocation');
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: position,
            infoWindow: const InfoWindow(title: 'Current Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );

        // Move camera to current location if not navigating
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

  // Search for places as user types
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length >= 2) {
        setState(() {
          _isSearching = true;
        });

        try {
          final suggestions = await GoogleApiServices.getPlaceSuggestions(query);
          setState(() {
            _placeSuggestions = suggestions;
            _isSearching = false;
          });
        } catch (e) {
          print('Error getting place suggestions: $e');
          setState(() {
            _isSearching = false;
          });
        }
      } else {
        setState(() {
          _placeSuggestions = [];
        });
      }
    });
  }

  // Select a place from search results
  Future<void> _selectPlace(PlaceSuggestion suggestion) async {
    final place = await GoogleApiServices.getPlaceDetails(suggestion.placeId);
    if (place != null) {
      setState(() {
        _destinationPlace = place;
        _searchController.text = place.name;
        _placeSuggestions = [];

        // Add marker for the destination
        _markers.removeWhere((marker) => marker.markerId.value == 'destination');
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: place.latLng,
            infoWindow: InfoWindow(title: place.name),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      });

      // Move camera to show both markers
      _fitBounds([
        LatLng(
          _currentLocation?.latitude ?? _defaultLocation.latitude,
          _currentLocation?.longitude ?? _defaultLocation.longitude,
        ),
        place.latLng,
      ]);

      _panelController.close();
    }
  }

  // Start navigation to selected destination
  Future<void> _startNavigation() async {
    if (_destinationPlace != null && _currentLocation != null) {
      setState(() {
        _isNavigating = true;
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

        if (routeDetails != null && routeDetails.routes.isNotEmpty) {
          setState(() {
            _routeDetails = routeDetails;
            _polylines.clear();

            // Add polyline for the route
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: routeDetails.routes[0].polylinePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });

          // Fit map to show the entire route
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(routeDetails.routes[0].bounds, 50),
          );
        }
      } catch (e) {
        print('Error getting directions: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get directions. Please try again.')),
        );
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  // Stop navigation
  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _routeDetails = null;
      _polylines.clear();
      _markers.removeWhere((marker) => marker.markerId.value == 'destination');
      _destinationPlace = null;
      _searchController.clear();
    });

    // Return to current location
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
  }

  // Fit map bounds to show all points
  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50, // padding
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SlidingUpPanel(
        controller: _panelController,
        minHeight: 80,
        maxHeight: MediaQuery.of(context).size.height * 0.8,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        panel: _buildSearchPanel(),
        body: Stack(
          children: [
            // Google Map
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

            // Top menu button and search bar
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        // Menu action
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _panelController.open();
                      },
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _destinationPlace?.name ?? 'Search here!',
                                style: TextStyle(
                                  color: _destinationPlace != null ? Colors.black : Colors.grey,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      icon: const Icon(Icons.my_location),
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
                  ),
                ],
              ),
            ),

            // Bottom buttons
            Positioned(
              bottom: 100,
              right: 16,
              child: Column(
                children: [
                  // Navigation button - Updated to toggle navigation
                  Container(
                    decoration: BoxDecoration(
                      color: _isNavigating ? Colors.red : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(_isNavigating ? Icons.close : Icons.navigation),
                      color: _isNavigating ? Colors.white : Colors.blue,
                      onPressed: () {
                        if (_isNavigating) {
                          _stopNavigation();
                        } else if (_destinationPlace != null) {
                          _startNavigation();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a destination first')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.warning_amber_rounded),
                      color: Colors.amber,
                      onPressed: () {
                        // Hazard reporting
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Info Panel
            if (_isNavigating && _routeDetails != null)
              Positioned(
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
                          Text(_routeDetails!.routes[0].legs[0].duration.text),
                          const SizedBox(width: 16),
                          const Icon(Icons.straighten, size: 16),
                          const SizedBox(width: 4),
                          Text(_routeDetails!.routes[0].legs[0].distance.text),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle indicator
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),

        // Search bar - Updated to use real search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                IconButton(
                  icon: _isSearching
                      ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.mic, color: Colors.grey),
                  onPressed: () {
                    // Voice search - will be implemented later
                  },
                ),
              ],
            ),
          ),
        ),

        // Search results
        if (_placeSuggestions.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _placeSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _placeSuggestions[index];
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(suggestion.mainText),
                  subtitle: Text(suggestion.secondaryText),
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _selectPlace(suggestion),
                );
              },
            ),
          )
        else ...[
          // Quick access buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAccessButton(Icons.bookmark, Colors.amber, 'Saved'),
                _buildQuickAccessButton(Icons.home, Colors.brown, 'Home'),
                _buildQuickAccessButton(Icons.work, Colors.blue, 'Work'),
                _buildQuickAccessButton(Icons.school, Colors.red, 'School'),
              ],
            ),
          ),

          // Recent locations
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recent locations
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Locations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRecentLocationItem(
                          Icons.home,
                          Colors.brown,
                          'Home',
                          'Cebu N Rd, Consolacion, Cebu',
                        ),
                        const Divider(),
                        _buildRecentLocationItem(
                          Icons.school,
                          Colors.red,
                          'UCLM',
                          'School',
                        ),
                      ],
                    ),
                  ),

                  // Recent searches
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRecentSearchItem(
                          'Pacific Mall Mandaue',
                          'Shopping Mall',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickAccessButton(IconData icon, Color color, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecentLocationItem(IconData icon, Color color, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
      onTap: () {
        // This will be replaced with actual geocoding
        _panelController.close();
      },
    );
  }

  Widget _buildRecentSearchItem(String title, String subtitle) {
    return ListTile(
      leading: const Icon(Icons.location_on_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      contentPadding: EdgeInsets.zero,
      onTap: () {
        // This will be replaced with actual search
        _panelController.close();
      },
    );
  }
}