library navigo_map;

import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:project_navigo/models/recent_location.dart';
import 'package:project_navigo/services/recent_locations_service.dart';
import 'dart:async';
import '../../component/reusable-location-search_screen.dart';
import '../../config/config.dart';
import '../../models/map_models/map_ids.dart';
import '../../models/map_models/map_styles.dart';
import '../../models/map_models/report_type.dart';
import '../../models/route_history.dart';
import '../../models/user_profile.dart';
import '../../services/google-api-services.dart' as api;
import 'package:project_navigo/screens/hamburger-menu/hamburger-menu.dart';
import '../../services/route_history_service.dart';
import 'package:project_navigo/services/saved-map_services.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/services/app_constants.dart';
import '../../services/user_provider.dart';
import '../../themes/app_theme.dart';
import '../../themes/app_typography.dart';
import '../../themes/theme_provider.dart';
import '../../widgets/report_panel.dart';
import '../hamburger-menu/all_shortcuts_screen.dart';
import '../authentication/login_screen.dart';
import 'package:project_navigo/services/quick_access_shortcut_service.dart';
import 'dart:ui' show Canvas, Paint, Path, PictureRecorder, ImageByteFormat;
import 'dart:typed_data' show ByteData, Uint8List;

import 'package:project_navigo/models/map_models/navigation_state.dart';
import 'package:project_navigo/models/map_models/quick_access_shortcut.dart';
import 'package:project_navigo/utils/map_utilities/location_utils.dart';
import 'package:project_navigo/utils/map_utilities/camera_utils.dart';
import 'package:project_navigo/utils/map_utilities/format_utils.dart';
import 'package:project_navigo/utils/map_utilities/map_utils.dart';

import '../hamburger-menu/profile.dart';

