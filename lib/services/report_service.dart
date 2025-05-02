import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:project_navigo/models/map_models/report_type.dart';
import 'package:project_navigo/utils/firebase_utils.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' show sin, cos, sqrt, asin, pi;



/// Service for handling user reports of road conditions, hazards, etc.
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseUtils _firebaseUtils = FirebaseUtils();

  /// Submit a new report at the given location
  Future<String> submitReport({
    required String reportTypeId,
    required LatLng location,
    String? description,
    Map<String, dynamic>? additionalData,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      // Get current user
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'anonymous';

      // Create report data
      final Map<String, dynamic> reportData = {
        'report_type': reportTypeId,
        'location': GeoPoint(location.latitude, location.longitude),
        'created_at': FieldValue.serverTimestamp(),
        'user_id': userId,
        'is_anonymous': user == null,
        'description': description,
        'status': 'active', // Initial status
        'upvotes': 0,
        'downvotes': 0,
      };

      // Add any additional data
      if (additionalData != null) {
        reportData.addAll(additionalData);
      }

      try {
        // Check if we have internet connection first
        bool isConnected = true;
        try {
          final result = await InternetAddress.lookup('google.com');
          isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } on SocketException catch (_) {
          isConnected = false;
        }

        if (!isConnected) {
          throw Exception('No internet connection. Please check your network and try again.');
        }

        // Save to Firestore with a timeout to prevent hanging
        final docRef = await _firestore
            .collection('reports')
            .add(reportData)
            .timeout(Duration(seconds: 10), onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        });

        // Return the report ID
        return docRef.id;
      } catch (e) {
        // Check if this is a permission error
        if (e is FirebaseException && e.code == 'permission-denied') {
          // If user is not logged in, suggest logging in
          if (user == null) {
            throw Exception('You need to be logged in to submit reports. Please log in and try again.');
          } else {
            // Otherwise it's a configuration issue
            throw Exception('You don\'t have permission to submit reports. This might be a configuration issue.');
          }
        }

        // Handle network connectivity issues more clearly
        if (e is SocketException ||
            e.toString().contains('network') ||
            e.toString().contains('connection')) {
          throw Exception('Network error. Please check your internet connection and try again.');
        }

        // Handle timeout
        if (e is TimeoutException) {
          throw Exception('The operation timed out. Please try again later.');
        }

        // For any other error, provide a more user-friendly message
        throw Exception('Failed to submit report: ${e.toString()}');
      }
    }, 'submitReport');
  }

  /// Get reports within a specified radius around a location
  Future<List<QueryDocumentSnapshot>> getNearbyReports({
    required LatLng center,
    double radiusKm = 5.0, // Default 5km radius
    int limit = 50,
  }) async {
    return _firebaseUtils.safeOperation(() async {
      // Get reports sorted by recency
      final querySnapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'active') // Only active reports
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      // Filter by distance
      // Note: This is a simple filtering approach. For production,
      // consider using Firestore's GeoPoint queries or a separate
      // geo-querying service for better performance and scalability.
      List<QueryDocumentSnapshot> nearbyReports = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final GeoPoint reportLocation = data['location'] as GeoPoint;

        // Calculate distance between report and center
        final double distanceKm = _calculateDistance(
          center.latitude,
          center.longitude,
          reportLocation.latitude,
          reportLocation.longitude,
        );

        if (distanceKm <= radiusKm) {
          nearbyReports.add(doc);
        }
      }

      return nearbyReports;
    }, 'getNearbyReports');
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // in kilometers
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
            (cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
                sin(dLon / 2) * sin(dLon / 2));

    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (pi / 180);

  /// Upvote a report
  Future<void> upvoteReport(String reportId) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore
          .collection('reports')
          .doc(reportId)
          .update({'upvotes': FieldValue.increment(1)});
    }, 'upvoteReport');
  }

  /// Downvote a report
  Future<void> downvoteReport(String reportId) async {
    return _firebaseUtils.safeOperation(() async {
      await _firestore
          .collection('reports')
          .doc(reportId)
          .update({'downvotes': FieldValue.increment(1)});
    }, 'downvoteReport');
  }
}

