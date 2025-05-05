part of navigo_map;

/// --------------------------------Shortcuts and User Preferences---------------------------------------------///

extension NavigoMapShortcutsExtension on _NavigoMapScreenState {
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

  void _saveOrUnsaveLocation() async {
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

            // Show unsave confirmation instead of Snackbar
            _showUnsaveConfirmation(_destinationPlace!.name);
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

            _showSaveConfirmation(_destinationPlace!.name, selectedCategory);
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

  Future<String?> _showCategorySelectionDialog() async {
    String category = 'favorite'; // Default category

    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // Theme-aware background color
          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Save to...',
            style: AppTypography.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              // Theme-aware text color
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
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
                      isDarkMode,
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTypography.textTheme.labelLarge?.copyWith(
                  // Theme-aware text color
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(category),
              child: Text(
                'Save',
                style: AppTypography.textTheme.labelLarge?.copyWith(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

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

  void _handleShortcutTapFromAllScreen(dynamic shortcut) {
    // Cast the dynamic parameter to the expected type
    _handleCustomShortcutTap(shortcut as QuickAccessShortcut);
  }

  void _handleShortcutsReorder(List<dynamic> reorderedShortcuts) async {
    // Update local shortcuts list
    setState(() {
      _quickAccessShortcuts = List<QuickAccessShortcut>.from(reorderedShortcuts);
    });

    // Persist the new order to Firebase
    await _saveReorderedShortcuts();
  }

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

      // Show enhanced success message
      if (mounted) {
        _showSuccessOverlay('Shortcut order updated successfully');
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
      // Replace the Snackbar with our new dialog
      _showLocationNotSetDialog(type);
      return;
    }

    // Only proceed if we have valid coordinates
    if (address.lat == 0 && address.lng == 0) {
      // We can also use our new dialog here instead
      _showLocationNotSetDialog(type);
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

  /// Helper method to build category selection radio button option
  Widget _buildCategoryOption(
      String label,
      IconData icon,
      String value,
      String selectedCategory,
      Function(String) onChanged,
      bool isDarkMode,
      ) {
    final isSelected = value == selectedCategory;

    return Theme(
      // Apply a local theme override for this RadioListTile
      data: Theme.of(context).copyWith(
        unselectedWidgetColor: isDarkMode ? Colors.grey[600] : Colors.grey[400],
        radioTheme: RadioThemeData(
          fillColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue;
            }
            return isDarkMode ? Colors.grey[700]! : Colors.grey[400]!;
          }),
        ),
      ),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(
              icon,
              // Apply accent color to the icon
              color: isSelected
                  ? Colors.blue
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                // Theme-aware text color
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        value: value,
        groupValue: selectedCategory,
        activeColor: Colors.blue, // Keep blue selection color for both themes
        selectedTileColor: isDarkMode
            ? Colors.blue.withOpacity(0.1)
            : Colors.blue.withOpacity(0.05),
        onChanged: (String? newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
        // Add shape for better definition in dark mode
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? Colors.blue.withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
    );
  }

  void _showSuccessOverlay(String message) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Add haptic feedback for better UX
    HapticFeedback.mediumImpact();

    // Create an overlay entry
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Positioned(
              top: 150 + (40 * (1 - value)), // Slide down animation
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
                          ? Color.lerp(Colors.grey[900], Colors.green, 0.1)
                          : Color.lerp(Colors.white, Colors.green, 0.05),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                      border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                          width: 1.5
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animated check icon
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
                                  color: Colors.green.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 28,
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
                                'Success!',
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

    // Remove after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _showSaveConfirmation(String locationName, String category) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Add haptic feedback for better UX
    HapticFeedback.mediumImpact();

    // Get category color
    final categoryData = locationCategories[category];
    final Color categoryColor = categoryData?['color'] ?? Colors.blue;

    // Get category icon
    final IconData categoryIcon = getCategoryIcon(category);

    // Create an overlay entry
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Positioned(
              top: 200 + (40 * (1 - value)), // Slide down animation
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
                          ? Color.lerp(Colors.grey[900], categoryColor, 0.15)
                          : Color.lerp(Colors.white, categoryColor, 0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                      border: Border.all(
                          color: categoryColor.withOpacity(0.5),
                          width: 1.5
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animated icon/image container
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
                                  color: categoryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    categoryIcon,
                                    color: categoryColor,
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
                                'Location Saved!',
                                style: AppTypography.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$locationName has been saved to ${getCategoryDisplayName(category)}.',
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

    // Remove after 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _showUnsaveConfirmation(String locationName) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Add haptic feedback for better UX
    HapticFeedback.lightImpact();

    // Create an overlay entry
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Positioned(
              top: 200 + (40 * (1 - value)), // Slide down animation
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
                          ? Color.lerp(Colors.grey[900], Colors.grey[800], 0.15)
                          : Color.lerp(Colors.white, Colors.grey[300], 0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                      border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1.5
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animated icon container
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
                                  color: Colors.grey.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.bookmark_remove,
                                    color: Colors.grey[600],
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
                                'Location Removed',
                                style: AppTypography.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$locationName has been removed from saved locations.',
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

    // Remove after 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _showLocationNotSetDialog(String type) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    // Determine icon and title based on type
    final IconData locationIcon = type == 'home' ? Icons.home : Icons.work;
    final String locationName = type == 'home' ? 'Home' : 'Work';
    final Color iconColor = type == 'home' ? Colors.blue : Colors.blue;

    // Add subtle haptic feedback
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween<double>(begin: 0.8, end: 1.0),
            curve: Curves.easeOutQuint,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Location icon in a nice circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        locationIcon,
                        size: 40,
                        color: iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'No $locationName Location Set',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'You haven\'t set a $locationName address yet. Add your $locationName location to use this shortcut.',
                    textAlign: TextAlign.center,
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Not now button
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Not Now',
                            style: AppTypography.textTheme.labelLarge?.copyWith(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Set location button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _navigateToProfileSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: iconColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Set Location',
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
        );
      },
    );
  }

  // Helper method to navigate to profile settings screen
  void _navigateToProfileSettings() {
    // Here you would navigate to the profile settings screen where users can set their address
    // For example:
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(), // Your profile settings screen
      ),
    );
  }
}