import 'package:flutter/material.dart';

class AppColors {
  // Logo colors - Red and Dark Gray (used in both themes)
  static const Color primary = Color(0xFFE63946);        // Logo red
  static const Color secondary = Color(0xFF2B2D42);      // Logo dark gray/black

  // Supporting colors derived from logo colors
  static const Color primaryLight = Color(0xFFFF6B77);   // Lighter red
  static const Color primaryDark = Color(0xFFB82833);    // Darker red
  static const Color secondaryLight = Color(0xFF464A5E);  // Lighter dark gray

  // Status colors - proper semantic colors for better UI
  static const Color success = Color(0xFF10B981);        // Emerald green
  static const Color error = Color(0xFFEF4444);          // Red
  static const Color warning = Color(0xFFF59E0B);        // Amber/Orange
  static const Color info = Color(0xFF3B82F6);           // Blue

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8F9FA);     // Light gray background
  static const Color lightText = Color(0xFF2B2D42);           // Dark gray text
  static const Color lightTextLight = Color(0xFF6C757D);      // Medium gray
  static const Color lightDivider = Color(0xFFE9ECEF);        // Very light gray
  static const Color lightCard = Colors.white;

  // Dark Theme Colors - Enhanced for better contrast
  static const Color darkBackground = Color(0xFF0D0D0D);      // Deeper dark background
  static const Color darkSurface = Color(0xFF171717);         // Dark surface
  static const Color darkCard = Color(0xFF1F1F1F);            // Dark card
  static const Color darkText = Color(0xFFF5F5F5);            // Brighter text for dark mode
  static const Color darkTextLight = Color(0xFFA3A3A3);       // Subtle gray text
  static const Color darkDivider = Color(0xFF2E2E2E);         // Dark divider
  static const Color darkAccent = Color(0xFF262626);          // Accent surface for cards

  // Legacy properties for backward compatibility
  static const Color background = lightBackground;
  static const Color white = Colors.white;
  static const Color text = lightText;
  static const Color textLight = lightTextLight;
  static const Color divider = lightDivider;
}

class AppConstants {
  static const String appName = 'POS Tanzania';
  static const String dateFormat = 'yyyy-MM-dd';
  static const String displayDateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'HH:mm:ss';
}
