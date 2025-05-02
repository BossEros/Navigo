part of navigo_map;

extension NavigoMapSearchExtension on _NavigoMapScreenState {
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

  String _getFormattedType(String type) {
    // Convert 'place_of_worship' to 'Place of Worship'
    return type.split('_').map((word) =>
    word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : ''
    ).join(' ');
  }

  void _updateAllSuggestionDistances() {
    if (_placeSuggestions.isEmpty || _currentLocation == null) return;

    for (var suggestion in _placeSuggestions) {
      if (!_suggestionDistances.containsKey(suggestion.placeId)) {
        _calculateDistanceAsync(suggestion);
      }
    }
  }

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
}


