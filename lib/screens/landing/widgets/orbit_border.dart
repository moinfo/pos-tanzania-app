import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A small glowing bulb that travels round a rounded card's border, trailing a
/// short comet tail that lights the border behind it.
///
/// Sits on top of a card (wrap it in [IgnorePointer]); it paints nothing
/// else. All cards share one [animation] (a repeating 0..1 controller) and
/// each passes its own [phase] so neighbouring cards are not in step.
class OrbitBorder extends StatelessWidget {
  const OrbitBorder({
    super.key,
    required this.animation,
    required this.color,
    this.phase = 0,
    this.radius = 20,
    this.inset = 0.8,
    this.bulbRadius = 5.0,
    this.tailFraction = 0.24,
  });

  /// Repeating 0..1 value; one full lap per cycle.
  final Animation<double> animation;

  /// The bulb's glow and the tail's colour (the client's brand colour).
  final Color color;

  /// Offset along the lap, 0..1.
  final double phase;

  /// The card's corner radius.
  final double radius;

  /// How far inside the card's edge the bulb rides (half the border width, so
  /// it sits on the line).
  final double inset;

  final double bulbRadius;

  /// Length of the lit tail as a fraction of the whole perimeter.
  final double tailFraction;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _OrbitPainter(
          animation: animation,
          color: color,
          phase: phase,
          radius: radius,
          inset: inset,
          bulbRadius: bulbRadius,
          tailFraction: tailFraction,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.animation,
    required this.color,
    required this.phase,
    required this.radius,
    required this.inset,
    required this.bulbRadius,
    required this.tailFraction,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double phase;
  final double radius;
  final double inset;
  final double bulbRadius;
  final double tailFraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(inset),
      Radius.circular(math.max(0, radius - inset)),
    );
    final metric = (Path()..addRRect(rrect)).computeMetrics().first;
    final length = metric.length;
    final t = (animation.value + phase) % 1.0;
    final head = t * length;

    // Comet tail: short segments behind the bulb, brighter and thicker near it.
    const segments = 14;
    final tailLength = length * tailFraction;
    for (var i = segments; i >= 1; i--) {
      final f = i / segments; // 1 = far end of the tail
      final start = head - tailLength * f;
      final end = head - tailLength * (f - 1 / segments);
      final a = _segment(metric, length, start, end);
      if (a == null) continue;
      final fade = 1 - f;
      canvas.drawPath(
        a,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.8 + 3.0 * fade
          ..color = color.withValues(alpha: 0.14 + 0.80 * fade * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.8 + 2.2 * fade),
      );
    }

    final tangent = metric.getTangentForOffset(head % length);
    if (tangent == null) return;
    final c = tangent.position;

    // Outer halo, then a hot core, like a small bulb.
    canvas.drawCircle(
      c,
      bulbRadius * 3.4,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          bulbRadius * 3.4,
          [color.withValues(alpha: 0.75), color.withValues(alpha: 0)],
        ),
    );
    canvas.drawCircle(
      c,
      bulbRadius * 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bulbRadius * 0.7),
    );
    canvas.drawCircle(
      c,
      bulbRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-bulbRadius * 0.25, -bulbRadius * 0.25),
          bulbRadius * 1.1,
          [Colors.white, Color.lerp(Colors.white, color, 0.55)!],
        ),
    );
    canvas.drawCircle(
      c,
      bulbRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = color.withValues(alpha: 0.9),
    );
  }

  /// The part of the closed outline between two distances, wrapping past the
  /// start of the path.
  Path? _segment(
      ui.PathMetric metric, double length, double start, double end) {
    double wrap(double v) => ((v % length) + length) % length;
    final s = wrap(start);
    final e = wrap(end);
    if ((end - start).abs() < 0.001) return null;
    if (s <= e) return metric.extractPath(s, e);
    return metric.extractPath(s, length)
      ..addPath(metric.extractPath(0, e), Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.color != color ||
      old.phase != phase ||
      old.radius != radius ||
      old.inset != inset ||
      old.bulbRadius != bulbRadius ||
      old.tailFraction != tailFraction;
}
