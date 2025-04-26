import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_navigo/models/recent_location.dart';
import 'package:project_navigo/services/recent_locations_service.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/themes/theme_provider.dart';
import 'package:project_navigo/screens/navigo-map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchHistoryScreen extends StatefulWidget {
  const SearchHistoryScreen({Key? key}) : super(key: key);

  @override
  _SearchHistoryScreenState createState() => _SearchHistoryScreenState();
}

class _SearchHistoryScreenState extends State<SearchHistoryScreen> {
  final RecentLocationsService _locationService = RecentLocationsService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<RecentLocation> _allLocations = [];
  List<RecentLocation> _filteredLocations = [];
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _error;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 25; // Larger page size for more historical data

  @override
  void initState() {
    super.initState();
    _fetchAllSearchHistory();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _fetchAllSearchHistory() async {
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

      // We're using a higher limit to get more historical data
      final locations = await _locationService.getRecentLocations(
        limit: _pageSize,
      );

      if (locations.isNotEmpty) {
        _lastDocument = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('recent_locations')
            .orderBy('accessed_at', descending: true)
            .limit(_pageSize)
            .get()
            .then((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.last : null);
      }

      setState(() {
        _allLocations = locations;
        _filteredLocations = locations;
        _isLoading = false;
        _hasMore = locations.length == _pageSize;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading search history: $e';
        _isLoading = false;
      });
    }
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

      // Use the service to get more recent locations
      // Ideally, we'd extend the service to support pagination with a startAfterDocument parameter
      // but for now, we'll directly use Firestore

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('recent_locations')
          .orderBy('accessed_at', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;

        // Parse the documents into RecentLocation objects
        final newLocations = querySnapshot.docs
            .map((doc) => RecentLocation.fromFirestore(doc))
            .toList();

        // Add to our lists
        setState(() {
          _allLocations.addAll(newLocations);

          // Only add to filtered list if they match current filter
          if (_searchController.text.isEmpty) {
            _filteredLocations.addAll(newLocations);
          } else {
            final filter = _searchController.text.toLowerCase();
            _filteredLocations.addAll(
                newLocations.where((location) =>
                location.name.toLowerCase().contains(filter) ||
                    location.address.toLowerCase().contains(filter)
                )
            );
          }

          _isLoadingMore = false;
          _hasMore = newLocations.length == _pageSize;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Don't set error here to maintain existing data
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading more locations: $e',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: Provider.of<ThemeProvider>(context, listen: false).isDarkMode
                ? Colors.grey[800]
                : null,
          ),
        );
      }
    }
  }

  Future<void> _refreshSearchHistory() async {
    _lastDocument = null;
    await _fetchAllSearchHistory();
  }

