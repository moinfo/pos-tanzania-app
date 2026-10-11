import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/client_config.dart';

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

  static BoxDecoration decorationFor(List<Color> colors) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      );
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
