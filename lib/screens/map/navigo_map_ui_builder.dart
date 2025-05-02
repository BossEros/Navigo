part of 'navigo-map.dart';

extension NavigoMapUIBuilderExtension on _NavigoMapScreenState {
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
              // Theme-aware colors with more contrast in dark mode
              color: isPrimary
                  ? Colors.blue
                  : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
              shape: BoxShape.circle,
              // Add subtle border in dark mode for better definition
              border: isDarkMode && !isPrimary
                  ? Border.all(color: Colors.grey[700]!, width: 1)
                  : null,
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
            // Use the app's typography system instead of hardcoded TextStyle
            style: AppTypography.textTheme.labelMedium?.copyWith(
              // Use theme-aware colors
              color: isPrimary
                  ? Colors.blue
                  : (isDarkMode ? Colors.white : Colors.black87),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTopMenuButtons() {
    return Positioned(
      top: 15, // This is now relative to the map container, not the screen
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

  Widget _buildMapActionButtons() {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

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
              // Theme-aware background color
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
              // Adjusted elevation for dark mode
              elevation: isDarkMode ? 6.0 : 4.0,
              child: Icon(
                  Icons.my_location,
                  // Keep blue color for better visibility in both themes
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 24
              ),
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
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // Skip rendering the report button if we're in route selection mode
    if (_showingRouteAlternatives) {
      return const SizedBox.shrink(); // Return an empty widget
    }

    // For navigation mode, show the report button at bottom left
    if (_isInNavigationMode) {
      return Positioned(
        bottom: 120, // Position at bottom with padding
        left: 16, // Position at left
        child: Material(
          elevation: 4.0,
          // Theme-aware background color
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(32), // Larger circular radius
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: _showReportPanel, // Call our report panel method
            child: Container(
              width: 64, // Increased from default FAB size
              height: 64, // Increased from default FAB size
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/icons/warning_icon.png',
                width: 40, // Larger icon
                height: 40, // Larger icon
                // Add color filter in dark mode to ensure visibility if needed
                //color: isDarkMode ? Colors.amber[300] : null,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback icon with theme-aware color
                  return Icon(
                    Icons.warning_amber,
                    size: 40,
                    color: Colors.amber[600],
                  );
                },
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
        onPressed: _showReportPanel, // Call our report panel method
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

          // Bottom button - Only "Go now" remains
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
            child: SizedBox(
              width: double.infinity, // Full width button
              child: ElevatedButton(
                onPressed: () {
                  _startActiveNavigation();
                },
                style: ElevatedButton.styleFrom(
                  // Use theme-specific colors
                  backgroundColor: isDarkMode
                      ? AppTheme.darkTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Go now',
                    style: AppTypography.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
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
}