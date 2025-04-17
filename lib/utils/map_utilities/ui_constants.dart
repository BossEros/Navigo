import 'package:flutter/material.dart';

class UiConstants {
  // Panel heights
  static const double searchPanelMinHeight = 100.0;
  static const double searchPanelMaxHeight = 0.9; // 90% of screen height
  static const double routePanelMinHeight = 80.0;
  static const double routePanelMaxHeight = 0.6; // 60% of screen height

  // Animation durations
  static const Duration standardAnimationDuration = Duration(milliseconds: 300);
  static const Duration quickAnimationDuration = Duration(milliseconds: 150);

  // Map constants
  static const double defaultZoom = 15.0;
  static const double navigationZoom = 17.5;
  static const double navigationTilt = 45.0;

  // UI spaces
  static const double standardPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Button sizes
  static const double mapButtonSize = 48.0;
  static const double quickAccessButtonSize = 80.0;
  static const double markerSize = 40.0;

  // Border radius
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;

  // Shadow values
  static BoxShadow standardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 10,
    spreadRadius: 2,
  );

  static BoxShadow lightShadow = BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 4,
    spreadRadius: 1,
    offset: const Offset(0, 2),
  );
}