  Future<void> _deleteLocation(RecentLocation location) async {
    try {
      await _locationService.deleteRecentLocation(location.id);

      setState(() {
        _allLocations.removeWhere((loc) => loc.id == location.id);
        _filteredLocations.removeWhere((loc) => loc.id == location.id);
      });

      if (mounted) {
        final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location removed from history',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: isDarkMode ? Colors.grey[800] : null,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Since we can't easily restore the deleted location,
                // we'll just refresh the list
                _refreshSearchHistory();
              },
              textColor: Colors.blue[200],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error removing location: $e',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: isDarkMode ? Colors.grey[800] : null,
          ),
        );
      }
    }
  }

  Future<void> _clearAllHistory() async {
    try {
      await _locationService.clearAllRecentLocations();

      setState(() {
        _allLocations = [];
        _filteredLocations = [];
      });

      if (mounted) {
        final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Search history cleared',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: isDarkMode ? Colors.grey[800] : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error clearing history: $e',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: isDarkMode ? Colors.grey[800] : null,
          ),
        );
      }
    }
  }

  void _filterLocations(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredLocations = _allLocations;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredLocations = _allLocations.where((location) =>
      location.name.toLowerCase().contains(lowerQuery) ||
          location.address.toLowerCase().contains(lowerQuery)
      ).toList();
    });
  }

  void _navigateToLocation(RecentLocation location) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MyApp(
          savedPlaceId: location.placeId,
          savedCoordinates: LatLng(location.lat, location.lng),
          savedName: location.name,
        ),
      ),
    );
  }

  String _formatAccessDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final accessDate = DateTime(date.year, date.month, date.day);

    if (accessDate == today) {
      return 'Today ${DateFormat('h:mm a').format(date)}';
    } else if (accessDate == yesterday) {
      return 'Yesterday ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, y \'at\' h:mm a').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        title: Text(
          'Search History',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _allLocations.isEmpty ? null : () {
              _showClearHistoryConfirmation(isDarkMode);
            },
          ),
        ],
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading && _allLocations.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: isDarkMode ? Colors.white70 : null,
        ),
      );
    }

    if (_error != null && _allLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: isDarkMode ? Colors.grey[500] : Colors.grey),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAllSearchHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.blueGrey[700] : Colors.blue,
              ),
              child: Text(
                'Try Again',
                style: AppTypography.authButton.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_allLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: isDarkMode ? Colors.grey[500] : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No search history',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your searched locations will appear here',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(
                'Refresh',
                style: AppTypography.authButton.copyWith(
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.blueGrey[700] : Colors.blue,
              ),
              onPressed: _refreshSearchHistory,
            ),
          ],
        ),
      );
    }

    // Group locations by date
    Map<String, List<RecentLocation>> groupedLocations = {};
    for (var location in _filteredLocations) {
      final date = _getDateGroup(location.accessedAt);
      if (!groupedLocations.containsKey(date)) {
        groupedLocations[date] = [];
      }
      groupedLocations[date]!.add(location);
    }

    return Column(
      children: [
        // Search box
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filterLocations,
            style: AppTypography.textTheme.bodyLarge?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Search your history',
              hintStyle: AppTypography.textTheme.bodyLarge?.copyWith(
                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                onPressed: () {
                  _searchController.clear();
                  _filterLocations('');
                },
              )
                  : null,
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),

        // Counter text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredLocations.length}/${_allLocations.length} locations',
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        // Locations list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshSearchHistory,
            color: isDarkMode ? Colors.blue[300] : Colors.blue,
            backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
            child: _filteredLocations.isEmpty
                ? _buildNoResultsMessage(isDarkMode)
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: groupedLocations.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == groupedLocations.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        color: isDarkMode ? Colors.white70 : null,
                      ),
                    ),
                  );
                }

                final date = groupedLocations.keys.elementAt(index);
                final dateLocations = groupedLocations[date]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        date,
                        style: AppTypography.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    ...dateLocations.map((location) => _buildLocationCard(location, isDarkMode)).toList(),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResultsMessage(bool isDarkMode) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: isDarkMode ? Colors.grey[500] : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No matches found',
                style: AppTypography.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: AppTypography.textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.clear),
                label: Text(
                  'Clear Search',
                  style: AppTypography.authButton.copyWith(
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.blueGrey[700] : Colors.blue,
                ),
                onPressed: () {
                  _searchController.clear();
                  _filterLocations('');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(RecentLocation location, bool isDarkMode) {
    IconData iconData = Icons.location_on;

    // Determine icon based on iconType if available
    if (location.iconType != null) {
      switch(location.iconType) {
        case 'restaurant':
        case 'food':
        case 'cafe':
          iconData = Icons.restaurant;
          break;
        case 'store':
        case 'shopping_mall':
        case 'supermarket':
          iconData = Icons.shopping_bag;
          break;
        case 'school':
        case 'university':
          iconData = Icons.school;
          break;
        case 'hospital':
        case 'doctor':
        case 'pharmacy':
          iconData = Icons.local_hospital;
          break;
        case 'airport':
        case 'bus_station':
        case 'train_station':
          iconData = Icons.directions_transit;
          break;
        case 'hotel':
        case 'lodging':
          iconData = Icons.hotel;
          break;
        default:
          iconData = Icons.location_on;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToLocation(location),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(isDarkMode ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  iconData,
                  color: Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),

              // Location details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location name
                    Text(
                      location.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Location address
                    Text(
                      location.address,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Last accessed time
                    Text(
                      'Last searched: ${_formatAccessDate(location.accessedAt)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  size: 20,
                ),
                onPressed: () => _showDeleteConfirmation(location, isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final accessDate = DateTime(date.year, date.month, date.day);

    if (accessDate == today) {
      return 'Today';
    } else if (accessDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(accessDate).inDays <= 7) {
      return 'This Week';
    } else if (now.difference(accessDate).inDays <= 30) {
      return 'This Month';
    } else {
      return DateFormat('MMMM yyyy').format(date);
    }
  }

  void _showDeleteConfirmation(RecentLocation location, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          'Remove Location?',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'This will remove "${location.name}" from your search history.',
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: isDarkMode ? Colors.grey[300] : Colors.black87,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLocation(location);
            },
            child: Text(
              'REMOVE',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryConfirmation(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          'Clear All History?',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'This will permanently remove all your search history. This action cannot be undone.',
          style: AppTypography.textTheme.bodyMedium?.copyWith(
            color: isDarkMode ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: isDarkMode ? Colors.grey[300] : Colors.black87,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllHistory();
            },
            child: Text(
              'CLEAR ALL',
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}