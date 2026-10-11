import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/client_config.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

/// The sign-in and launch screens share one look: the client's logo with no
/// background of its own, a white stroke traced around it, on a gradient drawn
/// from the logo's own colours. Both screens read it from here so the launch
/// screen and the login never drift apart.
class BrandBackdrop {
  const BrandBackdrop._();

  /// Gradient for [client], or null where the client keeps the plain light
  /// look. Sada's mark carries blue, green, yellow and orange: the cool
  /// blue-to-green run is the field, the warm tones stay in the logo itself.
  static List<Color>? gradientFor(ClientConfig? client) {
    if (client?.id == 'sada') {
      return const [
        Color(0xFF1B4F9C), // logo blue, deepened
        Color(0xFF1479B8),
        Color(0xFF14A38B), // blue-green blend from the logo's M
        Color(0xFF2DB566), // logo green
      ];
    }
    return null;
  }

  /// Decoration for a title band that used to be a flat brand-blue container:
  /// the client's gradient, left to right like the app bars, or [fallback] for
  /// a client without one.
  static BoxDecoration headerDecoration({
    required Color fallback,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    final brand = gradientFor(ApiService.currentClient);
    return BoxDecoration(
      color: brand == null ? fallback : null,
      gradient: brand == null
          ? null
          : LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: brand,
            ),
      borderRadius: borderRadius,
      boxShadow: boxShadow,
    );
  }

  static BoxDecoration decorationFor(List<Color> colors) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      );
}

/// Gives a [FloatingActionButton] the brand gradient.
///
/// A FAB cannot take a gradient, so the gradient is drawn behind it and the FAB
/// itself is made transparent and flat. Every switch is conditional on the
/// client having a gradient -- use [background] and [elevation] for the FAB's
/// own arguments -- so any other client keeps exactly the button it had.
///
///     BrandFab(
///       extended: true,
///       child: FloatingActionButton.extended(
///         backgroundColor: BrandFab.background(AppColors.primary),
///         elevation: BrandFab.elevation, ...
class BrandFab extends StatelessWidget {
  const BrandFab({super.key, required this.child, this.extended = false});

  final Widget child;

  /// `FloatingActionButton.extended` is a stadium; the plain one is a circle.
  final bool extended;

  static bool get _active =>
      BrandBackdrop.gradientFor(ApiService.currentClient) != null;

  /// [original] on a client without a gradient, transparent on one with it.
  static Color? background(Color? original) =>
      _active ? Colors.transparent : original;

  /// Flat on a gradient client (the wrapper draws the shadow), else default.
  static double? get elevation => _active ? 0 : null;

  @override
  Widget build(BuildContext context) {
    final brand = BrandBackdrop.gradientFor(ApiService.currentClient);
    if (brand == null) return child;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: extended ? const StadiumBorder() : const CircleBorder(),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: brand,
        ),
        shadows: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

/// The brand gradient behind an [AppBar], for its `flexibleSpace`.
///
/// Paints the same left-to-right strip as the main top bar. For a client with
/// no brand gradient it paints nothing, so the AppBar keeps its own colour.
class BrandAppBarBackground extends StatelessWidget {
  const BrandAppBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = BrandBackdrop.gradientFor(ApiService.currentClient);
    if (brand == null) return const SizedBox.shrink();

    // Must expand: a childless DecoratedBox sizes to its smallest, and the
    // flexibleSpace slot passes loose constraints, so it painted nothing and
    // the bar stayed flat blue.
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: brand,
          ),
        ),
      ),
    );
  }
}

/// A menu icon on a rounded gradient tile with a white glyph.
///
/// Only clients with a brand gradient get the tile; every other client keeps
/// the plain coloured icon, so [fallbackColor] is what they have always seen.
/// A [fallbackColor] other than the brand blue (a red "credits" row, an amber
/// "suspended" row) is kept as the tile's own tint so the warning still reads.
class BrandIconTile extends StatelessWidget {
  const BrandIconTile(
    this.icon, {
    super.key,
    this.fallbackColor,
    this.size = 36,
    this.iconSize = 20,
  });

  final IconData icon;
  final Color? fallbackColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final brand = BrandBackdrop.gradientFor(ApiService.currentClient);
    if (brand == null) return Icon(icon, color: fallbackColor);

    final tint = fallbackColor;
    final semantic = tint != null && tint != AppColors.brandPrimary;
    final colors = semantic ? [tint.withValues(alpha: 0.8), tint] : brand;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}

/// Puts the brand gradient around a badge as a thin border.
///
/// Wrap the finished badge. The ring is painted ON TOP of the badge's edge, so
/// the badge's own fill is untouched -- an earlier version drew the gradient
/// behind the child, and every translucent tinted fill let it show through as
/// a solid slab. Clients with no brand gradient get [child] back untouched.
/// [radius] is the badge's own corner radius, so the ring follows it.
class BrandBadgeFrame extends StatelessWidget {
  const BrandBadgeFrame({
    super.key,
    required this.child,
    this.radius = 999,
    this.width = 1.5,
  });

  final Widget child;
  final double radius;
  final double width;

  @override
  Widget build(BuildContext context) {
    final brand = BrandBackdrop.gradientFor(ApiService.currentClient);
    if (brand == null) return child;

    return CustomPaint(
      foregroundPainter: _GradientRingPainter(
        radius: radius,
        width: width,
        colors: brand,
      ),
      child: child,
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  _GradientRingPainter({
    required this.radius,
    required this.width,
    required this.colors,
  });

  final double radius;
  final double width;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    // Stroke sits inside the badge's bounds: inset by half its width.
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Offset.zero & size);
    final r = radius.clamp(0.0, rect.shortestSide / 2).toDouble();
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), paint);
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter old) =>
      old.radius != radius || old.width != width || old.colors != colors;
}

/// The client's mark with a white stroke around its shapes.
///
/// Flutter has no stroke for bitmap alpha, so the silhouette is drawn white at
/// a ring of offsets behind the real logo -- the union of those copies is the
/// outline.
class OutlinedLogo extends StatelessWidget {
  const OutlinedLogo({
    super.key,
    required this.client,
    required this.height,
    this.stroke = 4.5,
  });

  final ClientConfig? client;
  final double height;
  final double stroke;

  static const int _steps = 24;

  @override
  Widget build(BuildContext context) {
    final path = client?.id == 'leruma' || client?.logoUrl == null
        ? 'assets/images/leruma-logo.svg'
        : client!.logoUrl!;

    Widget logo() => path.toLowerCase().endsWith('.svg')
        ? SvgPicture.asset(path, height: height, fit: BoxFit.contain)
        : Image.asset(
            path,
            height: height,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          );

    return Padding(
      // Room for the stroke so it is not clipped at the logo's own bounds.
      padding: EdgeInsets.all(stroke + 1),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < _steps; i++)
            Transform.translate(
              offset: Offset.fromDirection(2 * math.pi * i / _steps, stroke),
              child: ColorFiltered(
                colorFilter:
                    const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                child: logo(),
              ),
            ),
          logo(),
        ],
      ),
    );
  }
}
