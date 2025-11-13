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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.08),
                          ]
                        : [
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0.25),
                          ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
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
