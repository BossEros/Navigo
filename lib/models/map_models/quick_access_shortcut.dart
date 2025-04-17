import 'package:google_maps_flutter/google_maps_flutter.dart';

class QuickAccessShortcut {
  final String id;
  final String iconPath;
  final String label;
  final LatLng location;
  final String address;
  final String? placeId;

  QuickAccessShortcut({
    required this.id,
    required this.iconPath,
    required this.label,
    required this.location,
    required this.address,
    this.placeId,
  });

  // Convert from Firebase model
  factory QuickAccessShortcut.fromModel(dynamic model) {
    return QuickAccessShortcut(
      id: model.id,
      iconPath: model.iconPath,
      label: model.label,
      location: model.location,
      address: model.address,
      placeId: model.placeId,
    );
  }

  // Create a copy with some fields modified
  QuickAccessShortcut copyWith({
    String? id,
    String? iconPath,
    String? label,
    LatLng? location,
    String? address,
    String? placeId,
  }) {
    return QuickAccessShortcut(
      id: id ?? this.id,
      iconPath: iconPath ?? this.iconPath,
      label: label ?? this.label,
      location: location ?? this.location,
      address: address ?? this.address,
      placeId: placeId ?? this.placeId,
    );
  }
}