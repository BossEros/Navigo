import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String username;
  final String email;
  final Address homeAddress;
  final Address workAddress;
  final int age;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int schemaVersion;
  final String onboardingStatus; // Add this field

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.homeAddress,
    required this.workAddress,
    required this.age,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.schemaVersion,
    required this.onboardingStatus, // Initialize this
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return UserProfile(
      id: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      homeAddress: Address.fromMap(data['home_address'] ?? {}),
      workAddress: Address.fromMap(data['work_address'] ?? {}),
      age: data['age'] ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['is_active'] ?? true,
      schemaVersion: data['schema_version'] ?? 1,
      onboardingStatus: data['onboarding_status'] ?? 'incomplete',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'home_address': homeAddress.toMap(),
      'work_address': workAddress.toMap(),
      'age': age,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_active': isActive,
      'schema_version': schemaVersion,
      'onboarding_status': onboardingStatus,
    };
  }
}

class Address {
  final String formattedAddress;
  final double lat;
  final double lng;
  final String placeId;

  Address({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.placeId,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      formattedAddress: map['formattedAddress'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      placeId: map['placeId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'formattedAddress': formattedAddress,
      'lat': lat,
      'lng': lng,
      'placeId': placeId,
    };
  }

  // Create an empty address instance
  factory Address.empty() {
    return Address(
      formattedAddress: '',
      lat: 0.0,
      lng: 0.0,
      placeId: '',
    );
  }
}