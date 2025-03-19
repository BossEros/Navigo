import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String username;
  final String email;
  final Address homeAddress;
  final Address workAddress;
  final int age;
  final DateTime? dateOfBirth;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final int schemaVersion;
  final String onboardingStatus;
  final String? profileImageUrl;
  final String? profileImagePath;
  final DateTime? profileImageUpdatedAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.homeAddress,
    required this.workAddress,
    required this.age,
    this.dateOfBirth,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.schemaVersion,
    required this.onboardingStatus,
    this.profileImageUrl,
    this.profileImagePath,
    this.profileImageUpdatedAt,
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
      dateOfBirth: (data['date_of_birth'] as Timestamp?)?.toDate(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['is_active'] ?? true,
      schemaVersion: data['schema_version'] ?? 1,
      onboardingStatus: data['onboarding_status'] ?? 'incomplete',
      profileImageUrl: data['profileImageUrl'],
      profileImagePath: data['profileImagePath'],
      profileImageUpdatedAt: (data['profileImageUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'home_address': homeAddress.toMap(),
      'work_address': workAddress.toMap(),
      'age': age,
      'date_of_birth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_active': isActive,
      'schema_version': schemaVersion,
      'onboarding_status': onboardingStatus,
      'profileImageUrl': profileImageUrl,
      'profileImagePath': profileImagePath,
      'profileImageUpdatedAt': profileImageUpdatedAt,
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