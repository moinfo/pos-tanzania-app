import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/constants.dart';

/// Shared look for Contracts mode -- "Road" identity, built from the
/// mopos-design 2 handover (PART 2: Contracts mode). Deliberately a
/// SEPARATE design system from Lodge's "night skyline" look
/// (lib/screens/lodge/lodge_theme.dart) -- no shared base class, no
/// shared widget names, nothing imported from or into that file. Same
/// app palette (every color here is an existing AppColors token), but
/// its own motif (winding road + wheel, not arches), its own badge shape
/// (circle, not arch), its own bottom nav style (flat white bar, not a
/// floating dark pill). Scoped to lib/screens/contracts/ only.
class ContractTheme {
  static TextStyle display({
    required double size,
    FontWeight weight = FontWeight.w700,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: weight,
      height: height != null ? height / size : null,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.w400,
    double? height,
    Color? color,
  }) {
    return GoogleFonts.publicSans(
      fontSize: size,
      fontWeight: weight,
      height: height != null ? height / size : null,
      color: color,
    );
  }

  static TextStyle eyebrow() =>
      body(size: 12, weight: FontWeight.w700, color: AppColors.warning).copyWith(letterSpacing: 1.0);

  /// A rounded-bottom header with road art, matching every Contracts
  /// screen's header in the handover. Built as a plain widget (not a
  /// stock AppBar) for the same reason Lodge's header is: AppBar
  /// vertically centers title+actions as one block within toolbarHeight,
  /// which reads wrong once the title is this big -- pins the icon row to
  /// the top and the eyebrow/title to the bottom instead.
  static PreferredSizeWidget appBar({
    required bool isDark,
    required String eyebrow,
    required String title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return _RoadHeader(isDark: isDark, eyebrow: eyebrow, title: title, actions: actions, leading: leading);
  }
}

class _RoadHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  final String eyebrow;
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const _RoadHeader({
    required this.isDark,
    required this.eyebrow,
    required this.title,
    this.actions,
    this.leading,
  });

  static const double _iconRowHeight = 44;
  static const double _titleBlockHeight = 78;

  @override
  Size get preferredSize => const Size.fromHeight(_iconRowHeight + _titleBlockHeight);

