// lib/theme/app_typography.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized typography configuration for the Navigo app.
/// This ensures consistent font usage across the entire application.
///
/// Primary font: Inter - Designed for excellent screen legibility
/// Platform-specific fallbacks: SF Pro Display (iOS) and Roboto (Android)
class AppTypography {
  /// Selects the appropriate font family based on the platform
  static String get _secondaryFontFamily {
    if (kIsWeb) return 'Inter';

    if (Platform.isIOS) {
      return '.SF Pro Display'; // iOS system font
    } else {
      return 'Roboto'; // Android system font
    }
  }

  /// Base text theme using Inter font with platform-specific fallbacks
  static TextTheme get textTheme {
    return GoogleFonts.interTextTheme().copyWith(
      // Display styles
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.3,
      ),

      // Headline styles - optimized for navigation information
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.15,
        height: 1.3,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
      ),

      // Title styles - for UI components
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.05,
        height: 1.3,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
      ),

      // Body styles - optimized for readability at various sizes
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        letterSpacing: 0,
        height: 1.5, // Increased for better readability
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1, // Slightly increased for better legibility at this size
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.2, // More letter spacing for small text
        height: 1.5,
      ),

      // Label styles - for UI elements and navigation cues
      labelLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize:
        12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.25, // More spacing for small labels
        height: 1.4,
      ),
    );
  }

  /// Helper methods for specific UI elements in navigation context

  // Auth screens
  static TextStyle get authTitle => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
    height: 1.2, // Tighter for titles
  );

  static TextStyle get authSubtitle => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
    height: 1.5, // More height for better readability
    color: Colors.black54,
  );

  static TextStyle get authInputLabel => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  static TextStyle get authInputText => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    letterSpacing: 0,
    height: 1.5,
  );

  static TextStyle get authButton => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2, // Slightly increased for better button readability
    height: 1,
  );

  // Onboarding screens
  static TextStyle get onboardingTitle => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static TextStyle get onboardingDescription => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5, // Better readability for longer paragraphs
    letterSpacing: 0,
    color: Colors.black87,
  );

  static TextStyle get onboardingButton => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1,
  );

  // Navigation specific styles
  static TextStyle get navigationInstruction => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle get distanceText => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1,
  );

  static TextStyle get streetName => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2, // More letter spacing for better scanning
    height: 1.3,
  );

  // Helper for input decoration text styles
  static InputDecorationTheme get inputDecorationTheme {
    return InputDecorationTheme(
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.1,
        color: Colors.grey[400],
      ),
      errorStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.2,
        color: Colors.red[700],
      ),
      // Add other input decoration properties as needed
    );
  }
}