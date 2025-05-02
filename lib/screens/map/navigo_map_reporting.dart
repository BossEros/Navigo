part of navigo_map;

extension NavigoMapReportingExtension on _NavigoMapScreenState {
  /// Shows the report panel as a sliding bottom sheet
  void _showReportPanel() {
    // Safety check to prevent issues
    if (!mounted) return;

    try {
      // Get theme state
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final isDarkMode = themeProvider.isDarkMode;

      // Ensure the current location is valid
      final currentLatLng = _currentLocation != null ?
      LatLng(
          _currentLocation!.latitude ?? _defaultLocation.latitude,
          _currentLocation!.longitude ?? _defaultLocation.longitude
      ) : _defaultLocation;

      // Add haptic feedback when opening report panel
      HapticFeedback.mediumImpact();

      // Get screen size to calculate proper height ratios
      final screenHeight = MediaQuery.of(context).size.height;
      final bottomPadding = MediaQuery.of(context).padding.bottom;

      // Show modal bottom sheet with improved styling for modern look
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        useSafeArea: false, // Allow extending into safe areas for seamless look
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        builder: (context) {
          // Calculate max available height, accounting for status bar
          final statusBarHeight = MediaQuery.of(context).padding.top;
          final availableHeight = screenHeight - statusBarHeight;

          return Container(
            height: availableHeight * 0.70, // Use 80% of available height
            margin: EdgeInsets.zero, // No margin to ensure it goes edge to edge
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkTheme.dialogBackgroundColor : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ReportPanel(
                    currentLocation: currentLatLng,
                    onReportSubmitted: (reportTypeId) {
                      _handleReportSubmitted(reportTypeId, currentLatLng);
                    },
                    onClose: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                // Add padding at the bottom to account for navigation bar
                //SizedBox(height: bottomPadding),
              ],
            ),
          );
        },
      ).catchError((error) {
        // Handle any errors that occur when showing the modal
        print('Error showing report panel: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error showing report panel'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      // Catch any unexpected errors
      print('Unexpected error showing report panel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open reporting panel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle a submitted report
  void _handleReportSubmitted(String reportTypeId, LatLng location) {
    // Ensure keyboard remains hidden
    _ensureKeyboardHidden(context);

    // Ensure focus goes to dummy node to prevent keyboard showing
    FocusScope.of(context).requestFocus(_dummyFocusNode);

    try {
      // Get report type information for the confirmation message
      final reportType = ReportTypes.allTypes.firstWhere(
            (type) => type.id == reportTypeId,
        orElse: () => ReportTypes.hazard, // Default fallback
      );

      // Show enhanced confirmation overlay
      if (mounted) {
        _showReportConfirmation(reportType);
      }

      // Add a marker at report location (optional)
      if (mounted) {
        _addReportMarker(reportType, location);
      }
    } catch (e) {
      print('Error handling report submission: $e');
      // Show fallback success message if there's an error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showReportConfirmation(ReportType reportType) {
    // Get theme state
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

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
                          ? Color.lerp(Colors.grey[900], reportType.color, 0.15)
                          : Color.lerp(Colors.white, reportType.color, 0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: reportType.color.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                      border: Border.all(
                          color: reportType.color.withOpacity(0.5),
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
                                  color: reportType.color.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  // Choose between Image and Icon based on the reportType structure
                                  child: reportType.imagePath != null
                                      ? Image.asset(
                                    reportType.imagePath!,
                                    width: 28,
                                    height: 28,
                                  )
                                      : Icon(
                                    reportType.icon ?? Icons.check_circle,
                                    color: reportType.color,
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
                                'Thanks for Your Report!',
                                style: AppTypography.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your ${reportType.label.toLowerCase()} report has been submitted successfully.',
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

  /// Adds a temporary marker at the report location
  void _addReportMarker(ReportType reportType, LatLng location) {
    final markerId = MarkerId('report_${DateTime.now().millisecondsSinceEpoch}');

    // Create BitmapDescriptor for the marker (this would be better with custom markers)
    BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(
      _getMarkerHue(reportType.color),
    );

    // Create the marker
    final marker = Marker(
      markerId: markerId,
      position: location,
      icon: markerIcon,
      infoWindow: InfoWindow(
        title: reportType.label,
        snippet: 'Reported just now',
      ),
      zIndex: 2,  // Above regular markers
    );

    // Add to markers map
    setState(() {
      _markersMap[markerId] = marker;
    });

    // Remove the marker after a delay (optional)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _markersMap.remove(markerId);
        });
      }
    });
  }

  /// Helper to convert color to marker hue
  double _getMarkerHue(Color color) {
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    if (color == Colors.orange) return BitmapDescriptor.hueOrange;
    if (color == Colors.yellow) return BitmapDescriptor.hueYellow;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.blue) return BitmapDescriptor.hueAzure;
    if (color == Colors.indigo || color == Colors.purple) return BitmapDescriptor.hueViolet;
    if (color == Colors.pink) return BitmapDescriptor.hueRose;

    // Default
    return BitmapDescriptor.hueRed;
  }
}