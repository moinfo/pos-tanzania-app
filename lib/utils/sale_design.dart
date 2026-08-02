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

/// The same tokens resolved against the active theme.
///
/// [SaleColors] holds the handoff's light values as compile-time constants;
/// this reads them for light mode and substitutes dark equivalents otherwise.
/// Member names match [SaleColors] exactly, so a call site only swaps the
/// receiver.
///
/// Resolved once per build from [Theme], which MaterialApp drives from
/// ThemeProvider -- so the dark-mode toggle reaches this screen too.
class SaleTheme {
  final bool dark;

  const SaleTheme._(this.dark);

  factory SaleTheme.of(BuildContext context) =>
      SaleTheme._(Theme.of(context).brightness == Brightness.dark);

  // Brand -- unchanged; the blue carries the same meaning on either ground.
  Color get brand => SaleColors.brand;
  Color get brandPressed => SaleColors.brandPressed;
  Color get appBarNavy => dark ? const Color(0xFF10233D) : SaleColors.appBarNavy;

  // Blue tints. The pale fills glow on black, so they become a wash of the
  // brand blue instead of a near-white block.
  Color get blueTint1 => _tint(SaleColors.brand, SaleColors.blueTint1, 0.22);
  Color get blueTint2 => _tint(SaleColors.brand, SaleColors.blueTint2, 0.10);
  Color get blueTint3 => _tint(SaleColors.brand, SaleColors.blueTint3, 0.12);
  Color get blueTintPressed =>
      _tint(SaleColors.brand, SaleColors.blueTintPressed, 0.30);
  Color get blueTintPressedAlt =>
      _tint(SaleColors.brand, SaleColors.blueTintPressedAlt, 0.28);
  Color get blueTintPressedRow =>
      _tint(SaleColors.brand, SaleColors.blueTintPressedRow, 0.26);
  Color get blueBorder =>
      dark ? SaleColors.brand.withValues(alpha: 0.45) : SaleColors.blueBorder;

  // Surfaces
  Color get pageBackground =>
      dark ? const Color(0xFF0D0D0D) : SaleColors.pageBackground;
  Color get surface => dark ? const Color(0xFF1F1F1F) : SaleColors.surface;
  Color get surfaceAlt => dark ? const Color(0xFF262626) : SaleColors.surfaceAlt;
  Color get neutralFill =>
      dark ? Colors.white.withValues(alpha: 0.07) : SaleColors.neutralFill;
  Color get neutralFillPressed => dark
      ? Colors.white.withValues(alpha: 0.12)
      : SaleColors.neutralFillPressed;

  // Borders
  Color get border => _line(SaleColors.border);
  Color get borderFooter => _line(SaleColors.borderFooter);
  Color get borderNav => _line(SaleColors.borderNav);
  Color get divider => _line(SaleColors.divider);

  // Text
  Color get textPrimary =>
      dark ? const Color(0xFFF5F5F5) : SaleColors.textPrimary;
  Color get textSecondary =>
      dark ? const Color(0xFFCBD5E1) : SaleColors.textSecondary;
  Color get textMuted => dark ? const Color(0xFFA3AEBF) : SaleColors.textMuted;
  Color get textFaint => dark ? const Color(0xFF94A0B0) : SaleColors.textFaint;
  Color get textFaintAlt =>
      dark ? const Color(0xFF8A94A6) : SaleColors.textFaintAlt;

  // Icons
  Color get iconFaint =>
      dark ? Colors.white.withValues(alpha: 0.32) : SaleColors.iconFaint;
  Color get iconFaintAlt =>
      dark ? Colors.white.withValues(alpha: 0.28) : SaleColors.iconFaintAlt;

  // Status
  Color get success => SaleColors.success;
  Color get successPressed => SaleColors.successPressed;
  Color get successTint => _tint(SaleColors.success, SaleColors.successTint, 0.22);
  Color get danger => dark ? const Color(0xFFE06B5E) : SaleColors.danger;

  // Warning / required-customer / suspend
  Color get warning => SaleColors.warning;
  Color get warningText =>
      dark ? const Color(0xFFE7C176) : SaleColors.warningText;
  Color get warningBorder => dark
      ? SaleColors.warning.withValues(alpha: 0.45)
      : SaleColors.warningBorder;
  Color get warningFill => _tint(SaleColors.warning, SaleColors.warningFill, 0.18);
  Color get warningFillSoft =>
      _tint(SaleColors.warning, SaleColors.warningFillSoft, 0.10);
  Color get warningFillPressed =>
      _tint(SaleColors.warning, SaleColors.warningFillPressed, 0.26);

  Color get scrim => SaleColors.scrim;

  // Shadows. A dark drop shadow on a dark page reads as smudge, so surfaces
  // lift by colour there instead -- except the coloured button glows, which
  // still work.
  List<BoxShadow> get cardShadow => dark ? const [] : SaleShadows.card;
  List<BoxShadow> get resultCardShadow =>
      dark ? const [] : SaleShadows.resultCard;
  List<BoxShadow> get footerShadow => dark ? const [] : SaleShadows.footer;
  List<BoxShadow> get sheetShadow => dark ? const [] : SaleShadows.sheet;
  List<BoxShadow> get primaryButtonShadow => SaleShadows.primaryButton;
  List<BoxShadow> get successButtonShadow => SaleShadows.successButton;

  Color _tint(Color fg, Color lightBg, double alpha) =>
      dark ? fg.withValues(alpha: alpha) : lightBg;

  Color _line(Color lightBg) =>
      dark ? Colors.white.withValues(alpha: 0.12) : lightBg;
}

/// Money and other numeric columns use tabular figures so digits line up.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];