  @override
  Widget build(BuildContext context) {
    final headerColor = isDark ? AppColors.darkSurface : AppColors.primaryDark;
    // Same reasoning as Lodge's header: a pushed route (every Contracts
    // screen reached from the drawer) sits at the physical top of the
    // screen and needs the real status-bar inset; a ContractsShell tab
    // embedded as a contracts-only tenant's Home tab sits *inside*
    // MainNavigation's own Scaffold, below its 56px bar, which already
    // consumes the status bar -- adding SafeArea's inset there a second
    // time shows as a block of empty blue space above the content.
    final isStandaloneRoute = Navigator.canPop(context);
    final canPop = leading == null && isStandaloneRoute;

    return Material(
      color: headerColor,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        top: isStandaloneRoute,
        bottom: false,
        child: Stack(
          children: [
            const Positioned(right: -4, bottom: 0, child: RoadArt(width: 160)),
            Column(
              children: [
                SizedBox(
                  height: _iconRowHeight,
                  child: Row(
                    children: [
                      if (leading != null)
                        leading!
                      else if (canPop)
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.maybePop(context),
                        )
                      else
                        const SizedBox(width: 8),
                      const Spacer(),
                      if (actions != null)
                        ...actions!.map((a) => IconTheme(data: const IconThemeData(color: Colors.white), child: a)),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(eyebrow.toUpperCase(), style: ContractTheme.eyebrow()),
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ContractTheme.display(
                                size: 30, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The road-at-dusk illustration: a sun, a winding blue road with a
/// dashed centre line, and a wheel -- Contracts mode's one repeated
/// motif, same role Lodge's skyline plays there. Drawn with CustomPaint,
/// matching the handover's SVG path 1:1 (viewBox 200x110).
class RoadArt extends StatelessWidget {
  final double width;
  const RoadArt({super.key, this.width = 160});

  @override
  Widget build(BuildContext context) {
    final height = width * 110 / 200;
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _RoadArtPainter(scale: width / 200)),
      ),
    );
  }
}

class _RoadArtPainter extends CustomPainter {
  final double scale;
  _RoadArtPainter({required this.scale});

  Offset _p(double x, double y) => Offset(x * scale, y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    // The road: a single cubic-ish curve traced with quadratic beziers
    // matching "M-10 104C40 104 52 66 104 72S168 60 214 36" (two chained
    // cubics sharing a smooth tangent at (104,72)).
    final road = Path()
      ..moveTo(_p(-10, 104).dx, _p(-10, 104).dy)
      ..cubicTo(_p(40, 104).dx, _p(40, 104).dy, _p(52, 66).dx, _p(52, 66).dy, _p(104, 72).dx, _p(104, 72).dy)
      ..cubicTo(_p(156, 78).dx, _p(156, 78).dy, _p(168, 60).dx, _p(168, 60).dy, _p(214, 36).dx, _p(214, 36).dy);

    final roadPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(road, roadPaint);

    final dashPaint = Paint()
      ..color = AppColors.lightDivider.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;
    _drawDashedPath(canvas, road, dashPaint, 5 * scale, 7 * scale);

    // Sun.
    canvas.drawCircle(_p(168, 24), 10 * scale, Paint()..color = AppColors.warning);

    // Wheel: a ring + hub + cross-spokes, centred at (152, 86).
    final wheelCenter = _p(152, 86);
    final wheelPaint = Paint()
      ..color = AppColors.primaryLight.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * scale;
    canvas.drawCircle(wheelCenter, 14 * scale, wheelPaint);
    canvas.drawCircle(wheelCenter, 3 * scale, Paint()..color = AppColors.warning);
    final spokePaint = Paint()
      ..color = AppColors.primaryLight.withOpacity(0.5)
      ..strokeWidth = 1.5 * scale;
    canvas.drawLine(_p(152, 74), _p(152, 98), spokePaint);
    canvas.drawLine(_p(140, 86), _p(164, 86), spokePaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth, double dashGap) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoadArtPainter oldDelegate) => oldDelegate.scale != scale;
}

/// Contracts mode's one recurring badge shape: a plain circle (never an
/// arch) -- holds an initial, a rank number, or a status icon depending
/// on context. Contrast with Lodge's LodgeArchIcon.
class ContractCircleBadge extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final double size;
  final Border? border;

  const ContractCircleBadge({
    super.key,
    this.text,
    this.icon,
    this.background = const Color(0xFFF8F9FA),
    this.foreground = const Color(0xFF6C757D),
    this.size = 36,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle, border: border),
      child: text != null
          ? Text(text!, style: ContractTheme.display(size: size * 0.44, weight: FontWeight.w700, color: foreground))
          : Icon(icon, color: foreground, size: size * 0.5),
    );
  }
}

/// Status pill -- same shape convention as Lodge's badge, different
/// default colors: red "Behind" is the common case in this mode.
class ContractStatusBadge extends StatelessWidget {
  final String label;
  final Color dot;
  final Color background;
  final Color foreground;

  const ContractStatusBadge({
    super.key,
    required this.label,
    this.dot = AppColors.error,
    this.background = const Color(0xFFFEE2E2),
    this.foreground = const Color(0xFFB91C1C),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: ContractTheme.body(size: 12, weight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}

/// The 90-day strip -- one tick per contract day, green for paid, red for
/// unpaid, the module's signature at-a-glance visual on the Contracts
/// list card. `totalDays` is capped for the strip's own sake (a very
/// long contract would make each tick imperceptibly thin); the real
/// days/paid/unpaid figures are shown as text alongside it, not implied
/// by tick count alone.
class ContractDayStrip extends StatelessWidget {
  final int daysPaid;
  final int daysUnpaid;
  final int totalDays;
  static const int _maxTicks = 90;

  const ContractDayStrip({
    super.key,
    required this.daysPaid,
    required this.daysUnpaid,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalDays > 0 ? totalDays : (daysPaid + daysUnpaid);
    final ticks = total > _maxTicks ? _maxTicks : (total < 1 ? 1 : total);
    final paidTicks = total > 0 ? (daysPaid / total * ticks).round().clamp(0, ticks) : 0;

    return SizedBox(
      height: 14,
      child: Row(
        children: List.generate(ticks, (i) {
          final isPaid = i < paidTicks;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == ticks - 1 ? 0 : 1.5),
              decoration: BoxDecoration(
                color: isPaid ? AppColors.success : AppColors.error,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Ring gauge (Dashboard's "4/5 behind" donut) -- a plain CustomPaint arc,
/// not a package dependency.
class ContractRingGauge extends StatelessWidget {
  final int value;
  final int total;
  final double size;
  final Color color;
  final Color trackColor;

  const ContractRingGauge({
    super.key,
    required this.value,
    required this.total,
    this.size = 96,
    this.color = AppColors.error,
    this.trackColor = const Color(0xFFE9ECEF),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingGaugePainter(
          fraction: total > 0 ? (value / total).clamp(0.0, 1.0) : 0,
          color: color,
          trackColor: trackColor,
        ),
        child: Center(
          child: Text('$value/$total',
              style: ContractTheme.display(size: size * 0.23, weight: FontWeight.w700, color: AppColors.secondary)),
        ),
      ),
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;
  _RingGaugePainter({required this.fraction, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.104;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 6.2832, false, trackPaint);

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5708, 6.2832 * fraction, false, valuePaint);
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

/// Dark hero panel (Still owed on active / hero totals) -- Contracts'
/// equivalent of Lodge's LodgeHeroPanel, with road art instead of a
/// skyline.
class ContractHeroPanel extends StatelessWidget {
  final String caption;
  final String value;
  final Color valueColor;

  const ContractHeroPanel({
    super.key,
    required this.caption,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Stack(
        children: [
          const Positioned(right: 0, bottom: 0, child: RoadArt(width: 130)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(caption, style: ContractTheme.body(size: 13, color: const Color(0xFFE9ECEF))),
              Text(value,
                  style: ContractTheme.display(
                      size: 32, weight: FontWeight.w800, color: valueColor, letterSpacing: -1)),
            ],
          ),
        ],
      ),
    );
  }
}
