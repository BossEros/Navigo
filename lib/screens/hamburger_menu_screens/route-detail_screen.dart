import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import 'package:project_navigo/models/route_history.dart';

class RouteDetailScreen extends StatefulWidget {
  final RouteHistory route;

  const RouteDetailScreen({Key? key, required this.route}) : super(key: key);

  @override
  _RouteDetailScreenState createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _setupMapData();
  }

  void _setupMapData() {
    // Create markers for start and end locations
    final startMarker = Marker(
      markerId: const MarkerId('start'),
      position: LatLng(widget.route.startLocation.lat, widget.route.startLocation.lng),
      infoWindow: InfoWindow(title: 'Start: ${widget.route.startLocation.formattedAddress}'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    final endMarker = Marker(
      markerId: const MarkerId('end'),
      position: LatLng(widget.route.endLocation.lat, widget.route.endLocation.lng),
      infoWindow: InfoWindow(title: 'End: ${widget.route.endLocation.formattedAddress}'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    // Create markers for any waypoints
    List<Marker> waypointMarkers = [];
    for (int i = 0; i < widget.route.waypoints.length; i++) {
      final waypoint = widget.route.waypoints[i];
      waypointMarkers.add(
        Marker(
          markerId: MarkerId('waypoint_$i'),
          position: LatLng(waypoint.lat, waypoint.lng),
          infoWindow: InfoWindow(title: 'Waypoint ${i + 1}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );
    }

    // Set up polyline if available
    Set<Polyline> polylines = {};
    if (widget.route.polyline.isNotEmpty) {
      try {
        // Parse our custom polyline format
        List<LatLng> polylineCoordinates = _parsePolylineString(widget.route.polyline);

        if (polylineCoordinates.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: polylineCoordinates,
              color: Colors.blue,
              width: 5,
            ),
          );
          print('Successfully parsed ${polylineCoordinates.length} polyline points');
        } else {
          print('No polyline coordinates parsed from string');
        }
      } catch (e) {
        print('Error setting up polyline: $e');
      }
    }

    setState(() {
      _markers = {startMarker, endMarker, ...waypointMarkers};
      _polylines = polylines;
      _isMapReady = true;
    });
  }

  List<LatLng> _parsePolylineString(String polylineStr) {
    List<LatLng> points = [];

    try {
      // Your database stores polylines in this format:
      // "[LatLng(10.2945, 124.0006), LatLng(10.2949, 124.00063), LatLng(10.2952, 124.00067), LatLng(10.2963, 124.00057)]"

      // Extract just the coordinate parts
      final cleanedStr = polylineStr.replaceAll("[", "").replaceAll("]", "");

      // Split by LatLng( to get individual coordinates
      final latLngs = cleanedStr.split("LatLng(");

      for (var latLng in latLngs) {
        // Skip empty strings
        if (latLng.trim().isEmpty) continue;

        // Remove trailing ")" and split by comma to get lat/lng
        final coords = latLng.replaceAll(")", "").split(",");

        if (coords.length >= 2) {
          try {
            final lat = double.parse(coords[0].trim());
            final lng = double.parse(coords[1].trim());
            points.add(LatLng(lat, lng));
          } catch (e) {
            print('Error parsing lat/lng values: $e');
          }
        }
      }
    } catch (e) {
      print('Error parsing polyline string: $e');
    }

    return points;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitMapToRoute();
  }

  void _fitMapToRoute() {
    if (_mapController == null) return;

    // Create a LatLngBounds that includes all the markers
    LatLngBounds bounds = _getBounds();

    // Fit the map to the bounds with some padding
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
  }

  LatLngBounds _getBounds() {
    // Collect all points to include in bounds
    List<LatLng> points = _markers.map((marker) => marker.position).toList();

    // Add polyline points if available
    for (var polyline in _polylines) {
      points.addAll(polyline.points);
    }

    // Find the southwest and northeast corners
    double minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    // Add a small buffer
    double latBuffer = (maxLat - minLat) * 0.1;
    double lngBuffer = (maxLng - minLng) * 0.1;

    return LatLngBounds(
      southwest: LatLng(minLat - latBuffer, minLng - lngBuffer),
      northeast: LatLng(maxLat + latBuffer, maxLng + lngBuffer),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('EEEE, MMMM d, y \'at\' h:mm a').format(dateTime);
  }

  String _formatDuration(String text) {
    // Clean up duration text if needed
    return text;
  }

  Color _getTrafficColor() {
    final trafficConditions = widget.route.trafficConditions;
    if (trafficConditions == null) return Colors.grey;

    switch (trafficConditions.toLowerCase()) {
      case 'light':
        return Colors.green;
      case 'normal':
        return Colors.amber;
      case 'heavy':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.route.routeName ?? 'Route Details',
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement sharing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Map view (taking up approximately 40% of the screen)
          SizedBox(
            height: screenHeight * 0.4,
            child: _isMapReady
                ? GoogleMap(
              initialCameraPosition: CameraPosition(
                // Default center (will be overridden by fit bounds)
                target: LatLng(
                  widget.route.startLocation.lat,
                  widget.route.startLocation.lng,
                ),
                zoom: 12,
              ),
              markers: _markers,
              polylines: _polylines,
              mapType: MapType.normal,
              onMapCreated: _onMapCreated,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )
                : const Center(child: CircularProgressIndicator()),
          ),

          // Route details (scrollable section below the map)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Date and time
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formatDateTime(widget.route.createdAt),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Info tiles: Distance, Duration, Traffic
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoTile(
                                icon: Icons.straighten,
                                label: 'Distance',
                                value: widget.route.distance.text,
                              ),
                              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
                              _buildInfoTile(
                                icon: Icons.access_time,
                                label: 'Duration',
                                value: _formatDuration(widget.route.duration.text),
                              ),
                              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
                              _buildInfoTile(
                                icon: Icons.traffic,
                                label: 'Traffic',
                                value: widget.route.trafficConditions?.capitalize() ?? 'Unknown',
                                valueColor: _getTrafficColor(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Locations Section
                  const Text(
                    'Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Start location
                  _buildLocationItem(
                    title: 'Starting Point',
                    address: widget.route.startLocation.formattedAddress,
                    iconData: Icons.trip_origin,
                    iconColor: Colors.green,
                  ),

                  // Waypoints (if any)
                  ...widget.route.waypoints.asMap().entries.map((entry) {
                    final index = entry.key;
                    final waypoint = entry.value;
                    return _buildLocationItem(
                      title: 'Waypoint ${index + 1}',
                      address: waypoint.formattedAddress.isEmpty
                          ? 'Waypoint ${index + 1}'
                          : waypoint.formattedAddress,
                      iconData: Icons.more_horiz,
                      iconColor: Colors.purple,
                    );
                  }).toList(),

                  // End location
                  _buildLocationItem(
                    title: 'Destination',
                    address: widget.route.endLocation.formattedAddress,
                    iconData: Icons.place,
                    iconColor: Colors.red,
                  ),

                  const SizedBox(height: 24),

                  // Additional information (if available)
                  if (widget.route.weatherConditions != null ||
                      widget.route.trafficConditions != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Conditions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // Traffic conditions
                        if (widget.route.trafficConditions != null)
                          _buildConditionItem(
                            title: 'Traffic',
                            value: widget.route.trafficConditions!.capitalize(),
                            iconData: Icons.traffic,
                            iconColor: _getTrafficColor(),
                          ),

                        // Weather conditions
                        if (widget.route.weatherConditions != null)
                          _buildConditionItem(
                            title: 'Weather',
                            value: widget.route.weatherConditions!,
                            iconData: Icons.cloud,
                            iconColor: Colors.blue,
                          ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Travel mode
                  Row(
                    children: [
                      Icon(
                        widget.route.travelMode == 'WALKING'
                            ? Icons.directions_walk
                            : widget.route.travelMode == 'BICYCLING'
                            ? Icons.directions_bike
                            : widget.route.travelMode == 'TRANSIT'
                            ? Icons.directions_transit
                            : Icons.directions_car,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Travel Mode: ${widget.route.travelMode.capitalize()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItem({
    required String title,
    required String address,
    required IconData iconData,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionItem({
    required String title,
    required String value,
    required IconData iconData,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Extension method to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}