import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Model for storing quick access shortcuts in Firestore
class QuickAccessShortcutModel {
  final String id;
  final String iconPath;
  final String label;
  final double lat;
  final double lng;
  final String address;
  final String? placeId;
  final DateTime createdAt;

  QuickAccessShortcutModel({
    required this.id,
    required this.iconPath,
    required this.label,
    required this.lat,
    required this.lng,
    required this.address,
    this.placeId,
    required this.createdAt,
  });

  // For use in the UI
  LatLng get location => LatLng(lat, lng);

  factory QuickAccessShortcutModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return QuickAccessShortcutModel(
      id: doc.id,
      iconPath: data['icon_path'] ?? 'assets/icons/star_icon.png',
      label: data['label'] ?? '',
      lat: (data['lat'] ?? 0.0).toDouble(),
      lng: (data['lng'] ?? 0.0).toDouble(),
      address: data['address'] ?? '',
      placeId: data['place_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'icon_path': iconPath,
      'label': label,
      'lat': lat,
      'lng': lng,
      'address': address,
      'place_id': placeId,
      'created_at': createdAt,
    };
  }

  // Create a model from the UI class (used in navigo-map.dart)
  static QuickAccessShortcutModel fromUiShortcut(dynamic uiShortcut) {
    return QuickAccessShortcutModel(
      id: uiShortcut.id,
      iconPath: uiShortcut.iconPath,
      label: uiShortcut.label,
      lat: uiShortcut.location.latitude,
      lng: uiShortcut.location.longitude,
      address: uiShortcut.address,
      placeId: uiShortcut.placeId,
      createdAt: DateTime.now(),
    );
  }

  // Convert to UI shortcut
  dynamic toUiShortcut() {
    // Creating a map with the exact properties expected by the UI class
    return {
      'id': id,
      'iconPath': iconPath,
      'label': label,
      'location': location,
      'address': address,
      'placeId': placeId,
    };
  }
}