part 'navigo_map_shortcuts.dart';
part 'navigo_map_navigation.dart';
part 'navigo_map_search.dart';
part 'navigo_map_ui_builder.dart';
part 'navigo_map_reporting.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String? savedPlaceId;
  final LatLng? savedCoordinates;
  final String? savedName;
  final bool startNavigation;

  const MyApp({
    Key? key,
    this.savedPlaceId,
    this.savedCoordinates,
    this.savedName,
    this.startNavigation = false,
  }) : super(key: key);

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
      home: NavigoMapScreen(
        savedPlaceId: savedPlaceId,
        savedCoordinates: savedCoordinates,
        savedName: savedName,
        startNavigation: startNavigation,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NavigoMapScreen extends StatefulWidget {
  final String? savedPlaceId;
  final LatLng? savedCoordinates;
  final String? savedName;
  final bool startNavigation;

  const NavigoMapScreen({
    Key? key,
    this.savedPlaceId,
    this.savedCoordinates,
    this.savedName,
    this.startNavigation = false,
  }) : super(key: key);

  @override
  State<NavigoMapScreen> createState() => _NavigoMapScreenState();
}

// A state variable to control traffic visibility
bool _trafficEnabled = false;
String? _currentMapStyle;

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

  // Add this for recent locations
  final RecentLocationsService _recentLocationsService = RecentLocationsService();
  List<RecentLocation> _recentLocations = [];
  bool _isLoadingRecentLocations = false;

  // Panel state
  double _panelPosition = 0.0;
  bool _isFullyExpanded = false;

  // Navigation state
  api.Place? _destinationPlace;
  bool _isNavigating = false;
  api.RouteDetails? _routeDetails;
  bool _isNavigationInProgress = false;
  DateTime _navigationStartTime = DateTime.now();

  bool _showingRouteAlternatives = false;
  int _selectedRouteIndex = 0;
  List<api.RouteDetails> _routeAlternatives = [];

  final PanelController _routePanelController = PanelController();
  bool _isRoutePanelExpanded = false;

  bool _isLocationSaved = false;
  bool _isLoadingLocationSave = false;
  SavedMapService? _savedMapService;
  Map<String, bool> _savedLocationCache = {};

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

  List<QuickAccessShortcut> _quickAccessShortcuts = [];
  final ScrollController _shortcutsScrollController = ScrollController();

  // For quick access button
  QuickAccessShortcutService? _shortcutService;
  bool _isLoadingShortcuts = false;

  // Navigation Icon
  BitmapDescriptor? _navigationArrowIcon;

  bool _isPlaceCardExpanded = false;
  DraggableScrollableController _placeCardScrollController = DraggableScrollableController();
  final double _placeCardMinHeight = 400 / 800; // Adjust denominator based on average screen height

  ///--------------------------------Lifecycle and Initialization--------------------------------------------------------///

  @override
  @override
  void initState() {
    super.initState();

    _initLocationService();
    _trafficEnabled = false;
    _placeCardScrollController = DraggableScrollableController();

    _preloadNavigationIcon();

    // Add this part to listen for theme changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set initial status bar style
      _updateStatusBarStyle();

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      themeProvider.addListener(() {
        // Update status bar when theme changes
        _updateStatusBarStyle();

        // Handle theme changes for map
        if (_mapController != null) {
          _updateMapOnThemeChange();
        }
      });
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Add this line to fetch recent locations
    _fetchRecentLocations();

    // Initialize quick access shortcuts
    _initQuickAccessShortcuts();

    // Load user data if user is logged in from a persisted session
    _loadUserDataIfLoggedIn();

    // Get saved map service
    Future.microtask(() {
      _savedMapService = Provider.of<SavedMapService>(context, listen: false);

      // Check if we should display a saved location
      if (widget.savedPlaceId != null && widget.savedCoordinates != null) {
        _showSavedLocationOnMap();
      }
    });
  }

  @override
  void dispose() {
    // Restore system UI to default when leaving the screen
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _placeCardScrollController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _mapController?.dispose();
    _locationSubscription?.cancel();
    _navigationLocationSubscription?.cancel();
    _locationSimulationTimer?.cancel();
    _dummyFocusNode.dispose();
    _shortcutsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataIfLoggedIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get user provider and load data if needed
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.userProfile == null) {
        await userProvider.loadUserData();
      }
    }
  }

  void _initQuickAccessShortcuts() {
    setState(() {
      _isLoadingShortcuts = true;
      // Initialize with empty list
      _quickAccessShortcuts = [];
    });

    // Get the service from the provider on the next frame
    Future.microtask(() async {
      try {
        _shortcutService = Provider.of<QuickAccessShortcutService>(context, listen: false);

        // Check if user is logged in
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted) {
            setState(() {
              _isLoadingShortcuts = false;
            });
          }
          return; // Early return if no user
        }

        // Load shortcuts from Firebase
        final shortcuts = await _shortcutService!.getUserShortcuts();

        // Convert to UI shortcuts
        if (mounted) {
          setState(() {
            _quickAccessShortcuts = shortcuts.map((model) => QuickAccessShortcut(
              id: model.id,
              iconPath: model.iconPath,
              label: model.label,
              location: model.location,
              address: model.address,
              placeId: model.placeId,
            )).toList();
            _isLoadingShortcuts = false;
          });
        }
      } catch (e) {
        print('Error loading quick access shortcuts: $e');
        if (mounted) {
          setState(() {
            _isLoadingShortcuts = false;
          });
        }
      }
    });
  }

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

  Future<void> _preloadNavigationIcon() async {
    try {
      print('Preloading navigation arrow icon...');
      _navigationArrowIcon = await _createNavigationArrowIcon();
      print('Navigation arrow icon preloaded: ${_navigationArrowIcon != null}');
    } catch (e) {
      print('Error preloading navigation arrow icon: $e');
      // Continue without the icon, it will be loaded when needed
    }
  }


  ///--------------------------------End of Lifecycle and Initialization--------------------------------------------------------///

  final FocusNode _dummyFocusNode = FocusNode();

  // Get markers as a Set from the Map for the GoogleMap widget
  Set<Marker> get _markers => Set.of(_markersMap.values);

  // Get polylines as a Set from the Map for the GoogleMap widget
  Set<Polyline> get _polylines => Set.of(_polylinesMap.values);

  ///--------------------------------------------Map and Location Management---------------------------------------------///

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
          // When centering on current location, we don't need the vertical offset
          // since we don't show the details card for the current location
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

  void _centerCameraOnLocation({
    required LatLng location,
    double zoom = 16.0,
    double tilt = 30.0,
  }) {
    if (_mapController == null) return;

    // Calculate vertical offset for UI elements
    final screenHeight = MediaQuery.of(context).size.height;
    final detailsCardHeight = screenHeight * 0.35; // Approximate height of details card

    final LatLng offsetTarget = CameraUtils.calculateOffsetTarget(
        location,
        detailsCardHeight / 2,
        zoom
    );

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: offsetTarget,
          zoom: zoom,
          tilt: tilt,
        ),
      ),
    );
  }

  String _getCurrentMapId() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // For dark mode, we'll use JSON styling instead
    if (isDarkMode) {
      return MapIds.defaultMapId; // This will be overridden by JSON styling
    } else if (_isInNavigationMode) {
      return MapIds.navigationMapId;
    } else if (!_trafficEnabled) {
      return MapIds.trafficOffMapId;
    } else {
      return MapIds.defaultMapId;
    }
  }

  void _toggleTrafficLayer() {
    // Get the provider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    // Update the provider state
    themeProvider.setTrafficEnabled(!themeProvider.isTrafficEnabled);

    // Update local state
    setState(() {
      _trafficEnabled = themeProvider.isTrafficEnabled;
      // The rebuild will now use the updated cloudMapId based on the traffic state
    });

    // Note: No need to manually call setMapStyle anymore - it's handled by cloudMapId
    print("Traffic toggled: $_trafficEnabled. Using Cloud Map ID: ${_getCurrentMapId()}");
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

  void _clearRouteInfoMarkers() {
    // Remove any markers with IDs starting with 'route_duration_'
    _markersMap.removeWhere((markerId, marker) =>
        markerId.value.startsWith('route_duration_'));
  }

  void _updateStatusBarStyle() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent to allow our custom background to show
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
    ));
  }


  ///--------------------------------------------End of Map and Location Management---------------------------------------------///


  ///----------------------------------------------------UI Building Methods-----------------------------------------------///

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    _trafficEnabled = themeProvider.isTrafficEnabled;

    // Get status bar height
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      // ONLY change to prevent the UI from moving up when keyboard appears
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // First level: SafeArea with map and panels (original structure)
          SafeArea(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _defaultLocation,
                    zoom: 15,
                  ),
                  onMapCreated: _onMapCreated,
                  markers: _markers,
                  polylines: _polylines,
                  mapType: _currentMapType,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  trafficEnabled: _trafficEnabled,
                  // Allow all gestures even during navigation mode
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                ),

                // SlidingUpPanel with original structure (unchanged)
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
                  color: isDarkMode ? AppTheme.darkTheme.cardTheme.color! : Colors.white,
                  panel: _buildSearchPanel(),
                  body: _buildUIOverlays(),
                ),

                // Other UI components (unchanged)
                if (_showingRouteAlternatives && _routeAlternatives.isNotEmpty)
                  _buildRouteSelectionPanel(),

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

          // Second level: Status bar overlay
          // This sits above the map but below other UI elements to provide the status bar background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: statusBarHeight,
            child: Container(
              color: isDarkMode ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateCurrentLocationMarker();
    print("Map Created with Cloud Map ID: ${_getCurrentMapId()}");

    // Add the dark mode style application here if needed
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.isDarkMode) {
      _applyDarkMapStyle();
    }
  }

  // Helper method to display rating stars
  Widget _buildRatingStars(double? rating, {double size = 16}) {
    if (rating == null) return SizedBox.shrink();

    const int maxStars = 5;
    final int fullStars = rating.floor();
    final bool hasHalfStar = rating - fullStars >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStars, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, color: Colors.amber, size: size);
        } else if (index == fullStars && hasHalfStar) {
          return Icon(Icons.star_half, color: Colors.amber, size: size);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: size);
        }
      }),
    );
  }

