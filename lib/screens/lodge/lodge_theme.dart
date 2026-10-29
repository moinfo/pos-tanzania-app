import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/constants.dart';

/// Shared look for the Lodge module -- built from the "Mopos Lodge —
/// redesigned screens" mockups the client supplied, scoped to Lodge only
/// (the rest of the app keeps its existing plain Material look). Every
/// color used is an existing AppColors token; nothing new was invented --
/// this is a layout/typography/shape redesign, not a palette change.
///
/// Distinctive devices, each doing a job (not decoration for its own sake):
///  - Bricolage Grotesque for display numbers/headlines, paired with
///    Public Sans body text -- a display/body pairing the rest of the app
///    doesn't have, giving Lodge its own voice within the same brand colors.
///  - An "arch" badge (rounded top, flat-ish bottom, like a doorway) as the
///    one recurring icon shape for rooms/bookings/guests -- a single motif
///    repeated everywhere reads as a considered system, not a grab-bag of
///    Material icon containers.
///  - A floating pill bottom nav (AppColors.secondary ground, warning-amber
///    active pill) and a pill FAB, replacing the stock Material bar/FAB.
class LodgeTheme {
  /// Bricolage Grotesque: big numbers, screen titles, display text.
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

  /// Public Sans: everything else (labels, body copy, captions).
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

  static TextStyle eyebrow(bool isDark) => body(
        size: 12,
        weight: FontWeight.w700,
        color: AppColors.warning,
      ).copyWith(letterSpacing: 1.0);

  /// A rounded-bottom AppBar carrying an eyebrow line + a big display
  /// title, matching every Lodge screen's header in the mockups. Sits
  /// below MainNavigation's own chrome (menu/notifications/theme toggle),
  /// which this never repeats.
  static PreferredSizeWidget appBar({
    required bool isDark,
    required String eyebrow,
    required String title,
    List<Widget>? actions,
    Widget? leading,
    PreferredSizeWidget? bottom,
  }) {
    final headerColor = isDark ? AppColors.darkSurface : AppColors.primaryDark;
    return AppBar(
      backgroundColor: headerColor,
      foregroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 96,
      leading: leading,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      actions: actions,
      bottom: bottom,
      title: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow.toUpperCase(), style: LodgeTheme.eyebrow(isDark)),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LodgeTheme.display(size: 30, weight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }
}

/// The recurring "arch" icon badge: rounded top, square-ish bottom, used
/// for every room/booking/guest row so the whole module reads as one
/// system rather than ad hoc icon containers per screen.
class LodgeArchIcon extends StatelessWidget {
  final IconData icon;
  final String? text;
  final Color background;
  final Color foreground;
  final double width;
  final double height;

  const LodgeArchIcon({
    super.key,
    this.icon = Icons.bed_outlined,
    this.text,
    this.background = AppColors.warning,
    this.foreground = AppColors.secondary,
    this.width = 44,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(width / 2),
          topRight: Radius.circular(width / 2),
          bottomLeft: const Radius.circular(10),
          bottomRight: const Radius.circular(10),
        ),
      ),
      child: text != null
          ? Text(text!,
              style: LodgeTheme.display(size: 15, weight: FontWeight.w700, color: foreground))
          : Icon(icon, color: foreground, size: 22),
    );
  }
}

/// Amber status pill -- "Occupied"/"Checked in" read warmer (welcoming)
/// than a hard red/blue badge would on a hospitality screen.
class LodgeStatusBadge extends StatelessWidget {
  final String label;
  final Color dot;
  final Color background;
  final Color foreground;

  const LodgeStatusBadge({
    super.key,
    required this.label,
    this.dot = AppColors.warning,
    this.background = const Color(0xFFFEF3C7),
    this.foreground = const Color(0xFF92400E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: LodgeTheme.body(size: 12, weight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}

/// Pill FAB in warning-amber with dark text, matching the mockups --
/// deliberately not Flutter's stock FloatingActionButton (round, brand
/// blue), and never uses a Hero (sidesteps the duplicate-tag crash that
/// hit the stock FABs in LodgeShell's IndexedStack tabs).
class LodgeFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const LodgeFab({super.key, required this.onPressed, this.label = 'Booking', this.icon = Icons.add});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning,
      borderRadius: BorderRadius.circular(999),
      elevation: 6,
      shadowColor: AppColors.primaryDark.withOpacity(0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 22, 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(label, style: LodgeTheme.body(size: 15, weight: FontWeight.w700, color: AppColors.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}
