import 'package:flutter/material.dart';

/// Fades and slides its child in once, when first built.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const FadeSlideIn(
      {super.key,
      required this.child,
      this.duration = const Duration(milliseconds: 450)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
