import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Saichi (SCL) logo tile exactly as the sign-in form draws it: the
/// gradient SVG in a rounded square with a white outline. Used by the top bars
/// so the mark is the same everywhere.
class SaichiLogoTile extends StatelessWidget {
  final double size;

  const SaichiLogoTile({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final border = size * 0.04 + 1;
    final radius = size * 0.27;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white, width: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - border),
        child: SvgPicture.asset(
          'assets/images/scl_logo.svg',
          width: size - border * 2,
          height: size - border * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
