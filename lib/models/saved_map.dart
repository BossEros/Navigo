// lib/models/saved_map.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedMap {
  final String id;
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String category;
  final String? icon;
  final DateTime savedAt;
  final String? notes;

  SavedMap({
    required this.id,
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
    this.icon,
    required this.savedAt,
    this.notes,
  });

  factory SavedMap.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return SavedMap(
      id: doc.id,
      placeId: data['place_id'] ?? '',
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      category: data['category'] ?? 'favorite',
      icon: data['icon'],
      savedAt: (data['saved_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'place_id': placeId,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'category': category,
      'icon': icon,
      'saved_at': savedAt,
      'notes': notes,
    };
  }
}