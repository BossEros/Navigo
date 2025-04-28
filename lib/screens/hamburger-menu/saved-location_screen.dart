import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:project_navigo/screens/map/navigo-map.dart';
import 'package:project_navigo/models/saved_map.dart';
import 'package:project_navigo/services/saved-map_services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/services/app_constants.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:provider/provider.dart'; // Added for ThemeProvider
import 'package:project_navigo/themes/theme_provider.dart'; // Added for ThemeProvider

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({Key? key}) : super(key: key);

  @override
  _SavedLocationsScreenState createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final SavedMapService _savedMapService = SavedMapService();

  List<SavedMap> _savedLocations = [];
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _error;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 20;
  String? _selectedCategory;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchSavedLocations();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreLocations();
    }
  }

  Future<void> _fetchSavedLocations() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'No user logged in';
          _isLoading = false;
        });
        return;
      }

      final locations = await _savedMapService.getSavedLocations(
        userId: user.uid,
        category: _selectedCategory,
        limit: _pageSize,
      );

      if (locations.isNotEmpty) {
        _lastDocument = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_maps')
            .orderBy('saved_at', descending: true)
            .limit(_pageSize)
            .get()
            .then((snapshot) => snapshot.docs.last);
      }

      setState(() {
        _savedLocations = locations;
        _isLoading = false;
        _hasMore = locations.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading saved locations: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Central method for location interaction
  void _handleLocationInteraction(SavedMap location, {bool startNavigation = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MyApp(
          savedPlaceId: location.placeId,
          savedCoordinates: LatLng(location.lat, location.lng),
          savedName: location.name,
          startNavigation: startNavigation,
        ),
      ),
    );
  }

  Future<void> _loadMoreLocations() async {
    if (!mounted || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      final locations = await _savedMapService.getSavedLocations(
        userId: user.uid,
        category: _selectedCategory,
        limit: _pageSize,
        startAfterDocument: _lastDocument,
      );

      if (locations.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('saved_maps')
            .orderBy('saved_at', descending: true)
            .startAfterDocument(_lastDocument!)
            .limit(_pageSize)
            .get();

        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
      }

      setState(() {
        _savedLocations.addAll(locations);
        _isLoadingMore = false;
        _hasMore = locations.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading more locations: $e',
              style: AppTypography.textTheme.bodyMedium,
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteLocation(SavedMap location) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _savedMapService.deleteSavedLocation(
        userId: user.uid,
        savedMapId: location.id,
      );

      setState(() {
        _savedLocations.removeWhere((loc) => loc.id == location.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location deleted',
            style: AppTypography.textTheme.bodyMedium,
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _fetchSavedLocations(); // Refresh to restore
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error deleting location: $e',
            style: AppTypography.textTheme.bodyMedium,
          ),
        ),
      );
    }
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _lastDocument = null; // Reset pagination
    });
    _fetchSavedLocations();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final locationDate = DateTime(date.year, date.month, date.day);

    if (locationDate == today) {
      return 'Today ${DateFormat('h:mm a').format(date)}';
    } else if (locationDate == yesterday) {
      return 'Yesterday ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    // Get the theme provider to access the current theme mode
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      // Apply theme-aware background color
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        title: Text(
          'Saved Locations',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            // Apply theme-aware text color
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        // Apply theme-aware AppBar styling
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Icon color is handled by foregroundColor
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            // Icon color is handled by foregroundColor
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading && _savedLocations.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          // Apply theme-aware progress indicator color
          valueColor: AlwaysStoppedAnimation<Color>(
            isDarkMode ? Colors.white : Colors.blue,
          ),
        ),
      );
    }

    if (_error != null && _savedLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              // Apply theme-aware icon color
              color: isDarkMode ? Colors.grey[400] : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSavedLocations,
              // Button styling is defined in the theme
              child: Text(
                'Try Again',
                style: AppTypography.authButton,
              ),
            ),
          ],
        ),
      );
    }

    if (_savedLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              // Apply theme-aware icon color
              color: isDarkMode ? Colors.grey[400] : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved locations',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                // Apply theme-aware text color
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCategory != null
                  ? 'No locations saved in this category'
                  : 'Your saved locations will appear here',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            if (_selectedCategory != null) const SizedBox(height: 16),
            if (_selectedCategory != null)
              ElevatedButton(
                onPressed: () => _filterByCategory(null),
                // Button styling is defined in the theme
                child: Text(
                  'Show All Locations',
                  style: AppTypography.authButton,
                ),
              ),
          ],
        ),
      );
    }

    // Group locations by category
    Map<String, List<SavedMap>> groupedLocations = {};
    for (var location in _savedLocations) {
      if (!groupedLocations.containsKey(location.category)) {
        groupedLocations[location.category] = [];
      }
      groupedLocations[location.category]!.add(location);
    }

    return RefreshIndicator(
      onRefresh: _fetchSavedLocations,
      // Apply theme-aware refresh indicator color
      color: isDarkMode ? Colors.white : Colors.blue,
      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: groupedLocations.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedLocations.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  // Apply theme-aware progress indicator color
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDarkMode ? Colors.white : Colors.blue,
                  ),
                ),
              ),
            );
          }

          final category = groupedLocations.keys.elementAt(index);
          final categoryLocations = groupedLocations[category]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _getCategoryDisplayName(category),
                  style: AppTypography.textTheme.headlineSmall?.copyWith(
                    // Apply theme-aware text color
                    color: isDarkMode ? Colors.white : null,
                  ),
                ),
              ),
              ...categoryLocations.map((location) => _buildLocationCard(location, isDarkMode)).toList(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  final Map<String, Map<String, dynamic>> locationCategories = {
    'favorite': {
      'displayName': 'Favorites',
      'icon': Icons.favorite,
      'color': Colors.red,
    },
    'food': {
      'displayName': 'Food & Dining',
      'icon': Icons.restaurant,
      'color': Colors.orange,
    },
    'shopping': {
      'displayName': 'Shopping',
      'icon': Icons.shopping_bag,
      'color': Colors.lightBlue,
    },
    'entertainment': {
      'displayName': 'Entertainment',
      'icon': Icons.movie,
      'color': Colors.purple,
    },
    'services': {
      'displayName': 'Services',
      'icon': Icons.business,
      'color': Colors.teal,
    },
    'other': {
      'displayName': 'Other Places',
      'icon': Icons.place,
      'color': Colors.amber,
    },
  };

  String _getCategoryDisplayName(String category) {
    return getCategoryDisplayName(category);
  }

  IconData _getCategoryIcon(String category) {
    return getCategoryIcon(category);
  }

  Color _getCategoryColor(String category) {
    return getCategoryColor(category);
  }

  Widget _buildLocationCard(SavedMap location, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      // Apply theme-aware card styling
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _handleLocationInteraction(location),
        borderRadius: BorderRadius.circular(12),
        // Apply theme-aware splash color
        splashColor: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(location.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      _getCategoryIcon(location.category),
                      color: _getCategoryColor(location.category),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Location details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: AppTypography.textTheme.titleMedium?.copyWith(
                            // Apply theme-aware text color
                            color: isDarkMode ? Colors.white : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location.address,
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            // Apply theme-aware text color
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saved ${_formatDate(location.savedAt)}',
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            // Apply theme-aware text color
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Options menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      // Apply theme-aware icon color
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation(location, isDarkMode);
                      } else if (value == 'navigate') {
                        _navigateToLocation(location);
                      } else if (value == 'view') {
                        _viewOnMap(location);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            // Apply theme-aware icon color
                            Icon(Icons.map, size: 18, color: isDarkMode ? Colors.white : null),
                            const SizedBox(width: 8),
                            Text(
                              'View on Map',
                              style: AppTypography.textTheme.bodyMedium?.copyWith(
                                // Apply theme-aware text color
                                color: isDarkMode ? Colors.white : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'navigate',
                        child: Row(
                          children: [
                            // Apply theme-aware icon color
                            Icon(Icons.navigation, size: 18, color: isDarkMode ? Colors.white : null),
                            const SizedBox(width: 8),
                            Text(
                              'Navigate',
                              style: AppTypography.textTheme.bodyMedium?.copyWith(
                                // Apply theme-aware text color
                                color: isDarkMode ? Colors.white : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: AppTypography.textTheme.bodyMedium?.copyWith(
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Apply theme-aware PopupMenu styling
                    color: isDarkMode ? Colors.grey[800] : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterOptions() {
    // Get the theme provider to access the current theme mode
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      // Apply theme-aware bottom sheet styling
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add a drag handle indicator
              Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: Text(
                  'All Locations',
                  style: AppTypography.textTheme.bodyLarge?.copyWith(
                    // Apply theme-aware text color
                    color: isDarkMode ? Colors.white : null,
                  ),
                ),
                leading: Icon(
                  Icons.list,
                  // Apply theme-aware icon color
                  color: isDarkMode ? Colors.white : null,
                ),
                selected: _selectedCategory == null,
                // Apply theme-aware selected tile color
                selectedTileColor: isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                selectedColor: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _filterByCategory(null);
                },
              ),
              // Generate filter options dynamically from categories
              ...locationCategories.entries.map((entry) {
                final key = entry.key;
                final data = entry.value;
                return ListTile(
                  title: Text(
                    data['displayName'],
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      // Apply theme-aware text color
                      color: isDarkMode ? Colors.white : null,
                    ),
                  ),
                  leading: Icon(data['icon'], color: data['color']),
                  selected: _selectedCategory == key,
                  // Apply theme-aware selected tile color
                  selectedTileColor: isDarkMode ? Colors.blue.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  selectedColor: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _filterByCategory(key);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(SavedMap location, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Saved Location?',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            // Apply theme-aware text color
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${location.name}" from your saved locations?',
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            // Apply theme-aware text color
            color: isDarkMode ? Colors.white : null,
          ),
        ),
        // Apply theme-aware dialog styling
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                // Apply theme-aware text color
                color: isDarkMode ? Colors.grey[400] : null,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLocation(location);
            },
            child: Text(
              'DELETE',
              style: AppTypography.textTheme.labelLarge?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _viewOnMap(SavedMap location) {
    _handleLocationInteraction(location);
  }

  void _navigateToLocation(SavedMap location) {
    _handleLocationInteraction(location, startNavigation: true);
  }
}