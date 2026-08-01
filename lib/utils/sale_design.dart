import 'dart:ui';

import 'package:flutter/material.dart';

/// Design tokens for the redesigned Sale screen.
///
/// Taken from `design_handoff_sale_screen/README.md`. They live in their own
/// class rather than in [AppColors] because the redesign is currently scoped to
/// the sale screen -- folding them into the global theme would restyle every
/// other screen. Move them into the app theme once the redesign is adopted more
/// widely.
class SaleColors {
  const SaleColors._();

  // Brand
  static const Color brand = Color(0xFF0B5FD1);
  static const Color brandPressed = Color(0xFF0A52B4);
  static const Color appBarNavy = Color(0xFF0A3F8F);

  // Blue tints
  static const Color blueTint1 = Color(0xFFE9F1FD); // selected chips
  static const Color blueTint2 = Color(0xFFF1F5FB); // soft fills
  static const Color blueTint3 = Color(0xFFEFF4FB); // qty pill fill
  static const Color blueTintPressed = Color(0xFFDEEAFA);
  static const Color blueTintPressedAlt = Color(0xFFE0EBFA);
  static const Color blueTintPressedRow = Color(0xFFE4EDFA);
  static const Color blueBorder = Color(0xFFD5E3F7);

  // Surfaces
  static const Color pageBackground = Color(0xFFF4F6F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF7F9FC);
  static const Color neutralFill = Color(0xFFF1F4F8);
  static const Color neutralFillPressed = Color(0xFFE4EAF2);

  // Borders
  static const Color border = Color(0xFFE2E8F1);
  static const Color borderFooter = Color(0xFFE6EAF0);
  static const Color borderNav = Color(0xFFEEF1F5);
  static const Color divider = Color(0xFFF1F4F8);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF7A8699);
  static const Color textFaint = Color(0xFF8A94A6);
  static const Color textFaintAlt = Color(0xFF94A0B0);

  // Icons
  static const Color iconFaint = Color(0xFFC3CBD8);
  static const Color iconFaintAlt = Color(0xFFC9D2DE);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color successPressed = Color(0xFF128040);
  static const Color successTint = Color(0xFFE7F6EE);
  static const Color danger = Color(0xFFD14343);

  // Warning / required-customer / suspend
  static const Color warning = Color(0xFFC4820E);
  static const Color warningText = Color(0xFFB4770B);
  static const Color warningBorder = Color(0xFFF1C97C);
  static const Color warningFill = Color(0xFFFFF6E7);
  static const Color warningFillSoft = Color(0xFFFFFBF3);
  static const Color warningFillPressed = Color(0xFFFDEECF);

  // Scrim behind every bottom sheet
  static const Color scrim = Color(0x730F172A); // rgba(15,23,42,.45)
}

/// Shadows from the handoff.
class SaleShadows {
  const SaleShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> resultCard = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> footer = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 18, offset: Offset(0, -6)),
  ];

  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x330F172A), blurRadius: 30, offset: Offset(0, -8)),
  ];

  static const List<BoxShadow> primaryButton = [
    BoxShadow(color: Color(0x470B5FD1), blurRadius: 14, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> successButton = [
    BoxShadow(color: Color(0x4216A34A), blurRadius: 14, offset: Offset(0, 6)),
  ];
}

/// Money and other numeric columns use tabular figures so digits line up.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];
