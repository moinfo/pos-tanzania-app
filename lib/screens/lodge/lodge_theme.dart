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

  /// A rounded-bottom header carrying an eyebrow line + a display title
  /// over the skyline illustration, matching every Lodge screen's header
  /// in the mockups. Built as a plain widget rather than a stock `AppBar`
  /// -- `AppBar` vertically *centers* its title and actions as one block
  /// within `toolbarHeight`, which left the icons floating oddly next to
  /// an oversized title; the mockup instead pins the icon row to the top
  /// and the eyebrow/title to the bottom of the header. `big` is Board's
  /// own taller variant (the only screen whose header carries stars by
  /// default); every other screen uses the standard title size with a
  /// plain "back" leading icon.
  static PreferredSizeWidget appBar({
    required bool isDark,
    required String eyebrow,
    required String title,
    List<Widget>? actions,
    Widget? leading,
    PreferredSizeWidget? bottom,
    bool big = false,
    bool? showStars,
  }) {
    return _LodgeHeader(
      isDark: isDark,
      eyebrow: eyebrow,
      title: title,
      actions: actions,
      leading: leading,
      bottom: bottom,
      big: big,
      showStars: showStars ?? big,
    );
  }
}

class _LodgeHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  final bool big;
  final bool showStars;
  final String eyebrow;
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const _LodgeHeader({
    required this.isDark,
    required this.eyebrow,
    required this.title,
    required this.big,
    required this.showStars,
    this.actions,
    this.leading,
    this.bottom,
  });

  static const double _iconRowHeight = 52;
  double get _titleBlockHeight => big ? 92 : 76;

  @override
  Size get preferredSize =>
      Size.fromHeight(_iconRowHeight + _titleBlockHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final headerColor = isDark ? AppColors.darkSurface : AppColors.primaryDark;
    // A pushed route (every Lodge screen reached from the drawer) sits
    // right at the physical top of the screen and needs the real status-bar
    // inset. A LodgeShell tab embedded as a lodge-only tenant's Home tab
    // sits *inside* MainNavigation's own Scaffold, below its 56px bar --
    // that bar already consumes the status bar, but MediaQuery's top
    // padding is unchanged for this subtree, so blindly adding SafeArea's
    // inset here double-counts it as a chunk of empty blue space. Since
    // there's nothing to pop back to in the embedded case, canPop doubles
    // as "am I actually at the top of the screen".
    final isStandaloneRoute = Navigator.canPop(context);
    final canPop = leading == null && isStandaloneRoute;

    return Material(
      color: headerColor,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        top: isStandaloneRoute,
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: bottom != null ? bottom!.preferredSize.height : 0,
              child: LodgeSkyline(width: big ? 190 : 170, showStars: showStars),
            ),
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
                        ...actions!.map((a) => IconTheme(
                              data: const IconThemeData(color: Colors.white),
                              child: a,
                            )),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                SizedBox(
                  height: _titleBlockHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(eyebrow.toUpperCase(), style: LodgeTheme.eyebrow(isDark)),
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LodgeTheme.display(
                                  size: big ? 38 : 30,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (bottom != null) bottom!,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The decorative skyline -- amber sun, a few star dots, and a row of
/// "arch" buildings (the same doorway shape as [LodgeArchIcon], just
/// scaled up) -- used behind every Lodge header and the dark hero panels
/// (Day close's closing-cash card, Report's net-result card, etc). Drawn
/// with plain Containers, not an SVG asset, so it needs no new dependency.
class LodgeSkyline extends StatelessWidget {
  final double width;
  final bool showStars;
  final bool showBuildings;

  const LodgeSkyline({
    super.key,
    this.width = 200,
    this.showStars = true,
    this.showBuildings = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = width / 200;
    final height = width * 110 / 200;

    Widget building(double x, double w, double h, Color color) => Positioned(
          left: x * s,
          bottom: 0,
          child: Container(
            width: w * s,
            height: h * s,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(w * s / 2),
                topRight: Radius.circular(w * s / 2),
              ),
            ),
          ),
        );

    Widget dot(double x, double y) => Positioned(
          left: (x - 1.6) * s,
          top: (y - 1.6) * s,
          child: Container(
            width: 3.2 * s,
            height: 3.2 * s,
            decoration: const BoxDecoration(color: Color(0xFFE9ECEF), shape: BoxShape.circle),
          ),
        );

    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 159 * s,
              top: 9 * s,
              child: Container(
                width: 22 * s,
                height: 22 * s,
                decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
              ),
            ),
            if (showStars) ...[dot(120, 14), dot(140, 38), dot(96, 34)],
            if (showBuildings) ...[
              building(14, 56, 52, AppColors.primary.withOpacity(0.55)),
              building(60, 72, 84, AppColors.primary.withOpacity(0.85)),
              building(122, 60, 56, AppColors.primaryLight.withOpacity(0.45)),
              building(78, 36, 36, AppColors.warning),
              building(140, 24, 24, AppColors.warning),
            ],
          ],
        ),
      ),
    );
  }
}

/// The dark skyline hero panel used for a screen's one big number (Day
/// close's closing cash, Payments/Expenses' period total, Report's net
/// result): same rounded-24 dark-blue card as the header, illustration
/// tucked behind the number.
class LodgeHeroPanel extends StatelessWidget {
  final String caption;
  final String value;
  final bool showStars;
  final bool showBuildings;
  final Widget? trailing;
  final Color valueColor;

  const LodgeHeroPanel({
    super.key,
    required this.caption,
    required this.value,
    this.showStars = false,
    this.showBuildings = true,
    this.trailing,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: LodgeSkyline(width: 140, showStars: showStars, showBuildings: showBuildings),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(caption,
                        style: LodgeTheme.body(size: 13, color: const Color(0xFFE9ECEF)))),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 2),
              Text(value,
                  style: LodgeTheme.display(
                      size: 36, weight: FontWeight.w800, color: valueColor, letterSpacing: -1)),
            ],
          ),
        ],
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

  /// A soft halo ring around the badge (e.g. the amber-tint ring Board's
  /// room cards use to make the occupied icon pop) -- null for none.
  final Color? ringColor;
  final double ringWidth;

  const LodgeArchIcon({
    super.key,
    this.icon = Icons.room_service_outlined,
    this.text,
    this.background = AppColors.warning,
    this.foreground = AppColors.secondary,
    this.width = 44,
    this.height = 52,
    this.ringColor,
    this.ringWidth = 5,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
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
    if (ringColor == null) return badge;
    return Container(
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        color: ringColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(width / 2 + ringWidth),
          topRight: Radius.circular(width / 2 + ringWidth),
          bottomLeft: Radius.circular(10 + ringWidth),
          bottomRight: Radius.circular(10 + ringWidth),
        ),
      ),
      child: badge,
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
