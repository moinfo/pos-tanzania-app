import 'package:flutter/material.dart';

class AppColors {
  // Logo colors - Red and Dark Gray (used in both themes)
  static const Color primary = Color(0xFFE63946);        // Logo red
  static const Color secondary = Color(0xFF2B2D42);      // Logo dark gray/black

  // Supporting colors derived from logo colors
  static const Color primaryLight = Color(0xFFFF6B77);   // Lighter red
  static const Color primaryDark = Color(0xFFB82833);    // Darker red
  static const Color secondaryLight = Color(0xFF464A5E);  // Lighter dark gray

  // Status colors using logo palette
  static const Color success = Color(0xFFE63946);        // Use primary red
  static const Color error = Color(0xFFB82833);          // Use darker red
  static const Color warning = Color(0xFFE63946);        // Use primary red
  static const Color info = Color(0xFF2B2D42);           // Use secondary dark gray

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8F9FA);     // Light gray background
  static const Color lightText = Color(0xFF2B2D42);           // Dark gray text
  static const Color lightTextLight = Color(0xFF6C757D);      // Medium gray
  static const Color lightDivider = Color(0xFFE9ECEF);        // Very light gray
  static const Color lightCard = Colors.white;

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF121212);      // Dark background
  static const Color darkSurface = Color(0xFF1E1E1E);         // Dark surface
  static const Color darkCard = Color(0xFF2C2C2C);            // Dark card
  static const Color darkText = Color(0xFFE0E0E0);            // Light text for dark mode
  static const Color darkTextLight = Color(0xFFB0B0B0);       // Lighter gray text
  static const Color darkDivider = Color(0xFF3A3A3A);         // Dark divider

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
