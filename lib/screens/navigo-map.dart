import 'package:google_fonts/google_fonts.dart';
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
import '../component/reusable-location-search_screen.dart';
import '../config/config.dart';
import '../models/map_models/map_ids.dart';
import '../models/route_history.dart';
import '../models/user_profile.dart';
import '../services/google-api-services.dart' as api hide Duration;
import 'package:project_navigo/screens/hamburger_menu_screens/hamburger-menu.dart';
import '../services/route_history_service.dart';
import 'package:project_navigo/services/saved-map_services.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/services/app_constants.dart';
import '../services/user_provider.dart';
import '../themes/app_theme.dart';
import '../themes/app_typography.dart';
import '../themes/theme_provider.dart';
import 'hamburger_menu_screens/all_shortcuts_screen.dart';
import 'login_screen.dart';
import 'package:project_navigo/services/quick_access_shortcut_service.dart';

import 'package:project_navigo/models/map_models/navigation_state.dart';
import 'package:project_navigo/models/map_models/map_style.dart';
import 'package:project_navigo/models/map_models/pulsating_marker_painter.dart';
import 'package:project_navigo/models/map_models/quick_access_shortcut.dart';
import 'package:project_navigo/models/map_models/route_info.dart';
import 'package:project_navigo/utils/map_utilities/location_utils.dart';
import 'package:project_navigo/utils/map_utilities/camera_utils.dart';
import 'package:project_navigo/utils/map_utilities/format_utils.dart';
import 'package:project_navigo/utils/map_utilities/map_utils.dart';
import 'package:project_navigo/utils/map_utilities/ui_constants.dart';

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
  String? _currentAppliedStyle;

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

  @override
  void initState() {
    super.initState();

    _initLocationService();
    _trafficEnabled = false;
    _currentMapStyle = MapStyles.trafficOffMapStyle;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Add this line to fetch recent locations
    _fetchRecentLocations();

    // Initialize quick access shortcuts
    _initQuickAccessShortcuts();

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

  // method to initialize the quick access shortcuts
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

  // Add this method to handle the "New" button tap in the Quick acces button section
  Future<dynamic> _handleNewButtonTap() async {
    try {
      // Show dialog to create a new shortcut
      final result = await _showAddShortcutDialog();

      if (result != null) {
        try {
          // Check if user is logged in
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            _showLoginPrompt();
            return null;
          }

          // Get service if needed
          if (_shortcutService == null) {
            _shortcutService = Provider.of<QuickAccessShortcutService>(context, listen: false);
          }

          // First add to UI for immediate feedback
          setState(() {
            _quickAccessShortcuts.add(result);
          });

          // Scroll to show the new item
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_shortcutsScrollController.hasClients) {
              _shortcutsScrollController.animateTo(
                _shortcutsScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });

          // Save to Firebase
          final newId = await _shortcutService!.addShortcut(
            iconPath: result.iconPath,
            label: result.label,
            lat: result.location.latitude,
            lng: result.location.longitude,
            address: result.address,
            placeId: result.placeId,
          );

          // Create updated shortcut with the new ID
          QuickAccessShortcut? updatedShortcut;

          if (mounted) {
            final index = _quickAccessShortcuts.indexWhere((s) => s.id == result.id);
            if (index >= 0) {
              // Create updated shortcut outside of setState
              updatedShortcut = QuickAccessShortcut(
                id: newId,  // Replace temporary ID with Firebase ID
                iconPath: result.iconPath,
                label: result.label,
                location: result.location,
                address: result.address,
                placeId: result.placeId,
              );

              // Update state
              setState(() {
                _quickAccessShortcuts[index] = updatedShortcut!;
              });
            }
          }

          // Return either the updated shortcut or the original
          return updatedShortcut ?? result;
        } catch (e) {
          print('Error adding shortcut: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error adding shortcut: $e')),
            );
          }
          return null;
        }
      }
      return null;
    } catch (e) {
      print('Error in _handleNewButtonTap: $e');
      return null;
    }
  }

  //==== ADD THIS METHOD FOR SHORTCUT DELETION ====
  void _deleteShortcut(String shortcutId) async {
    try {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showLoginPrompt();
        return;
      }

      // Get service if needed
      if (_shortcutService == null) {
        _shortcutService = Provider.of<QuickAccessShortcutService>(context, listen: false);
      }

      // First update UI
      setState(() {
        _quickAccessShortcuts.removeWhere((shortcut) => shortcut.id == shortcutId);
      });

      // Then delete from Firebase
      await _shortcutService!.deleteShortcut(shortcutId);
    } catch (e) {
      print('Error deleting shortcut: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting shortcut: $e')),
        );
      }
    }
  }

  //==== METHODS FOR LONG-PRESS ACTIONS ====
  void _showShortcutOptions(QuickAccessShortcut shortcut) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shortcut.label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.navigation, color: Colors.blue),
              title: Text('Navigate Now'),
              onTap: () {
                Navigator.pop(context);
                _handleCustomShortcutTap(shortcut);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete Shortcut', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(shortcut);
              },
            ),
          ],
        ),
      ),
    );
  }


  void _showDeleteConfirmation(QuickAccessShortcut shortcut) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Shortcut?'),
        content: Text('Are you sure you want to delete "${shortcut.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteShortcut(shortcut.id);
            },
            child: Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  // Method to show dialog for adding a new shortcut
  Future<QuickAccessShortcut?> _showAddShortcutDialog({
    bool editMode = false,
    QuickAccessShortcut? existingShortcut
  }) async {
    // Get the current theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    final TextEditingController labelController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    String? selectedIcon;
    final formKey = GlobalKey<FormState>();

    // Location variables
    LatLng? selectedLocation;
    String selectedAddress = '';
    String? selectedPlaceId;

    // Pre-populate fields if in edit mode
    if (editMode && existingShortcut != null) {
      labelController.text = existingShortcut.label;
      locationController.text = existingShortcut.label; // Show name in location field
      selectedIcon = existingShortcut.iconPath;
      selectedLocation = existingShortcut.location;
      selectedAddress = existingShortcut.address ?? '';
      selectedPlaceId = existingShortcut.placeId;
    } else {
      // Default icon for new shortcuts
      selectedIcon = 'assets/icons/star_icon.png';
    }

    return showDialog<QuickAccessShortcut>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (context, setState) {
                // Function to handle location selection
                Future<void> _selectLocation() async {
                  final result = await Navigator.push<api.Place>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationSearchScreen(
                        title: 'Select Location',
                        searchHint: 'Search for a location',
                      ),
                    ),
                  );

                  if (result != null) {
                    setState(() {
                      selectedLocation = result.latLng;
                      selectedAddress = result.address;
                      selectedPlaceId = result.id;
                      locationController.text = result.name;
                    });
                  }
                }

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 8,
                  // Theme-aware background color
                  backgroundColor: isDarkMode
                      ? AppTheme.darkTheme.dialogBackgroundColor
                      : Colors.white,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header with title - changes based on mode
                            Center(
                              child: Text(
                                editMode ? 'Edit Shortcut' : 'Add Quick Access',
                                style: AppTypography.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  // Theme-aware text color
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Shortcut name input
                            Text(
                              'Name',
                              style: AppTypography.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                // Theme-aware text color
                                color: isDarkMode ? Colors.white : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: labelController,
                              decoration: InputDecoration(
                                hintText: 'Enter shortcut name',
                                filled: true,
                                // Theme-aware fill color
                                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    // Theme-aware border color
                                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    // Theme-aware border color
                                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 16.0,
                                ),
                                counterText: '${labelController.text.length}/15',
                                // Theme-aware hint text and counter
                                hintStyle: TextStyle(
                                  color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                                ),
                                counterStyle: TextStyle(
                                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                                ),
                              ),
                              // Theme-aware text style
                              style: AppTypography.textTheme.bodyLarge?.copyWith(
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              maxLength: 15,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Location selection
                            Text(
                              'Location',
                              style: AppTypography.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                // Theme-aware text color
                                color: isDarkMode ? Colors.white : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                // Theme-aware background color
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedLocation != null
                                      ? Colors.blue
                                      : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                                  width: selectedLocation != null ? 2 : 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _selectLocation,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: selectedLocation != null
                                              ? Colors.blue
                                              : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                selectedLocation != null
                                                    ? locationController.text
                                                    : 'Select location',
                                                style: AppTypography.textTheme.bodyLarge?.copyWith(
                                                  color: selectedLocation != null
                                                      ? (isDarkMode ? Colors.white : Colors.black87)
                                                      : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                                  fontWeight: selectedLocation != null
                                                      ? FontWeight.w500
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                              if (selectedLocation != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  selectedAddress,
                                                  style: AppTypography.textTheme.bodySmall?.copyWith(
                                                    // Theme-aware text color
                                                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          // Theme-aware icon color
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (selectedLocation != null) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    // Theme-aware border color
                                    border: Border.all(
                                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Static Google Maps image
                                      Image.network(
                                        'https://maps.googleapis.com/maps/api/staticmap?center=${selectedLocation!.latitude},${selectedLocation!.longitude}&zoom=15&size=400x200&markers=color:red%7C${selectedLocation!.latitude},${selectedLocation!.longitude}&key=${AppConfig.apiKey}',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) {
                                          // Fallback if map image fails to load - theme-aware
                                          return Container(
                                            // Theme-aware background color
                                            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                            child: Center(
                                              child: Icon(
                                                Icons.map,
                                                size: 40,
                                                // Theme-aware icon color
                                                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Location pin overlay
                                      Center(
                                        child: Icon(
                                          Icons.location_pin,
                                          color: Colors.red,
                                          size: 36,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Icon selection
                            Text(
                              'Choose an Icon',
                              style: AppTypography.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                // Theme-aware text color
                                color: isDarkMode ? Colors.white : Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 100,
                              decoration: BoxDecoration(
                                // Theme-aware background color
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                // Theme-aware border color
                                border: Border.all(
                                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                ),
                              ),
                              child: GridView.builder(
                                padding: const EdgeInsets.all(8),
                                scrollDirection: Axis.horizontal,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 1,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                                itemCount: 8,
                                // More icons
                                itemBuilder: (context, index) {
                                  List<String> icons = [
                                    'assets/icons/home_icon.png',
                                    'assets/icons/work_icon.png',
                                    'assets/icons/restaurant_icon.png',
                                    'assets/icons/fastfood_icon.png',
                                    'assets/icons/hotel_icon.png',
                                    'assets/icons/shopping_icon.png',
                                    'assets/icons/gym_icon.png',
                                    'assets/icons/school_icon.png',
                                    'assets/icons/cafe_icon.png',
                                    'assets/icons/star_icon.png',
                                  ];
                                  String iconPath = index < icons.length
                                      ? icons[index]
                                      : 'assets/icons/star_icon.png';

                                  bool isSelected = iconPath == selectedIcon;

                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedIcon = iconPath;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          // Theme-aware background color for selected items
                                          color: isSelected
                                              ? (isDarkMode
                                              ? Colors.blue.withOpacity(0.2)
                                              : Colors.blue.withOpacity(0.1))
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.blue
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Image.asset(
                                            iconPath,
                                            width: 32,
                                            height: 32,
                                            // Apply color filter in dark mode to brighten icons
                                            errorBuilder: (context, error, stackTrace) {
                                              // Fallback for missing assets - theme-aware
                                              return Icon(
                                                Icons.star,
                                                color: isSelected
                                                    ? Colors.blue
                                                    : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                                                size: 32,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Action buttons - theme-aware
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Cancel button
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      // Theme-aware text color
                                      foregroundColor: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: AppTypography.textTheme.labelLarge?.copyWith(
                                        // Theme-aware text color
                                        color: isDarkMode ? Colors.white : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Add/Save button
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (formKey.currentState?.validate() == true) {
                                        if (selectedLocation == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Please select a location'),
                                              // Theme-aware background
                                              backgroundColor: isDarkMode ? Colors.grey[800] : null,
                                            ),
                                          );
                                          return;
                                        }

                                        // Create new or updated shortcut
                                        final shortcut = QuickAccessShortcut(
                                          // Keep the original ID if editing
                                          id: editMode && existingShortcut != null
                                              ? existingShortcut.id
                                              : 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                          iconPath: selectedIcon!,
                                          label: labelController.text.trim(),
                                          location: selectedLocation!,
                                          address: selectedAddress,
                                          placeId: selectedPlaceId,
                                        );

                                        Navigator.of(context).pop(shortcut);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      // Theme-aware button colors
                                      backgroundColor: isDarkMode
                                          ? AppTheme.darkTheme.colorScheme.primary
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      editMode ? 'Save Changes' : 'Add Shortcut',
                                      style: AppTypography.textTheme.labelLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
          );
        }
    );
  }


  // Add this helper method for icon selection
  Widget _buildIconOption(StateSetter setState, String iconPath, String? selectedIcon) {
    final bool isSelected = iconPath == selectedIcon;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIcon = iconPath;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Image.asset(
            iconPath,
            width: 24,
            height: 24,
          ),
        ),
      ),
    );
  }


  // Method to save shortcuts to persistent storage (optional)
  void _saveQuickAccessShortcuts() async {
    try {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showLoginPrompt();
        return;
      }

      // Get the shortcut service if not already available
      if (_shortcutService == null) {
        _shortcutService = Provider.of<QuickAccessShortcutService>(context, listen: false);
      }

      // Save to Firebase (directly using the UI shortcuts)
      await _shortcutService!.saveShortcuts(_quickAccessShortcuts);

      // Optional: Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Your shortcuts have been saved')),
        );
      }
    } catch (e) {
      print('Error saving shortcuts: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving shortcuts: $e')),
        );
      }
    }
  }


  // Method to handle custom shortcut tap
  void _handleCustomShortcutTap(QuickAccessShortcut shortcut) async {
    try {
      // Close keyboard
      FocusScope.of(context).unfocus();

      // Close the sliding panel
      _panelController.close();

      setState(() {
        _isSearching = true;
      });

      // Create a Place object from the shortcut
      api.Place place = api.Place(
        id: shortcut.placeId ?? 'custom_${shortcut.id}',
        name: shortcut.label,
        address: shortcut.address,
        latLng: shortcut.location,
        types: ['custom_shortcut'],
      );

      // Try to get additional details if we have a place ID
      if (shortcut.placeId != null && shortcut.placeId!.isNotEmpty) {
        try {
          final detailedPlace = await api.GoogleApiServices.getPlaceDetails(shortcut.placeId!);
          if (detailedPlace != null) {
            // Create a new place with the original name but detailed data
            place = api.Place(
              id: detailedPlace.id,
              name: shortcut.label, // Keep the custom label
              address: detailedPlace.address,
              latLng: detailedPlace.latLng,
              types: detailedPlace.types,
            );

            // Load photos
            final photos = await api.GoogleApiServices.getPlacePhotos(place.id);
            place.photoUrls = photos;
          }
        } catch (e) {
          print('Error getting additional place details: $e');
          // Continue with basic place info since we already have essentials
        }
      }

      if (mounted) {
        setState(() {
          _destinationPlace = place;
          _navigationState = NavigationState.placeSelected;
          _searchController.text = place.name;
          _placeSuggestions = [];
          _isSearching = false;
        });

        _addDestinationMarker(place);
        _loadPlacePhotos();

        // Center camera on the location
        _centerCameraOnLocation(
          location: place.latLng,
          zoom: 16,
          tilt: 30,
        );

        // Start navigation
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _startNavigation();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _showErrorSnackBar('Error navigating to shortcut: $e');
      }
    }
  }

  void _updateNavigationState(NavigationState newState) {
    // Only update if the state is actually changing
    if (_navigationState == newState) return;

    setState(() {
      _navigationState = newState;

      // Ensure other flags are synchronized with the navigation state
      switch (newState) {
        case NavigationState.placeSelected:
          _showingRouteAlternatives = false;
          _isNavigating = false;
          _isInNavigationMode = false;
          break;
        case NavigationState.routePreview:
          _showingRouteAlternatives = true;
          _isNavigating = false;
          _isInNavigationMode = false;
          break;
        case NavigationState.activeNavigation:
          _showingRouteAlternatives = false;
          _isNavigating = true;
          _isInNavigationMode = true;
          break;
        case NavigationState.idle:
          _showingRouteAlternatives = false;
          _isNavigating = false;
          _isInNavigationMode = false;
          break;
      }
    });

    // Debug logging to track state transitions
    print('Navigation state changed to: $newState');
  }

  // Method to show saved location:
  void _showSavedLocationOnMap() async {
    if (widget.savedPlaceId == null || widget.savedCoordinates == null) return;

    // Wait for map controller to be initialized
    await Future.delayed(const Duration(milliseconds: 300));
    if (_mapController == null) {
      // Retry once more if map controller isn't ready
      await Future.delayed(const Duration(milliseconds: 500));
      if (_mapController == null) return;
    }

    // Use the new centralized method for camera positioning
    _centerCameraOnLocation(
      location: widget.savedCoordinates!,
      zoom: 16,
      tilt: 30,
    );

    // Create a place suggestion to work with existing code
    final suggestion = api.PlaceSuggestion(
      placeId: widget.savedPlaceId!,
      description: widget.savedName ?? 'Saved Location',
      mainText: widget.savedName ?? 'Saved Location',
      secondaryText: '',
    );

    try {
      // Select the place to show details card
      await _selectPlace(suggestion);

      // Start navigation if requested (after location is loaded)
      if (widget.startNavigation && _destinationPlace != null) {
        // Small delay to ensure UI is updated
        await Future.delayed(const Duration(milliseconds: 300));
        _startNavigation();
      }
    } catch (e) {
      print('Error displaying saved location: $e');
      _showErrorSnackBar('Could not load location details');
    }
  }

  Widget _buildSelectedPlaceCard() {
    if (_navigationState != NavigationState.placeSelected) return const SizedBox.shrink();

    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          // Theme-aware background
          color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              // Darker shadow in dark mode
              color: isDarkMode
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle with theme-aware color
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Location name and address with theme-aware text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _destinationPlace!.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                            Icons.location_on,
                            size: 16,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600]
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _destinationPlace!.address,
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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

              // Actions row - Save and Navigate buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Save button with updated functionality
                  _buildActionButton(
                    icon: _isLocationSaved ? Icons.bookmark : Icons.bookmark_border,
                    label: _isLocationSaved ? 'Saved' : 'Save',
                    onPressed: _saveOrUnsaveLocation,
                    isLoading: _isLoadingLocationSave,
                    isDarkMode: isDarkMode,
                  ),

                  // Navigate button
                  _buildActionButton(
                    icon: Icons.navigation,
                    label: 'Navigate',
                    onPressed: _startNavigation,
                    isPrimary: true,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Photos section with theme-aware styling
              Container(
                height: 120,
                padding: const EdgeInsets.only(left: 16),
                child: _destinationPlace!.photoUrls.isEmpty && _isLoadingPhotos
                    ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isDarkMode ? Colors.white : Colors.blue
                    ),
                  ),
                )
                    : _destinationPlace!.photoUrls.isEmpty
                    ? Center(
                  child: Text(
                    'No photos available',
                    style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600]
                    ),
                  ),
                )
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _destinationPlace!.photoUrls.length,
                  itemBuilder: (context, index) {
                    return _buildPhotoItem(
                        _destinationPlace!.photoUrls[index],
                        isDarkMode: isDarkMode
                    );
                  },
                ),
              ),

              // Information section with theme-aware styling
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                            Icons.access_time,
                            size: 16,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600]
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Operating hours may vary',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
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
                          Icon(
                              Icons.category,
                              size: 16,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600]
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getFormattedType(_destinationPlace!.types.first),
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
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


  // Method to show a saved location on the map
  void showSavedLocation(String placeId, LatLng coordinates, String name) {
    // Create a place suggestion to use with existing methods
    final suggestion = api.PlaceSuggestion(
      placeId: placeId,
      description: name,
      mainText: name,
      secondaryText: '',
    );

    // Use existing method to select place
    _selectPlace(suggestion);
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
    bool isLoading = false,
    bool isDarkMode = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              // Theme-aware colors
              color: isPrimary
                  ? Colors.blue
                  : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  isPrimary ? Colors.white : Colors.blue
              ),
              strokeWidth: 2,
            )
                : Icon(
              icon,
              // Keep blue for contrast in dark mode
              color: isPrimary ? Colors.white : Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              // Blue stays for primary, but text color changes based on theme
              color: isPrimary ? Colors.blue : (isDarkMode ? Colors.white : Colors.black),
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

  Widget _buildPhotoItem(String imageUrl, {bool isDarkMode = false}) {
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        // Add subtle border in dark mode
        border: isDarkMode
            ? Border.all(color: Colors.grey[800]!, width: 1)
            : null,
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
              // Darker background in dark mode
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  // White in dark mode for contrast
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkMode ? Colors.white : Colors.blue
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading image: $error');
            return Container(
              // Darker background in dark mode
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              child: Center(
                child: Icon(
                    Icons.broken_image,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400]
                ),
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

  Future<void> _fetchRecentLocations() async {
    if (!mounted) return;

    setState(() {
      _isLoadingRecentLocations = true;
    });

    try {
      final locations = await _recentLocationsService.getRecentLocations();

      if (mounted) {
        setState(() {
          _recentLocations = locations;
          _isLoadingRecentLocations = false;
        });
      }
    } catch (e) {
      print('Error fetching recent locations: $e');
      if (mounted) {
        setState(() {
          _isLoadingRecentLocations = false;
        });
      }
    }
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

        // Use the new centralized method for camera positioning
        _centerCameraOnLocation(
          location: place.latLng,
          zoom: 16,
          tilt: 30,
        );

        // Check if the location is saved (if you have this functionality)
        if (_savedMapService != null) {
          _checkIfLocationIsSaved();
        }

        // Add to recent locations
        try {
          await _recentLocationsService.addRecentLocation(
            placeId: place.id,
            name: place.name,
            address: place.address,
            lat: place.latLng.latitude,
            lng: place.latLng.longitude,
            iconType: place.types.isNotEmpty ? place.types.first : null,
          );

          // Refresh recent locations list
          _fetchRecentLocations();
        } catch (e) {
          print('Error adding to recent locations: $e');
          // Continue even if this fails
        }

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

  Future<void> _selectRecentLocation(RecentLocation location) async {
    try {
      // Close keyboard
      FocusScope.of(context).unfocus();

      // Close the sliding panel
      _panelController.close();

      setState(() {
        _isSearching = true;
      });

      // Create a Place object from RecentLocation
      api.Place place = api.Place(
        id: location.placeId,
        name: location.name,
        address: location.address,
        latLng: LatLng(location.lat, location.lng),
        types: location.iconType != null ? [location.iconType!] : [],
      );

      // Try to get additional details and photos if needed
      try {
        final detailedPlace = await api.GoogleApiServices.getPlaceDetails(location.placeId);
        if (detailedPlace != null) {
          place = detailedPlace;

          // Load photos
          final photos = await api.GoogleApiServices.getPlacePhotos(place.id);
          place.photoUrls = photos;
        }
      } catch (e) {
        print('Error getting additional place details: $e');
        // Continue with basic place info since we already have essentials
      }

      if (mounted) {
        setState(() {
          _destinationPlace = place;
          _navigationState = NavigationState.placeSelected;
          _searchController.text = place.name;
          _placeSuggestions = [];
          _isSearching = false;
        });

        _addDestinationMarker(place);
        _loadPlacePhotos();

        // Use the centralized camera positioning method instead of direct animation
        // This ensures the marker isn't covered by the details panel
        _centerCameraOnLocation(
          location: place.latLng,
          zoom: 16,
          tilt: 30,
        );

        // Update the timestamp in recent locations
        try {
          await _recentLocationsService.addRecentLocation(
            placeId: place.id,
            name: place.name,
            address: place.address,
            lat: place.latLng.latitude,
            lng: place.latLng.longitude,
            iconType: place.types.isNotEmpty ? place.types.first : null,
          );

          // Refresh the list
          _fetchRecentLocations();
        } catch (e) {
          print('Error updating recent location timestamp: $e');
          // Continue even if updating timestamp fails
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _showErrorSnackBar('Error selecting recent location: $e');
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

    final LatLngBounds bounds = CameraUtils.calculateBoundsFromPoints(
        [currentLocation, place.latLng]
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, UiConstants.standardPadding * 3),
    );
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

      // Enable traffic layer when starting navigation if it's disabled
      if (!_trafficEnabled) {
        _toggleTrafficLayer();
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

      // Clear any existing route info markers first
      _clearRouteInfoMarkers();

      // Add all routes with different styles
      for (int i = 0; i < _routeAlternatives[0].routes.length; i++) {
        final route = _routeAlternatives[0].routes[i];
        final polylineId = PolylineId('route_$i');
        final isSelected = i == _selectedRouteIndex;

        // Enhanced visibility for polylines
        final polyline = Polyline(
          polylineId: polylineId,
          points: route.polylinePoints,
          // Use brighter colors that stand out better
          color: isSelected ? Colors.blue.shade600 : Colors.lightBlue.shade200,
          // Increase width for better visibility
          width: isSelected ? 8 : 5,
          // Higher z-index for the selected route
          zIndex: isSelected ? 3 : 1,
          // Add a border effect using endCap and jointType for more distinct appearance
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
          jointType: JointType.round,
          // Pattern for additional visibility (optional)
          // patterns: isSelected ? [PatternItem.dash(10), PatternItem.gap(5)] : [],
          // Enable tap events
          onTap: () {
            // Only update if not already selected
            if (!isSelected) {
              _updateDisplayedRoute(i);
            }
          },
          consumeTapEvents: true, // Prevent map from receiving the tap
        );

        _polylinesMap[polylineId] = polyline;

        // Add duration markers for each route
        _addRouteDurationMarker(route, i, isSelected);
      }
    });
  }

  // Create a custom bitmap for route duration bubbles
  Future<BitmapDescriptor> _createRouteDurationBitmap(String duration, bool isSelected) async {
    // Use a simple Flutter widget to generate a bitmap
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(80, 40);

    // Draw a rounded rectangle background
    final paint = Paint()
      ..color = isSelected
          ? const Color(0xFF66B2FF) // Light blue for selected route
          : const Color(0xFF888888); // Gray for alternate routes

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(20));
    canvas.drawRRect(rrect, paint);

    // Add text
    final textSpan = TextSpan(
      text: isSelected ? "$duration\nBest" : duration,
      style: TextStyle(
        color: Colors.white,
        fontSize: isSelected ? 16 : 14,
        fontWeight: FontWeight.bold,
        height: 1.0,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(minWidth: size.width, maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );

    // Convert to image
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      // Fallback to standard marker if conversion fails
      return BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueViolet
      );
    }

    final Uint8List bytes = byteData.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  // Helper method to add route duration markers
  void _addRouteDurationMarker(api.Route route, int routeIndex, bool isSelected) {
    // Skip if no legs
    if (route.legs.isEmpty) return;

    final leg = route.legs[0];
    final points = route.polylinePoints;

    // Find a good position for the marker (around 40% along the route)
    // This helps ensure the marker is visible but not too close to either end
    final markerPosition = LocationUtils.findPositionAlongRoute(points, 0.4);

    // Create marker ID
    final markerId = MarkerId('route_duration_$routeIndex');

    // Get duration text
    final durationText = leg.duration.text;

    // Create a route duration bubble using a custom bitmap
    _createRouteDurationBitmap(durationText, isSelected).then((BitmapDescriptor customIcon) {
      if (!mounted) return;

      setState(() {
        _markersMap[markerId] = Marker(
          markerId: markerId,
          position: markerPosition,
          // Use our custom bitmap for the route duration
          icon: customIcon,
          // No info window needed as we have a custom bubble
          infoWindow: InfoWindow.noText,
          // Higher z-index to ensure visibility over the route lines
          zIndex: isSelected ? 3 : 2,
          // Make the icon clickable
          consumeTapEvents: true,
          visible: true,
          // When tapped, select this route
          onTap: () {
            if (!isSelected) {
              _updateDisplayedRoute(routeIndex);
            }
          },
        );
      });
    });
  }


  // Clear all route info markers before creating new ones
  void _clearRouteInfoMarkers() {
    // Remove any markers with IDs starting with 'route_duration_'
    _markersMap.removeWhere((markerId, marker) =>
        markerId.value.startsWith('route_duration_'));
  }

  void _stopNavigation() {
    _completeNavigationReset();
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    _trafficEnabled = themeProvider.isTrafficEnabled;

    return Scaffold(
      // ONLY change to prevent the UI from moving up when keyboard appears
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  print("Map Created with Cloud Map ID: ${_getCurrentMapId()}");
                },
                cloudMapId: _getCurrentMapId(),
                markers: _markers,
                polylines: _polylines,
                mapType: _currentMapType,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                trafficEnabled: _trafficEnabled,
                scrollGesturesEnabled: !_isInNavigationMode,
                zoomGesturesEnabled: !_isInNavigationMode,
                tiltGesturesEnabled: !_isInNavigationMode,
                rotateGesturesEnabled: !_isInNavigationMode
            ),

            // SlidingUpPanel with original structure
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

  String _getCurrentMapId() {
    // Get theme state from provider
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Determine which Map ID to use based on app state
    if (_isInNavigationMode) {
      return MapIds.navigationMapId;
    } else if (isDarkMode) {
      return MapIds.nightMapId;
    } else if (!_trafficEnabled) {
      return MapIds.trafficOffMapId;
    } else {
      return MapIds.defaultMapId;
    }
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

  // Add this method to check if location is saved
  Future<void> _checkIfLocationIsSaved() async {
    if (_destinationPlace == null ||
        FirebaseAuth.instance.currentUser == null ||
        _savedMapService == null) {
      setState(() {
        _isLocationSaved = false;
      });
      return;
    }

    final placeId = _destinationPlace!.id;

    // Check cache first
    if (_savedLocationCache.containsKey(placeId)) {
      setState(() {
        _isLocationSaved = _savedLocationCache[placeId]!;
      });
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final isSaved = await _savedMapService!.isLocationSaved(
        userId: userId,
        placeId: placeId,
      );

      // Update cache and state
      _savedLocationCache[placeId] = isSaved;

      if (mounted) {
        setState(() {
          _isLocationSaved = isSaved;
        });
      }
    } catch (e) {
      print('Error checking if location is saved: $e');
      if (mounted) {
        setState(() {
          _isLocationSaved = false;
        });
      }
    }
  }

  // Add this method to handle saving/unsaving locations
  Future<void> _saveOrUnsaveLocation() async {
    if (_destinationPlace == null || _savedMapService == null) {
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      _showLoginPrompt();
      return;
    }

    final userId = FirebaseAuth.instance.currentUser!.uid;

    setState(() {
      _isLoadingLocationSave = true;
    });

    try {
      if (_isLocationSaved) {
        // Location is already saved, so unsave it
        // First get the saved location document
        final savedLocation = await _savedMapService!.getSavedLocationByPlaceId(
          userId: userId,
          placeId: _destinationPlace!.id,
        );

        if (savedLocation != null) {
          await _savedMapService!.deleteSavedLocation(
            userId: userId,
            savedMapId: savedLocation.id,
          );

          if (mounted) {
            setState(() {
              _isLocationSaved = false;
            });

            // Update cache
            _savedLocationCache[_destinationPlace!.id] = false;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_destinationPlace!.name} removed from saved locations')),
            );
          }
        }
      } else {
        // Location is not saved, so save it
        // Show category selection dialog
        final selectedCategory = await _showCategorySelectionDialog();

        if (selectedCategory != null) {
          final savedMapId = await _savedMapService!.saveLocation(
            userId: userId,
            placeId: _destinationPlace!.id,
            name: _destinationPlace!.name,
            address: _destinationPlace!.address,
            lat: _destinationPlace!.latLng.latitude,
            lng: _destinationPlace!.latLng.longitude,
            category: selectedCategory,
          );

          if (mounted) {
            setState(() {
              _isLocationSaved = true;
            });

            // Update cache
            _savedLocationCache[_destinationPlace!.id] = true;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${_destinationPlace!.name} saved to ${getCategoryDisplayName(selectedCategory)}')),
            );
          }
        }
      }
    } catch (e) {
      print('Error saving/unsaving location: $e');
      _showErrorSnackBar('Error saving location: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocationSave = false;
        });
      }
    }
  }

  // Helper method to show login prompt
  void _showLoginPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please log in to save locations'),
        action: SnackBarAction(
          label: 'Login',
          onPressed: () {
            // Navigate to login screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ),
    );
  }

  // Helper method to show category selection dialog
  Future<String?> _showCategorySelectionDialog() async {
    String category = 'favorite'; // Default category

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save to...'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: locationCategories.entries.map((entry) {
                    final key = entry.key;
                    final data = entry.value;
                    return _buildCategoryOption(
                      data['displayName'],
                      data['icon'],
                      key,
                      category,
                          (value) => setState(() => category = value),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(category),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to build category option
  Widget _buildCategoryOption(
      String label,
      IconData icon,
      String value,
      String selectedCategory,
      Function(String) onChanged,
      ) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      value: value,
      groupValue: selectedCategory,
      onChanged: (String? newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }

  Widget _buildCollapsedRoutePanel() {
    if (_routeAlternatives.isEmpty) return const SizedBox.shrink();

    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final route = _routeAlternatives[0].routes[_selectedRouteIndex];
    final leg = route.legs[0];

    return Container(
      decoration: BoxDecoration(
        // Theme-aware background
        color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            // Darker shadow in dark mode
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle with theme-aware color
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Route summary with theme-aware text
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      leg.distance.text,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),

                // Go button with theme-aware styling
                ElevatedButton(
                  onPressed: () {
                    _startActiveNavigation();
                  },
                  style: ElevatedButton.styleFrom(
                    // Use theme colors
                    backgroundColor: isDarkMode
                        ? AppTheme.darkTheme.colorScheme.primary
                        : AppTheme.lightTheme.colorScheme.primary,
                    foregroundColor: Colors.white,
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

    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final routes = _routeAlternatives[0].routes;

    return Container(
      // Theme-aware background
      color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
      child: Column(
        children: [
          // Drag handle with theme-aware color
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Route info header with theme-aware text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Your location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _destinationPlace?.name ?? 'Destination',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      overflow: TextOverflow.ellipsis,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Routes list with theme-aware styling
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
                      // Theme-aware background with selection highlight
                      color: _selectedRouteIndex == index
                          ? (isDarkMode
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.1))
                          : (isDarkMode ? Colors.grey[850] : Colors.white),
                      border: Border.all(
                        color: _selectedRouteIndex == index
                            ? Colors.blue
                            : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: isDarkMode ? Colors.white : Colors.black87,
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
                                      // Keep green for best route even in dark mode
                                      color: isDarkMode
                                          ? Colors.green[900]
                                          : Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green),
                                    ),
                                    child: Text(
                                      'Best',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.green[300]
                                            : Colors.green,
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
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
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
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[800],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 4),

                        // Traffic info
                        Text(
                          'Typical traffic',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
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

          // Bottom buttons with theme-aware styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              // Theme-aware background
              color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
              boxShadow: [
                BoxShadow(
                  // Darker shadow in dark mode
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
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
                  // Use theme-aware text color
                  style: TextButton.styleFrom(
                    foregroundColor: isDarkMode ? Colors.blue[300] : Colors.blue,
                  ),
                  child: const Text('Leave later'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _startActiveNavigation();
                  },
                  style: ElevatedButton.styleFrom(
                    // Use theme-specific colors
                    backgroundColor: isDarkMode
                        ? AppTheme.darkTheme.colorScheme.primary
                        : AppTheme.lightTheme.colorScheme.primary,
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
      return FormatUtils.extractRoadName(longestStep.instruction);
    }

    return "Unknown route";
  }

  void _startActiveNavigation() {
    if (_routeAlternatives.isEmpty || _selectedRouteIndex >= _routeAlternatives[0].routes.length) {
      _showErrorSnackBar('No route selected');
      return;
    }

    _navigationStartTime = DateTime.now();

    // Use the helper method to ensure consistent state
    _updateNavigationState(NavigationState.activeNavigation);

    setState(() {
      // Additional state updates specific to active navigation
      _polylinesMap.clear();
      final polylineId = const PolylineId('active_route');

      // Create an enhanced polyline for active navigation
      final polyline = Polyline(
        polylineId: polylineId,
        points: _routeAlternatives[0].routes[_selectedRouteIndex].polylinePoints,
        color: Colors.blue.shade600,
        width: 9,  // Thicker line for navigation mode
        zIndex: 3, // High z-index to ensure visibility
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
        jointType: JointType.round,
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

  }

  void _handleShortcutTapFromAllScreen(dynamic shortcut) {
    // Cast the dynamic parameter to the expected type
    _handleCustomShortcutTap(shortcut as QuickAccessShortcut);
  }

  void _handleReorderShortcuts(List<dynamic> reorderedShortcuts) {
    setState(() {
      _quickAccessShortcuts = reorderedShortcuts.cast<QuickAccessShortcut>();
    });

    // Save with error handling
    try {
      _saveQuickAccessShortcuts();
    } catch (e) {
      print('Error saving reordered shortcuts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shortcut order. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Add this method to navigate to the All Shortcuts screen
  void _navigateToAllShortcuts() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllShortcutsScreen(
          shortcuts: _quickAccessShortcuts,
          onShortcutTap: _handleShortcutTapFromAllScreen,
          onAddNewShortcut: _handleNewButtonTap,
          onDeleteShortcut: _deleteShortcut,
          onReorderShortcuts: _handleShortcutsReorder,
        ),
      ),
    );

    // Process the result if it's an edit request
    if (result != null && result is Map && result['action'] == 'edit') {
      final shortcut = result['shortcut'];
      if (shortcut != null) {
        _editExistingShortcut(shortcut);
      }
    }
  }

  Future<void> _editExistingShortcut(QuickAccessShortcut shortcut) async {
    try {
      // Use the existing dialog but in edit mode
      final updatedShortcut = await _showAddShortcutDialog(
          editMode: true,
          existingShortcut: shortcut
      );

      if (updatedShortcut != null) {
        setState(() {
          // Find and replace the shortcut in the list
          final index = _quickAccessShortcuts.indexWhere((s) => s.id == shortcut.id);
          if (index >= 0) {
            _quickAccessShortcuts[index] = updatedShortcut;
          }
        });

        // Save to Firebase
        await _saveReorderedShortcuts();

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shortcut updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error editing shortcut: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating shortcut: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleShortcutsReorder(List<dynamic> reorderedShortcuts) async {
    // Update local shortcuts list
    setState(() {
      _quickAccessShortcuts = List<QuickAccessShortcut>.from(reorderedShortcuts);
    });

    // Persist the new order to Firebase
    await _saveReorderedShortcuts();
  }

  // Method to save reordered shortcuts to Firebase
  Future<void> _saveReorderedShortcuts() async {
    try {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showLoginPrompt();
        return;
      }

      // Get service if needed
      if (_shortcutService == null) {
        _shortcutService = Provider.of<QuickAccessShortcutService>(context, listen: false);
      }

      // Save to Firebase
      await _shortcutService!.saveShortcuts(_quickAccessShortcuts);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shortcut order updated'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving reordered shortcuts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving shortcut order: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      final distanceToNextTurn = LocationUtils.calculateDistanceInMeters(_lastKnownLocation!, currentStep.endLocation);

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
    final distanceToStepEnd = LocationUtils.calculateDistanceInMeters(currentLocation, currentStep.endLocation);

    // If we're close to the end of the current step, move to the next one
    // Use a threshold based on GPS accuracy - typically 20-50 meters
    if (distanceToStepEnd < 30) { // 30 meters threshold
      if (_currentStepIndex < leg.steps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });
      } else {
        // We've reached the last step, check if we're close to destination
        final distToDestination = LocationUtils.calculateDistanceInMeters(currentLocation, leg.endLocation);

        if (distToDestination < 30) {
          _handleArrival();
        }
      }
    }
  }

  void _logNavigationEvent(String event, [dynamic data]) {
    print("NAVIGATION: $event ${data != null ? '- $data' : ''}");
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

    // Save the completed route to history
    _saveCompletedRoute();

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

  Future<void> _saveCompletedRoute() async {
    // Skip if any required data is missing
    if (_routeDetails == null ||
        _destinationPlace == null ||
        _currentLocation == null ||
        _routeDetails!.routes.isEmpty) {
      print('Missing data for saving route history');
      return;
    }

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user found');
        return;
      }

      // Get the selected route and its first leg
      final route = _routeDetails!.routes[_selectedRouteIndex];
      final leg = route.legs[0];

      // Create origin Address object
      final startLocation = Address(
        formattedAddress: leg.startAddress.isNotEmpty
            ? leg.startAddress
            : 'Your location',
        lat: leg.startLocation.latitude,
        lng: leg.startLocation.longitude,
        placeId: '', // We might not have this
      );

      // Create destination Address object
      final endLocation = Address(
        formattedAddress: _destinationPlace!.address,
        lat: _destinationPlace!.latLng.latitude,
        lng: _destinationPlace!.latLng.longitude,
        placeId: _destinationPlace!.id,
      );

      // Convert polyline points to encoded string if needed
      String encodedPolyline = '';
      if (route.polylinePoints.isNotEmpty) {
        // This might need a custom encoder depending on how you're storing polylines
        // For simplicity, we're just using a string representation
        encodedPolyline = route.polylinePoints.toString();
      }

      // Determine traffic conditions (simplified)
      String trafficCondition = 'normal';
      final actualDuration = DateTime.now().difference(_navigationStartTime).inSeconds;
      final estimatedDuration = leg.duration.value;

      if (actualDuration > estimatedDuration * 1.2) {
        trafficCondition = 'heavy';
      } else if (actualDuration < estimatedDuration * 0.8) {
        trafficCondition = 'light';
      }

      // Create the RouteHistory object
      final routeHistory = RouteHistory(
        id: '', // Will be set by Firebase
        startLocation: startLocation,
        endLocation: endLocation,
        waypoints: [], // Add any waypoints if available
        distance: Distance(
          text: leg.distance.text,
          value: leg.distance.value,
        ),
        duration: TravelDuration(
          text: leg.duration.text,
          value: actualDuration, // Use actual time rather than estimated
        ),
        createdAt: DateTime.now(),
        travelMode: 'DRIVING', // Update based on actual mode
        polyline: encodedPolyline,
        routeName: _destinationPlace!.name,
        trafficConditions: trafficCondition,
        weatherConditions: null, // Would need weather API integration
      );

      // Get route history service
      final routeHistoryService = RouteHistoryService();

      // Save the route
      final routeId = await routeHistoryService.saveCompletedRoute(
        userId: user.uid,
        routeHistory: routeHistory,
      );

      print('Route history saved successfully with ID: $routeId');

    } catch (e) {
      print('Error saving route history: $e');
      // Don't show error to user - silently log it
    }
  }

  Widget _buildUIOverlays() {
    return Stack(
      children: [

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
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      // Theme-aware background color
      backgroundColor: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        height: 300,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Options with theme-aware styling
            ListTile(
              title: Text(
                'Leave now',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              leading: Icon(
                Icons.directions_car,
                color: isDarkMode ? Colors.blue[300] : Colors.blue,
              ),
              onTap: () {
                Navigator.pop(context);
                _startActiveNavigation();
              },
            ),
            ListTile(
              title: Text(
                'Leave in 30 minutes',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              leading: Icon(
                Icons.access_time,
                color: isDarkMode ? Colors.blue[300] : Colors.blue,
              ),
              onTap: () {
                Navigator.pop(context);
                // You would implement delayed routing here
              },
            ),
            ListTile(
              title: Text(
                'Leave in 1 hour',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              leading: Icon(
                Icons.access_time,
                color: isDarkMode ? Colors.blue[300] : Colors.blue,
              ),
              onTap: () {
                Navigator.pop(context);
                // You would implement delayed routing here
              },
            ),
            ListTile(
              title: Text(
                'Choose departure time',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              leading: Icon(
                Icons.calendar_today,
                color: isDarkMode ? Colors.blue[300] : Colors.blue,
              ),
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
      top: 15,
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
    // Get dark mode state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        // Theme-aware background color
        color: color ?? (isDarkMode ? Colors.grey[800] : Colors.white),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            // Darker shadow for dark mode
            color: isDarkMode
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 28),
        // Theme-aware icon color
        color: color != null
            ? Colors.white
            : (isDarkMode ? Colors.white : Colors.black87),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(),
      ),
    );
  }

  Widget _buildCustomCircularButton({
    required String iconAsset,
    required VoidCallback onPressed,
    Color? color,
    double buttonSize = 48, // Configurable button size
    double iconSize = 28,    // Configurable icon size
    double borderRadius = 10, // Configurable border radius
  }) {
    // Get dark mode state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        // Theme-aware background color
        color: color ?? (isDarkMode ? Colors.grey[800] : Colors.white),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            // Darker shadow for dark mode
            color: isDarkMode
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.15),
            blurRadius: 6, // Slightly bigger shadow for larger button
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onPressed,
          child: Center(
            child: Image.asset(
              iconAsset,
              width: iconSize,
              height: iconSize,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to default icon if asset fails to load
                return Icon(
                  Icons.warning_amber_rounded,
                  size: iconSize,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Toggle function
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

  Widget _buildMapActionButtons() {
    // For navigation mode, include a more prominent traffic button
    if (_isInNavigationMode) {
      return Positioned(
        right: 16,
        bottom: MediaQuery.of(context).size.height / 2 - 28,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Remove traffic toggle button
            SizedBox(height: 8),

            FloatingActionButton(
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
          ],
        ),
      );
    }

    // For standard mode, remove traffic toggle completely
    return const SizedBox.shrink();
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
        child: Material(
          elevation: 4.0,
          color: Colors.white,
          borderRadius: BorderRadius.circular(32), // Larger circular radius
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: () {
              // Implement Hazard Reporting here
            },
            child: Container(
              width: 64, // Increased from default FAB size
              height: 64, // Increased from default FAB size
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/icons/warning_icon.png',
                width: 40, // Larger icon
                height: 40, // Larger icon
              ),
            ),
          ),
        ),
      );
    }

    // For other states, show the regular report button
    return Positioned(
      bottom: 200,
      left: 16,
      child: _buildCustomCircularButton(
        iconAsset: 'assets/icons/warning_icon.png',
        onPressed: () {
          // Implement Hazard Reporting here
        },
        buttonSize: 56, // Increased button size
        iconSize: 32, // Increased icon size
      ),
    );
  }

  Widget _buildNavigationInfoPanel() {
    if (!_isInNavigationMode || _routeDetails == null) {
      return const SizedBox.shrink();
    }

    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final route = _routeDetails!.routes[0];
    final leg = route.legs[0];

    if (leg.steps.isEmpty || _currentStepIndex >= leg.steps.length) {
      return const SizedBox.shrink();
    }

    final currentStep = leg.steps[_currentStepIndex];

    // Calculate distance to next maneuver
    String distanceText = currentStep.distance.text;
    if (_lastKnownLocation != null) {
      final distanceToStepEnd = LocationUtils.calculateDistanceInMeters(
          _lastKnownLocation!, currentStep.endLocation);
      distanceText = FormatUtils.formatDistance(distanceToStepEnd.toInt());
    }

    // Calculate ETA
    final eta = _calculateETA();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main instruction panel with theme-aware styling
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // Theme-aware background
              color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  // Darker shadow in dark mode
                  color: isDarkMode
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
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
                    // Darker background for top bar in dark mode
                    color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Distance to destination
                      Row(
                        children: [
                          Icon(
                              Icons.location_on,
                              size: 14,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey
                          ),
                          const SizedBox(width: 4),
                          Text(
                            leg.distance.text,
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // ETA
                      Row(
                        children: [
                          Icon(
                              Icons.access_time,
                              size: 14,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey
                          ),
                          const SizedBox(width: 4),
                          Text(
                            eta,
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
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
                      // Maneuver icon - don't change color based on theme
                      _buildManeuverIcon(currentStep.instruction),
                      const SizedBox(width: 16),

                      // Instruction text and distance
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FormatUtils.cleanInstruction(currentStep.instruction),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'In $distanceText',
                              style: TextStyle(
                                // Keep blue for visibility in both themes
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
                        icon: Icon(
                          Icons.more_vert,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
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
                            // Darker circle in dark mode
                            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Then ${FormatUtils.cleanInstruction(leg.steps[_currentStepIndex + 1].instruction)}',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
        final distanceToStepEnd = LocationUtils.calculateDistanceInMeters(_lastKnownLocation!, currentStep.endLocation);
        final totalStepDistance = LocationUtils.calculateDistanceInMeters(currentStep.startLocation, currentStep.endLocation);

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
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Ensure keyboard is hidden before showing options
    _ensureKeyboardHidden(context);

    // Set focus to dummy node to prevent text fields from getting focus
    FocusScope.of(context).requestFocus(_dummyFocusNode);

    showModalBottomSheet(
      context: context,
      // Theme-aware background
      backgroundColor: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
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
                  color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Options with theme-aware styling
            ListTile(
              leading: Icon(
                Icons.list_alt,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              title: Text(
                'Show all steps',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showAllSteps();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.map,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              title: Text(
                'Overview map',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRouteOverview();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.stop_circle,
                color: isDarkMode ? Colors.red[300] : Colors.red,
              ),
              title: Text(
                'End navigation',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
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
                          FormatUtils.cleanInstruction(step.instruction),
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


  // Show a confirmation dialog before ending navigation
  void _showEndNavigationDialog() {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Theme-aware background
        backgroundColor: isDarkMode ? AppTheme.darkTheme.dialogBackgroundColor : Colors.white,
        title: Text(
          'End Navigation',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to end navigation?',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            // Use theme-aware text color
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeNavigationReset();
            },
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.red[300] : Colors.red,
            ),
            child: const Text('End'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        // Apply theme-aware background color
        color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            // Soften shadow in dark mode
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle with theme-aware color
          _buildDragHandle(isDarkMode),

          // Search bar with theme awareness
          _buildSearchBar(isDarkMode),

          // Content area - changes based on search state
          Expanded(
            child: _searchController.text.isEmpty
                ? _buildDefaultContent(isDarkMode)
                : _buildSearchResults(isDarkMode),
          )
        ],
      ),
    );
  }

  Widget _buildDragHandle(bool isDarkMode) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          // Lighter gray in dark mode
          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600]
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                onEditingComplete: () {
                  _ensureKeyboardHidden(context);
                },
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Where to?',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600]
                  ),
                ),
                onChanged: _onSearchChanged,
                onTap: () {
                  // Ensure panel is open when search is tapped
                  if (!_panelController.isPanelOpen) {
                    _panelController.open();
                  }
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
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                onPressed: () {
                  // Voice search functionality
                },
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildDefaultContent(bool isDarkMode) {
    // Calculate shortcuts to show as before
    final int maxCustomShortcutsToShow = 2;
    final displayShortcuts = _quickAccessShortcuts.take(maxCustomShortcutsToShow).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick access buttons section
        Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
          // Theme-aware background
          color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title with theme-aware text
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0, left: 4.0),
                child: Text(
                  'Quick Access',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    // Theme-aware text color
                    color: isDarkMode ? Colors.white : Colors.grey[800],
                    letterSpacing: -0.3,
                  ),
                ),
              ),

              // Scrollable container for buttons
              Container(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  controller: _shortcutsScrollController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Pass isDarkMode to each button
                    // Home button
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildQuickAccessButton(
                        'assets/icons/home_icon.png',
                        'Home',
                        _handleHomeButtonTap,
                        isDarkMode: isDarkMode,
                      ),
                    ),

                    // Work button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildQuickAccessButton(
                        'assets/icons/work_icon.png',
                        'Work',
                        _handleWorkButtonTap,
                        isDarkMode: isDarkMode,
                      ),
                    ),

                    // Custom shortcuts with dark mode
                    ...displayShortcuts.map((shortcut) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildQuickAccessButton(
                        shortcut.iconPath,
                        shortcut.label,
                            () => _handleCustomShortcutTap(shortcut),
                        isDarkMode: isDarkMode,
                      ),
                    )),

                    // Loading indicator with dark mode support
                    if (_isLoadingShortcuts)
                      Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          // Darker background in dark mode
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              // Lighter color in dark mode
                              color: isDarkMode ? Colors.grey[300] : Colors.grey[400],
                            ),
                          ),
                        ),
                      ),

                    // "See All" button with dark mode
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildQuickAccessButton(
                        'assets/icons/plus_icon.png',
                        'See All',
                        _navigateToAllShortcuts,
                        isDarkMode: isDarkMode,
                        errorIconData: Icons.manage_search,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Visual divider between sections
        Container(
          height: 8,
          // Darker divider in dark mode
          color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        ),

        // Recent locations section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title with theme-aware text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Recent Places',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: -0.3,
                    // Theme-aware text color
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),

              // Loading state
              if (_isLoadingRecentLocations)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              // Empty state with dark mode support
              else if (_recentLocations.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            // Darker background in dark mode
                            color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              Icons.history,
                              size: 32,
                              // Lighter icon in dark mode
                              color: isDarkMode ? Colors.grey[600] : Colors.grey[400]
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recent locations',
                          style: GoogleFonts.poppins(
                            // Theme-aware text color
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Places you search for will appear here',
                          style: GoogleFonts.poppins(
                            // Lighter text in dark mode
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              // List with dark mode support
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _recentLocations.length,
                    itemBuilder: (context, index) {
                      final location = _recentLocations[index];
                      return _buildRecentLocationItem(
                        location.name,
                        location.address,
                            () => _selectRecentLocation(location),
                        MapUtils.getIconForPlaceType(location.iconType),
                        isDarkMode,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(bool isDarkMode) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              // Use theme-aware color
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.white : Colors.blue
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching places...',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return _buildDefaultContent(isDarkMode);
    }

    if (_placeSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                Icons.search_off,
                size: 48,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400]
            ),
            const SizedBox(height: 16),
            Text(
              'No places found for "${_searchController.text}"',
              style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.grey[600]
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or check your internet connection',
              style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600]
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _onSearchChanged(_searchController.text);
              },
              // Use theme colors from AppTheme
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? AppTheme.darkTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
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
          leading: Icon(
              Icons.location_on,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600]
          ),
          title: Text(
            suggestion.mainText,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            suggestion.secondaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          trailing: Text(
            _getFormattedDistanceForSuggestion(suggestion) == "-"
                ? "-"
                : "${_getFormattedDistanceForSuggestion(suggestion)} km",
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
          onTap: () => _selectPlace(suggestion),
        );
      },
    );
  }

  String _getFormattedDistanceForSuggestion(api.PlaceSuggestion suggestion) {
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

  // Updated async calculation:
  Future<void> _calculateDistanceAsync(api.PlaceSuggestion suggestion) async {
    try {
      // Get place details to access its coordinates
      final place = await api.GoogleApiServices.getPlaceDetails(suggestion.placeId);

      if (place != null && _currentLocation != null && mounted) {
        // Use LocationUtils for calculation
        final distanceInMeters = LocationUtils.calculateDistanceInMeters(
            LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
            place.latLng
        );

        // Use FormatUtils for formatting
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

  // This method stays exactly as it is in your original code
  Widget _buildQuickAccessButton(
      String iconPath,
      String label,
      VoidCallback onTap, {
        IconData errorIconData = Icons.star,
        bool isDarkMode = false,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 80,
        width: 80,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          // Theme-aware background
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // Darker shadow in dark mode
              color: isDarkMode
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 4,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            // Darker border in dark mode
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with theme support
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                iconPath,
                width: 32,
                height: 32,
                // Apply color filter in dark mode to make icons lighter if needed
                //color: isDarkMode ? Colors.white : null,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    errorIconData,
                    // Lighter icon in dark mode
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    size: 32,
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            // Label with theme support
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                // Theme-aware text color
                color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _handleHomeButtonTap() {
    _navigateToUserAddress('home');
  }

  void _handleWorkButtonTap() {
    _navigateToUserAddress('work');
  }

  Future<void> _navigateToUserAddress(String type) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Determine which address to use
    final Address address = type == 'home'
        ? userProvider.userProfile?.homeAddress ?? Address.empty()
        : userProvider.userProfile?.workAddress ?? Address.empty();

    // Check if address is set
    if (userProvider.userProfile == null ||
        address.formattedAddress.isEmpty) {
      // Address not set
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No ${type == 'home' ? 'Home' : 'Work'} location set. Please update your profile to add this location.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Only proceed if we have valid coordinates
    if (address.lat == 0 && address.lng == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid ${type == 'home' ? 'Home' : 'Work'} location coordinates. Please update your profile.'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // Close keyboard
      FocusScope.of(context).unfocus();

      // Close the sliding panel
      _panelController.close();

      setState(() {
        _isSearching = true;
      });

      // Create a Place object from the address
      final String name = type == 'home' ? 'Home' : 'Work';
      api.Place place = api.Place(
        id: address.placeId.isNotEmpty ? address.placeId : '${type}_${address.lat}_${address.lng}',
        name: name,
        address: address.formattedAddress,
        latLng: LatLng(address.lat, address.lng),
        types: [type],
      );

      // If we have a valid placeId, try to get additional details
      if (address.placeId.isNotEmpty) {
        try {
          final detailedPlace = await api.GoogleApiServices.getPlaceDetails(address.placeId);
          if (detailedPlace != null) {
            // Create a new place with the original name but detailed data
            place = api.Place(
              id: detailedPlace.id,
              name: name, // Keep the original name (Home/Work)
              address: detailedPlace.address,
              latLng: detailedPlace.latLng,
              types: detailedPlace.types,
            );

            // Load photos
            final photos = await api.GoogleApiServices.getPlacePhotos(place.id);
            place.photoUrls = photos;
          }
        } catch (e) {
          print('Error getting additional place details: $e');
          // Continue with basic place info since we already have essentials
        }
      }

      if (mounted) {
        setState(() {
          _destinationPlace = place;
          _navigationState = NavigationState.placeSelected;
          _searchController.text = place.name;
          _placeSuggestions = [];
          _isSearching = false;
        });

        _addDestinationMarker(place);
        _loadPlacePhotos();

        // Center camera on the location
        _centerCameraOnLocation(
          location: place.latLng,
          zoom: 16,
          tilt: 30,
        );

        // Immediately start navigation
        await Future.delayed(const Duration(milliseconds: 300)); // Give UI time to update
        if (mounted) {
          _startNavigation();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        _showErrorSnackBar('Error navigating to ${type == 'home' ? 'Home' : 'Work'} address: $e');
      }
    }
  }

  Widget _buildRecentLocationItem(
      String title,
      String subtitle,
      VoidCallback onTap,
      [IconData icon = Icons.location_on_outlined,
        bool isDarkMode = false]
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // Theme-aware background
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        boxShadow: [
          BoxShadow(
            // Adjusted shadow for dark mode
            color: isDarkMode
                ? Colors.black.withOpacity(0.15)
                : Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            // Darker blue background in dark mode
            color: isDarkMode
                ? Colors.blue.withOpacity(0.2)
                : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            // Same blue color in both modes for contrast
            color: Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: -0.2,
            // Theme-aware text color
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
            fontSize: 13,
            // Lighter text in dark mode
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            letterSpacing: -0.1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
        onLongPress: () {
          if (title != 'Home' && title != 'Work' && title != 'New') {
            _showRecentLocationOptions(title, subtitle, onTap, isDarkMode);
          }
        },
        trailing: Icon(
          Icons.chevron_right,
          // Lighter icon in dark mode
          color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
          size: 20,
        ),
      ),
    );
  }

  // Method to show options when long pressing a recent location
  // Update method signature
  void _showRecentLocationOptions(String title, String subtitle, VoidCallback onSelect, [bool isDarkMode = false]) {
    // Find the location in our list
    final location = _recentLocations.firstWhere(
          (loc) => loc.name == title && loc.address == subtitle,
      orElse: () => RecentLocation(
        id: '',
        placeId: '',
        name: title,
        address: subtitle,
        lat: 0,
        lng: 0,
        accessedAt: DateTime.now(),
      ),
    );

    // If we couldn't find the location, don't show options
    if (location.id.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      elevation: 10,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle - theming
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Location name header - theming
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Address - theming
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 24),

            // Navigate option - theming
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.navigation, color: Colors.blue, size: 20),
              ),
              title: Text(
                'Navigate to this location',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onSelect();
              },
            ),

            // Remove option - theming
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.red.withOpacity(0.2)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
              title: Text(
                'Remove from recent locations',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _recentLocationsService.deleteRecentLocation(location.id);
                  // Refresh the list
                  _fetchRecentLocations();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Removed from recent locations',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: isDarkMode ? Colors.grey[800] : null,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  print('Error removing recent location: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error removing location',
                        style: GoogleFonts.poppins(),
                      ),
                      backgroundColor: isDarkMode ? Colors.grey[800] : null,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}