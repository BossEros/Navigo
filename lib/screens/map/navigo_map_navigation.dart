part of navigo_map;

extension NavigoMapNavigationExtension on _NavigoMapScreenState {
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

  void _startActiveNavigation() async {
    if (_routeAlternatives.isEmpty || _selectedRouteIndex >= _routeAlternatives[0].routes.length) {
      _showErrorSnackBar('No route selected');
      return;
    }

    // Load the navigation arrow icon if not already loaded
    try {
      if (_navigationArrowIcon == null) {
        print('Loading navigation arrow icon...');
        _navigationArrowIcon = await _createNavigationArrowIcon();
        print('Navigation arrow icon loaded successfully: ${_navigationArrowIcon != null}');
      } else {
        print('Using existing navigation arrow icon');
      }
    } catch (e) {
      print('Error loading navigation arrow icon: $e');
      // Continue with default icon if custom icon fails
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

    // Initialize with current position and force marker update
    if (_currentLocation != null) {
      _lastKnownLocation = LatLng(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );

      // Force an immediate update of the navigation marker
      _updateCurrentNavigationMarker();

      // Then update the camera
      _updateNavigationCamera();
    }
  }

  // New helper method to update the navigation marker specifically
  void _updateCurrentNavigationMarker() {
    if (_lastKnownLocation == null) return;

    final markerId = const MarkerId('currentLocation');

    print('Updating navigation marker with arrow icon: ${_navigationArrowIcon != null}');

    final marker = Marker(
      markerId: markerId,
      position: _lastKnownLocation!,
      icon: _navigationArrowIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      rotation: _navigationBearing,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      zIndex: 2,
    );

    // Update marker without setState to avoid unnecessarily rebuilding the UI
    _markersMap[markerId] = marker;

    // Only call setState if we need to rebuild the UI
    if (mounted) {
      setState(() {});
    }
  }

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
      }
    });
  }

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

      // Log the marker creation for debugging
      print('Creating navigation marker with arrow icon: ${_navigationArrowIcon != null}');

      final marker = Marker(
        markerId: markerId,
        position: newLocation,
        // Use our custom navigation arrow icon
        icon: _navigationArrowIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: bearing, // Rotate marker to show direction
        flat: true, // Keep marker flat on the map
        anchor: const Offset(0.5, 0.5), // Center the marker at the image center
        zIndex: 2, // Ensure it appears above other markers
      );

      _markersMap[markerId] = marker;
    });

    // Update the camera to follow the user
    _updateNavigationCamera();

    // Check if we've reached the next instruction point
    _checkRouteProgress(newLocation);
  }

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
        _routeDetails!.routes.isNotEmpty &&
        _routeDetails!.routes[0].legs.isNotEmpty &&
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

    // For a Waze-like experience, we want to offset the camera target
    // in front of the user's current location in the direction of travel

    // Calculate a point ahead of the current location using the bearing
    final forwardDistance = 150.0; // Distance in meters to look ahead
    final double bearingRadians = _navigationBearing * (pi / 180.0);

    // Calculate the offset (simplified version for small distances)
    final double earthRadius = 6371000.0; // Earth radius in meters
    final double latRad = _lastKnownLocation!.latitude * (pi / 180.0);

    // Calculate new lat/lng with offset
    final newLat = _lastKnownLocation!.latitude +
        (forwardDistance * cos(bearingRadians) / earthRadius) * (180.0 / pi);
    final newLng = _lastKnownLocation!.longitude +
        (forwardDistance * sin(bearingRadians) / (earthRadius * cos(latRad))) * (180.0 / pi);

    final LatLng targetPosition = LatLng(newLat, newLng);

    // Create a camera position with Waze-like settings
    final cameraPosition = CameraPosition(
      target: targetPosition, // Position ahead of user
      zoom: _navigationZoom,
      tilt: 60.0, // Increased tilt for Waze-like 3D perspective
      bearing: _navigationBearing, // Match the direction of travel
    );

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(cameraPosition),
    );
  }

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

    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Show arrival dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Theme-aware background
        backgroundColor: isDarkMode ? AppTheme.darkTheme.dialogBackgroundColor : Colors.white,
        title: Text(
          'You\'ve Arrived',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'You\'ve reached ${_destinationPlace?.name ?? 'your destination'}.',
          style: AppTypography.textTheme.bodyLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeNavigationReset();
            },
            child: Text(
              'OK',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: Colors.blue,
              ),
            ),
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

  void _logNavigationEvent(String event, [dynamic data]) {
    print("NAVIGATION: $event ${data != null ? '- $data' : ''}");
  }

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

  void _showAllSteps() {
    if (_routeDetails == null) return;

    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Ensure keyboard is hidden
    _ensureKeyboardHidden(context);

    // Set focus to dummy node
    FocusScope.of(context).requestFocus(_dummyFocusNode);

    final route = _routeDetails!.routes[0];
    final leg = route.legs[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow the sheet to be larger
      // Theme-aware background
      backgroundColor: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
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
                // Theme-aware background
                color: isDarkMode ? AppTheme.darkTheme.cardTheme.color : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle with theme-aware color
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          // Lighter color in dark mode
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),

                    // Title with back button - theme-aware colors
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            // Theme-aware icon color
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            // Ensure keyboard remains hidden when returning
                            _ensureKeyboardHidden(context);
                          },
                        ),
                        Text(
                          'All Steps',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            // Theme-aware text color
                            color: isDarkMode ? Colors.white : Colors.black87,
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
                      // Theme-aware highlight color
                      color: isCurrent
                          ? (isDarkMode
                          ? Colors.blue.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.1))
                          : Colors.transparent,
                      child: ListTile(
                        leading: _buildManeuverIcon(step.instruction),
                        title: Text(
                          FormatUtils.cleanInstruction(step.instruction),
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            // Theme-aware text color
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          step.distance.text,
                          style: TextStyle(
                            // Theme-aware subtitle color - lighter in dark mode
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
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
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to end navigation?',
          style: AppTypography.textTheme.bodyLarge?.copyWith(
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
            child: Text(
              'Cancel',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeNavigationReset();
            },
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.red[300] : Colors.red,
            ),
            child: Text(
              'End',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: isDarkMode ? Colors.red[300] : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<BitmapDescriptor> _createNavigationArrowIcon() async {
    try {
      print('Attempting to load navigation arrow icon from assets...');

      // Create a better configuration for the icon
      final ImageConfiguration config = ImageConfiguration(
        size: Size(48, 48),
        devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
      );

      // Load the icon with the improved configuration
      return await BitmapDescriptor.fromAssetImage(
        config,
        'assets/navigation-arrow_icon.png',
      );
    } catch (e) {
      print('Error loading navigation arrow asset: $e');
      print('Stack trace: ${StackTrace.current}');

      // If asset loading fails, use default marker as fallback
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }
}