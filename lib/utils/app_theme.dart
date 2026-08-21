import 'package:flutter/material.dart';

import 'constants.dart';

/// The app's two themes, in one place.
///
/// They used to live inline in `main.dart`, which meant nothing else could
/// render against the real thing — and that the dark theme quietly carried
/// less configuration than the light one. It had no `textTheme` at all, so
/// every piece of body text in dark mode fell back to Material's default ink
/// rather than the palette, and neither side declared a divider, dialog,
/// sheet, snackbar, list-tile, chip or menu theme. Each screen then had to
/// re-derive those colours by hand from an `isDark` bool, which is where the
/// inconsistencies between screens came from.
///
/// Everything here is defined for BOTH modes, symmetrically. When you add a
/// component theme, add it to both.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: AppColors.lightBackground,
        surface: AppColors.lightCard,
        card: AppColors.lightCard,
        ink: AppColors.lightText,
        muted: AppColors.lightTextLight,
        divider: AppColors.lightDivider,
        appBar: AppColors.primary,
        // A field needs to read as recessed against the page. On white-on-white
        // it disappears, which is why several screens were wrapping inputs in
        // their own tinted containers.
        fieldFill: Colors.white,
        fieldBorder: AppColors.lightDivider,
        sheet: Colors.white,
        chip: const Color(0xFFEDF1F5),
        scrim: Colors.black54,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        card: AppColors.darkCard,
        ink: AppColors.darkText,
        muted: AppColors.darkTextLight,
        divider: AppColors.darkDivider,
        appBar: AppColors.darkSurface,
        fieldFill: AppColors.darkCard,
        fieldBorder: AppColors.darkDivider,
        sheet: AppColors.darkSurface,
        chip: AppColors.darkAccent,
        scrim: Colors.black87,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color card,
    required Color ink,
    required Color muted,
    required Color divider,
    required Color appBar,
    required Color fieldFill,
    required Color fieldBorder,
    required Color sheet,
    required Color chip,
    required Color scrim,
  }) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      // Kept in step with the palette so anything reading the scheme rather
      // than AppColors lands in the same place.
      surfaceContainerHighest: card,
      onSurfaceVariant: muted,
      outline: divider,
      outlineVariant: divider,
      shadow: Colors.black,
      scrim: scrim,
    );

    final text = TextTheme(
      displayLarge: TextStyle(color: ink),
      displayMedium: TextStyle(color: ink),
      displaySmall: TextStyle(color: ink),
      headlineLarge: TextStyle(color: ink),
      headlineMedium: TextStyle(color: ink),
      headlineSmall: TextStyle(color: ink),
      titleLarge: TextStyle(color: ink, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: ink, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: ink),
      bodyMedium: TextStyle(color: ink),
      // Small print is the muted role, not the ink role -- spelling that out
      // here is what stops screens hand-picking a grey.
      bodySmall: TextStyle(color: muted),
      labelLarge: TextStyle(color: ink, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: muted),
      labelSmall: TextStyle(color: muted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: IconThemeData(color: ink),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: appBar,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 2,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: ink,
        subtitleTextStyle: TextStyle(color: muted, fontSize: 13),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(color: ink, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheet,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: sheet,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: ink, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Dark snackbars on a dark page were invisible; light ones on a light
      // page likewise. Invert against the surface so it always reads.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkAccent : AppColors.secondary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.fixed,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: chip,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: ink, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        side: BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        helperStyle: TextStyle(color: muted, fontSize: 11.5),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: muted.withValues(alpha: 0.25),
          disabledForegroundColor: muted,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : muted,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        side: BorderSide(color: divider, width: 1.5),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkAccent : AppColors.secondary,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
