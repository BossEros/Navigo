import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:project_navigo/models/saved_map.dart';
import 'package:project_navigo/services/saved-map_services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/services/app_constants.dart';

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
          SnackBar(content: Text('Error loading more locations: $e')),
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
          content: Text('Location deleted'),
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
        SnackBar(content: Text('Error deleting location: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Locations'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _savedLocations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _savedLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSavedLocations,
              child: const Text('Try Again'),
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
            const Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No saved locations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedCategory != null
                  ? 'No locations saved in this category'
                  : 'Your saved locations will appear here',
              style: const TextStyle(color: Colors.grey),
            ),
            if (_selectedCategory != null) const SizedBox(height: 16),
            if (_selectedCategory != null)
              ElevatedButton(
                onPressed: () => _filterByCategory(null),
                child: const Text('Show All Locations'),
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
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: groupedLocations.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedLocations.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ...categoryLocations.map((location) => _buildLocationCard(location)).toList(),
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

  Widget _buildLocationCard(SavedMap location) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _handleLocationInteraction(location),
        borderRadius: BorderRadius.circular(12),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location.address,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saved ${_formatDate(location.savedAt)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Options menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation(location);
                      } else if (value == 'navigate') {
                        _navigateToLocation(location);
                      } else if (value == 'view') {
                        _viewOnMap(location);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.map, size: 18),
                            SizedBox(width: 8),
                            Text('View on Map'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'navigate',
                        child: Row(
                          children: [
                            Icon(Icons.navigation, size: 18),
                            SizedBox(width: 8),
                            Text('Navigate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Locations'),
                leading: const Icon(Icons.list),
                selected: _selectedCategory == null,
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
                  title: Text(data['displayName']),
                  leading: Icon(data['icon'], color: data['color']),
                  selected: _selectedCategory == key,
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

  void _showDeleteConfirmation(SavedMap location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Saved Location?'),
        content: Text('Are you sure you want to delete "${location.name}" from your saved locations?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLocation(location);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
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