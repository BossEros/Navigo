import 'package:cloud_firestore/cloud_firestore.dart';

class RecentLocation {
  final String id;
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final DateTime accessedAt;
  final String? iconType; // Optional: for displaying different icons based on location type

  RecentLocation({
    required this.id,
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.accessedAt,
    this.iconType,
  });

  factory RecentLocation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return RecentLocation(
      id: doc.id,
      placeId: data['place_id'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      accessedAt: (data['accessed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      iconType: data['icon_type'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'place_id': placeId,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'accessed_at': accessedAt,
      'icon_type': iconType,
    };
  }
}