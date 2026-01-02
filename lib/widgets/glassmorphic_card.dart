import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable glassmorphic card widget that can be used across the app
///
/// This widget creates a frosted glass effect with:
/// - Blur effect
/// - Semi-transparent background with gradient
/// - Border with opacity
/// - Support for both light and dark themes
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurStrength;
  final bool isDark;
  final Color? customColor;
  final double? width;
  final double? height;
  /// When true, uses transparent glassmorphic style (for cards on colored backgrounds like login)
  final bool onColoredBackground;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.blurStrength = 10,
    this.isDark = false,
    this.customColor,
    this.width,
    this.height,
    this.onColoredBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    // Use transparent glassmorphic style for cards on colored backgrounds
    final useGlassStyle = onColoredBackground || isDark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isDark
            ? [
                // Subtle glow effect for dark mode
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                // Inner highlight simulation
                BoxShadow(
                  color: Colors.white.withOpacity(0.02),
                  blurRadius: 1,
                  spreadRadius: 0,
                  offset: const Offset(0, -1),
                ),
              ]
            : onColoredBackground
                ? [
                    // Glassmorphic shadow for colored backgrounds
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    // Light mode - clean elevated shadow
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurStrength * 1.5, sigmaY: blurStrength * 1.5),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: customColor != null
                    ? [
                        customColor!.withOpacity(0.35),
                        customColor!.withOpacity(0.25),
                      ]
                    : isDark
                        ? [
                            // Enhanced dark mode gradient with subtle depth
                            const Color(0xFF1A1A1A).withOpacity(0.95),
                            const Color(0xFF141414).withOpacity(0.90),
                          ]
                        : onColoredBackground
                            ? [
                                // Glassmorphic transparent style for colored backgrounds
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.15),
                              ]
                            : [
                                // Light mode - clean white card for gray/white backgrounds
                                Colors.white.withOpacity(0.95),
                                const Color(0xFFFCFCFC).withOpacity(0.92),
                              ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08) // Subtle border for dark mode
                    : onColoredBackground
                        ? Colors.white.withOpacity(0.3) // Transparent border for colored backgrounds
                        : const Color(0xFFE5E7EB), // Clean gray border for light mode
                width: onColoredBackground ? 2 : 1,
              ),
            ),
            child: padding != null
                ? Padding(padding: padding!, child: child)
                : child,
          ),
        ),
      ),
    );
  }
}

/// A glassmorphic container that provides a frosted glass background
/// for content sections
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double blurStrength;
  final bool isDark;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.margin,
    this.padding = const EdgeInsets.all(16),
    this.blurStrength = 8,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: GlassmorphicCard(
        borderRadius: borderRadius,
        padding: padding,
        blurStrength: blurStrength,
        isDark: isDark,
        child: child,
      ),
    );
  }
}
