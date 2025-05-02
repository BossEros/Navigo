// lib/models/report_type.dart
import 'package:flutter/material.dart';

/// Model representing a report type that can be submitted by users
class ReportType {
  final String id;
  final String label;
  final IconData? icon;
  final String? imagePath;
  final Color color;
  final String? description;

  const ReportType({
    required this.id,
    required this.label,
    this.icon,
    this.imagePath,
    required this.color,
    this.description,
  }) : assert(icon != null || imagePath != null, 'Either icon or imagePath must be provided');
}

/// Predefined report types supported by the application
class ReportTypes {
  // Traffic-related reports
  static const ReportType traffic = ReportType(
    id: 'traffic',
    label: 'Traffic',
    imagePath: 'assets/icons/traffic_icon.png',
    color: Colors.orange,
    description: 'Report heavy traffic or slowdown',
  );

  static const ReportType crash = ReportType(
    id: 'crash',
    label: 'Crash',
    imagePath: 'assets/icons/crash_icon.png',
    color: Colors.red,
    description: 'Report vehicle accident or collision',
  );

  static const ReportType hazard = ReportType(
    id: 'hazard',
    label: 'Hazard',
    imagePath: 'assets/icons/warning_icon.png',
    color: Colors.amber,
    description: 'Report road hazard or dangerous condition',
  );

  static const ReportType closure = ReportType(
    id: 'closure',
    label: 'Closure',
    imagePath: 'assets/icons/road-closure_icon.png',
    color: Colors.red,
    description: 'Report closed road or lane',
  );

  static const ReportType blockedLane = ReportType(
    id: 'blocked_lane',
    label: 'Blocked lane',
    imagePath: 'assets/icons/blocked-lane_icon.png',
    color: Colors.deepOrange,
    description: 'Report partially blocked road',
  );

  static const ReportType police = ReportType(
    id: 'police',
    label: 'Police',
    imagePath: 'assets/icons/police-car_icon.png',
    color: Colors.blue,
    description: 'Report police presence',
  );

  static const ReportType badWeather = ReportType(
    id: 'bad_weather',
    label: 'Bad weather',
    imagePath: 'assets/icons/bad-weather_icon.png',
    color: Colors.blueGrey,
    description: 'Report severe weather conditions',
  );

  static const ReportType mapIssue = ReportType(
    id: 'map_issue',
    label: 'Map issue',
    icon: Icons.map,
    color: Colors.purple,
    description: 'Report incorrect map information',
  );

  // List of all available report types
  static List<ReportType> allTypes = [
    traffic,
    police,
    crash,
    hazard,
    closure,
    blockedLane,
    badWeather,
    // mapIssue removed from the list but constant kept for backward compatibility
  ];

  // Primary report types (subset of all types)
  static List<ReportType> primaryTypes = [
    traffic,
    crash,
    hazard,
    closure,
    blockedLane,
  ];
}