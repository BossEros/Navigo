import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_navigo/screens/hamburger_menu_screens/route-detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:project_navigo/models/route_history.dart';
import 'package:project_navigo/services/route_history_service.dart';
import 'package:project_navigo/services/user_provider.dart';
import 'package:project_navigo/themes/app_typography.dart'; // Import typography styles

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
              style: AppTypography.textTheme.bodyMedium,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Route deleted',
              style: AppTypography.textTheme.bodyMedium,
            ),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Ideally, we'd restore the route here, but since the
                // route is already deleted from Firebase, we'd need to
                // re-add it, which we don't have a method for. So for
                // now, just refresh the list.
                _refreshRoutes();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting route: $e',
              style: AppTypography.textTheme.bodyMedium,
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Route History',
          style: AppTypography.textTheme.titleLarge,
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
                    style: AppTypography.textTheme.bodyMedium,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _routes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRouteHistory,
              child: Text(
                'Try Again',
                style: AppTypography.authButton,
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
            const Icon(Icons.route, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No routes yet',
              style: AppTypography.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your navigation history will appear here',
              style: AppTypography.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(
                'Refresh',
                style: AppTypography.authButton,
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
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: groupedRoutes.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == groupedRoutes.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
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
                  style: AppTypography.textTheme.headlineSmall,
                ),
              ),
              ...dateRoutes.map((route) => _buildRouteCard(route)).toList(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(RouteHistory route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
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
                      color: _getTrafficColor(route.trafficConditions).withOpacity(0.1),
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
                          style: AppTypography.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Time
                        Text(
                          _formatDate(route.createdAt),
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
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
                        _showDeleteConfirmation(route);
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
                            const Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'View Details',
                              style: AppTypography.textTheme.bodyMedium,
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
                  color: _getTrafficColor(route.trafficConditions).withOpacity(0.2),
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
                      Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        route.distance.text,
                        style: AppTypography.distanceText.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  // Duration
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        route.duration.text,
                        style: AppTypography.distanceText.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  // Traffic
                  Row(
                    children: [
                      Icon(Icons.traffic, size: 16, color: _getTrafficColor(route.trafficConditions)),
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

  void _showDeleteConfirmation(RouteHistory route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Route?',
          style: AppTypography.textTheme.titleLarge,
        ),
        content: Text(
          'This action cannot be undone.',
          style: AppTypography.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: AppTypography.textTheme.labelLarge,
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
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}