// Helper method for price level display
  Widget _buildPriceLevel(int? priceLevel, bool isDarkMode) {
    if (priceLevel == null) return SizedBox.shrink();

    final int level = priceLevel.clamp(0, 4);
    String dollars = '';
    for (int i = 0; i <= level; i++) {
      dollars += '\$';
    }

    return Text(
      dollars,
      style: TextStyle(
        color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }


// URL launching helper
  void _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        print('Could not launch $url');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

// Format website URL for display
  String _formatWebsiteUri(String? url) {
    if (url == null || url.isEmpty) return '';

    try {
      Uri uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }

// Helper for opening hours display
  Widget _buildOpeningHours(Map<String, dynamic>? openingHours, bool isDarkMode) {
    if (openingHours == null) return const SizedBox.shrink();

    // Get open now status
    final bool openNow = openingHours['openNow'] ?? false;

    // Check if we have weekday descriptions directly
    final List<dynamic>? weekdayText = openingHours['weekdayDescriptions'];

    // If no weekday descriptions, we need to format from periods
    List<String> formattedHours = [];
    if (weekdayText == null || weekdayText.isEmpty) {
      // Format from periods if available
      if (openingHours.containsKey('periods') && openingHours['periods'] is List) {
        final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

        // Initialize with "Closed" for all days
        Map<int, String> dayHours = {
          0: 'Sunday: Closed',
          1: 'Monday: Closed',
          2: 'Tuesday: Closed',
          3: 'Wednesday: Closed',
          4: 'Thursday: Closed',
          5: 'Friday: Closed',
          6: 'Saturday: Closed',
        };

        // Fill in actual hours from periods
        for (var period in openingHours['periods']) {
          if (period['open'] != null) {
            final int day = period['open']['day'] ?? 0;
            final int openHour = period['open']['hour'] ?? 0;
            final int openMinute = period['open']['minute'] ?? 0;

            String closeTime = 'Closed';
            if (period['close'] != null) {
              final int closeHour = period['close']['hour'] ?? 0;
              final int closeMinute = period['close']['minute'] ?? 0;
              closeTime = '${_formatHour(closeHour)}:${_formatMinute(closeMinute)}';
            }

            dayHours[day] = '${dayNames[day]}: ${_formatHour(openHour)}:${_formatMinute(openMinute)} - $closeTime';
          }
        }

        // Sort by day and create formatted list
        formattedHours = List.generate(7, (i) => dayHours[i] ?? '${dayNames[i]}: Closed');
      }
    } else {
      // Use existing weekday descriptions
      formattedHours = weekdayText.map((day) => day.toString()).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Open now indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: openNow
                ? Colors.green.withOpacity(isDarkMode ? 0.2 : 0.1)
                : Colors.red.withOpacity(isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: openNow ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Text(
            openNow ? 'Open Now' : 'Closed',
            style: TextStyle(
              color: openNow ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Weekly hours - show all days
        ...formattedHours.map((dayHour) {
          // Try to find today's hours to highlight
          bool isToday = false;

          // Get current day name
          final now = DateTime.now();
          final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
          final todayName = dayNames[now.weekday % 7];

          // Check if this row is for today
          if (dayHour.toString().startsWith(todayName)) {
            isToday = true;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                if (isToday)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    dayHour.toString(),
                    style: TextStyle(
                      color: isToday
                          ? Colors.blue
                          : (isDarkMode ? Colors.grey[300] : Colors.grey[800]),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

// Helper methods for formatting time
  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _formatMinute(int minute) {
    return minute.toString().padLeft(2, '0');
  }

// Display editorial summary (if available)
  Widget _buildEditorialSummary(Map<String, dynamic>? summary, bool isDarkMode) {
    if (summary == null || !summary.containsKey('text') || summary['text'] == null) {
      return SizedBox.shrink();
    }

    return Text(
      summary['text'],
      style: TextStyle(
        color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
        fontSize: 14,
        height: 1.4,
      ),
    );
  }

// Share place helper
  void _sharePlace() {
    if (_destinationPlace == null) return;

    String shareText = '${_destinationPlace!.name}\n${_destinationPlace!.address}';

    // Add Google Maps link for the location
    final lat = _destinationPlace!.latLng.latitude;
    final lng = _destinationPlace!.latLng.longitude;
    shareText += '\nhttps://maps.google.com/maps?q=$lat,$lng';

    Share.share(shareText);
  }

  // Apply dark style using JSON
  void _applyDarkMapStyle() {
    if (_mapController == null) return;
    _mapController!.setMapStyle(MapStyles.dark);
  }

// Clear custom styling to return to Map ID styling
  void _clearCustomMapStyle() {
    if (_mapController == null) return;
    _mapController!.setMapStyle(null);
  }

// Update map when theme changes
  void _updateMapOnThemeChange() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    if (themeProvider.isDarkMode) {
      _applyDarkMapStyle();
    } else {
      _clearCustomMapStyle();
    }
  }

  ///----------------------------------------------------End of UI Building Methods-----------------------------------------------///

  ///----------------------------------------------------Helper and Utility Methods-----------------------------------------------///

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message))
      );
    }
  }

  void _ensureKeyboardHidden(BuildContext context) {
    // Hide keyboard by removing focus from any text field
    FocusScope.of(context).unfocus();

    // Additional safety - force native keyboard to dismiss using platform channel
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  ///----------------------------------------------------End of Helper and Utility Methods-----------------------------------------------///

}
