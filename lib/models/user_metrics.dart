import 'package:cloud_firestore/cloud_firestore.dart';

class UserMetrics {
  final String userId;
  final int totalRoutes;
  final double totalDistance;
  final List<Map<String, dynamic>> favoriteDestinations;
  final DateTime lastActive;

  UserMetrics({
    required this.userId,
    required this.totalRoutes,
    required this.totalDistance,
    required this.favoriteDestinations,
    required this.lastActive,
  });

  factory UserMetrics.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserMetrics(
      userId: doc.id,
      totalRoutes: data['totalRoutes'] ?? 0,
      totalDistance: (data['totalDistance'] ?? 0.0).toDouble(),
      favoriteDestinations: List<Map<String, dynamic>>.from(data['favoriteDestinations'] ?? []),
      lastActive: (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalRoutes': totalRoutes,
      'totalDistance': totalDistance,
      'favoriteDestinations': favoriteDestinations,
      'lastActive': FieldValue.serverTimestamp(),
    };
  }

  // Create initial empty metrics
  factory UserMetrics.initial(String userId) {
    return UserMetrics(
      userId: userId,
      totalRoutes: 0,
      totalDistance: 0.0,
      favoriteDestinations: [],
      lastActive: DateTime.now(),
    );
  }
}