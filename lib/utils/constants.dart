import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AppColors {
  // Logo colors - Blue and Dark Gray (Moinfotech branding)
  static const Color primary = Color(0xFF1565C0);        // Logo blue
  static const Color secondary = Color(0xFF2B2D42);      // Dark gray/black

  // Supporting colors derived from logo colors
  static const Color primaryLight = Color(0xFF42A5F5);   // Lighter blue
  static const Color primaryDark = Color(0xFF0D47A1);    // Darker blue

  /// Client-aware primary color. Returns the client's brand color if set,
  /// otherwise falls back to the default blue.
  static Color get brandPrimary {
    final branding = ApiService.currentClient?.branding;
    if (branding != null && branding.primaryColor != 0xFF1565C0) {
      return Color(branding.primaryColor);
    }
    return primary;
  }

  static Color get brandPrimaryDark {
    final branding = ApiService.currentClient?.branding;
    if (branding != null && branding.primaryDarkColor != 0xFF0D47A1) {
      return Color(branding.primaryDarkColor);
    }
    return primaryDark;
  }
  static const Color secondaryLight = Color(0xFF464A5E);

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

  // ---------------------------------------------------------------------
  // Theme-resolving helpers.
  //
  // The aliases above (text, textLight, divider, background, white) are the
  // LIGHT values. Using them directly is what produced dark-on-dark text --
  // they read correctly on a white page and vanish on a black one. These
  // resolve against the theme instead, so a widget stops having to thread an
  // `isDark` bool down just to pick a colour.
  //
  //     Text(name, style: TextStyle(color: AppColors.ink(context)))
  //
  // Reach for these in new code; the isDark ternaries already in the screens
  // are equivalent and do not need rewriting wholesale.
  // ---------------------------------------------------------------------

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Page background.
  static Color ground(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  /// A card or row sitting on [ground].
  static Color surface(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;

  /// A sheet, dialog or menu -- one step above [surface].
  static Color raised(BuildContext context) =>
      isDark(context) ? darkSurface : Colors.white;

  /// A recessed strip: search bars, sticky context headers, inset blocks.
  static Color sunken(BuildContext context) =>
      isDark(context) ? darkCard : const Color(0xFFF1F5F8);

  /// Primary text.
  static Color ink(BuildContext context) =>
      isDark(context) ? darkText : lightText;

  /// Secondary text: labels, captions, timestamps.
  static Color muted(BuildContext context) =>
      isDark(context) ? darkTextLight : lightTextLight;

  /// Hairline borders and rules.
  static Color hairline(BuildContext context) =>
      isDark(context) ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8EE);

  /// The track behind a progress bar or meter.
  static Color track(BuildContext context) =>
      isDark(context) ? const Color(0x1FFFFFFF) : const Color(0xFFE9EDF1);

  /// A disabled or absent value -- greyed, but still legible in both modes.
  static Color faded(BuildContext context) =>
      isDark(context) ? const Color(0xFF6B7A88) : const Color(0xFFA8B4BF);
}

class AppConstants {
  static const String appName = 'POS Tanzania';
  static const String dateFormat = 'yyyy-MM-dd';
  static const String displayDateFormat = 'dd MMM yyyy';
  static const String timeFormat = 'HH:mm:ss';
}