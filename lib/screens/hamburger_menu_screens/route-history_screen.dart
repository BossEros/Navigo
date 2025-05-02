import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_navigo/screens/hamburger_menu_screens/route-detail_screen.dart';
import 'package:project_navigo/models/route_history.dart';
import 'package:project_navigo/services/route_history_service.dart';
import 'package:project_navigo/themes/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/themes/theme_provider.dart';

class RouteHistoryScreen extends StatefulWidget {
  const RouteHistoryScreen({Key? key}) : super(key: key);

  @override
  _RouteHistoryScreenState createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> {
  final RouteHistoryService _routeHistoryService = RouteHistoryService();

  List<RouteHistory> _routes = [];
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _error;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchRouteHistory();
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
      _loadMoreRoutes();
    }
  }

  Future<void> _fetchRouteHistory() async {
    if (!mounted) return;

    print('========== STARTING ROUTE HISTORY FETCH ==========');

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

      final routes = await _routeHistoryService.getUserRouteHistory(
        userId: user.uid,
        limit: _pageSize,
      );

      print('ROUTES RECEIVED: ${routes.length}');
      if (routes.isNotEmpty) {
        print('FIRST ROUTE: ${routes.first.id}');
        print('DESTINATION: ${routes.first.endLocation.formattedAddress}');
        print('DATE: ${routes.first.createdAt}');
      }

      if (routes.isNotEmpty) {
        _lastDocument = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('route_history')
            .orderBy('created_at', descending: true) // Make sure this matches your DB
            .limit(_pageSize)
            .get()
            .then((snapshot) => snapshot.docs.last);
      }

      setState(() {
        _routes = routes;
        _isLoading = false;
        _hasMore = routes.length == _pageSize;

        print('========== COMPLETED ROUTE HISTORY FETCH ==========');
        print('ROUTES IN STATE: ${_routes.length}');
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading route history: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreRoutes() async {
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

      final routes = await _routeHistoryService.getUserRouteHistory(
        userId: user.uid,
        limit: _pageSize,
        startAfterDocument: _lastDocument,
      );

      if (routes.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('route_history')
            .orderBy('createdAt', descending: true)
            .startAfterDocument(_lastDocument!)
            .limit(_pageSize)
            .get();

        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
      }

      setState(() {
        _routes.addAll(routes);
        _isLoadingMore = false;
        _hasMore = routes.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // Don't set error here to maintain existing data
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading more routes: $e',
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

  Future<void> _refreshRoutes() async {
    _lastDocument = null;
    await _fetchRouteHistory();
  }

  Future<void> _deleteRoute(RouteHistory route) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _routeHistoryService.deleteRouteHistory(
        userId: user.uid,
        routeId: route.id,
      );

      setState(() {
        _routes.removeWhere((r) => r.id == route.id);
      });

      if (mounted) {
        final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Route deleted',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: isDarkMode ? Colors.grey[800] : null,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Ideally, we'd restore the route here, but since the
                // route is already deleted from Firebase, we'd need to
                // re-add it, which we don't have a method for. So for
                // now, just refresh the list.
                _refreshRoutes();
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
              'Error deleting route: $e',
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final routeDate = DateTime(date.year, date.month, date.day);

    if (routeDate == today) {
      return 'Today ${DateFormat('h:mm a').format(date)}';
    } else if (routeDate == yesterday) {
      return 'Yesterday ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, y \'at\' h:mm a').format(date);
    }
  }

  String _getTrafficColorHex(String? trafficConditions) {
    if (trafficConditions == null) return '#808080'; // Grey for unknown

    switch (trafficConditions.toLowerCase()) {
      case 'light':
        return '#4CAF50'; // Green
      case 'normal':
        return '#FFC107'; // Amber
      case 'heavy':
        return '#F44336'; // Red
      default:
        return '#808080'; // Grey for unknown
    }
  }

  Color _getTrafficColor(String? trafficConditions) {
    String hex = _getTrafficColorHex(trafficConditions);
    // Convert hex to Color
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        title: Text(
          'Your Route History',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filtering options (by date, distance, etc.)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Filtering coming soon',
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: isDarkMode ? Colors.grey[800] : null,
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading && _routes.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: isDarkMode ? Colors.white70 : null,
        ),
      );
    }

    if (_error != null && _routes.isEmpty) {
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
              onPressed: _fetchRouteHistory,
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

    if (_routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route,
              size: 64,
              color: isDarkMode ? Colors.grey[500] : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No routes yet',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.grey[400] : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your navigation history will appear here',
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
              onPressed: _refreshRoutes,
            ),
          ],
        ),
      );
    }

    // Group routes by date
    Map<String, List<RouteHistory>> groupedRoutes = {};
    for (var route in _routes) {
      final date = DateFormat('MMM d, y').format(route.createdAt);
      if (!groupedRoutes.containsKey(date)) {
        groupedRoutes[date] = [];
      }
      groupedRoutes[date]!.add(route);
    }

    return RefreshIndicator(
      onRefresh: _refreshRoutes,
      color: isDarkMode ? Colors.blue[300] : Colors.blue,
      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: groupedRoutes.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedRoutes.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(
                  color: isDarkMode ? Colors.white70 : null,
                ),
              ),
            );
          }

          final date = groupedRoutes.keys.elementAt(index);
          final dateRoutes = groupedRoutes[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  date,
                  style: AppTypography.textTheme.headlineSmall?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              ...dateRoutes.map((route) => _buildRouteCard(route, isDarkMode)).toList(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(RouteHistory route, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteDetailScreen(route: route),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route icon with traffic color
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getTrafficColor(route.trafficConditions).withOpacity(isDarkMode ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.directions_car,
                      color: _getTrafficColor(route.trafficConditions),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Route details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Route name or destination
                        Text(
                          route.routeName ?? route.endLocation.formattedAddress,
                          style: AppTypography.textTheme.titleMedium?.copyWith(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Time
                        Text(
                          _formatDate(route.createdAt),
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Options menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey,
                    ),
                    color: isDarkMode ? Colors.grey[850] : Colors.white,
                    onSelected: (value) {
                      if (value == 'delete') {
                        _showDeleteConfirmation(route, isDarkMode);
                      } else if (value == 'detail') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RouteDetailScreen(route: route),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'detail',
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'View Details',
                              style: AppTypography.textTheme.bodyMedium?.copyWith(
                                color: isDarkMode ? Colors.white : Colors.black87,
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
                  ),
                ],
              ),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                height: 4,
                decoration: BoxDecoration(
                  color: _getTrafficColor(route.trafficConditions).withOpacity(isDarkMode ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  children: [
                    // Start point indicator - FIXED: removed negative margin
                    Transform.translate(
                      offset: const Offset(-4, 0), // Use Transform instead of negative margin
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // End point indicator - FIXED: removed negative margin
                    Transform.translate(
                      offset: const Offset(4, 0), // Use Transform instead of negative margin
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Route info row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Distance
                  Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        route.distance.text,
                        style: AppTypography.distanceText.copyWith(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  // Duration
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        route.duration.text,
                        style: AppTypography.distanceText.copyWith(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  // Traffic
                  Row(
                    children: [
                      Icon(
                        Icons.traffic,
                        size: 16,
                        color: _getTrafficColor(route.trafficConditions),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        StringExtension(route.trafficConditions)?.capitalize() ?? 'Unknown',
                        style: AppTypography.distanceText.copyWith(
                          color: _getTrafficColor(route.trafficConditions),
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

  void _showDeleteConfirmation(RouteHistory route, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          'Delete Route?',
          style: AppTypography.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
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
              _deleteRoute(route);
            },
            child: Text(
              'DELETE',
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

// Extension method to capitalize first letter
extension StringExtension on String? {
  String capitalize() {
    if (this == null || this!.isEmpty) return 'Unknown';
    return "${this![0].toUpperCase()}${this!.substring(1)}";
  }
}