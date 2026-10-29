import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/constants.dart';

/// Shared look for Transactions/e-Wakala mode -- "Ledger chip" identity,
/// built from the mopos-design 3 handover (PART 3: E-Wakala mode).
/// Deliberately a SEPARATE design system from Lodge's "night skyline"
/// (lodge_theme.dart) and Contracts' "Road" (contracts/contract_theme.dart)
/// -- no shared base class, no shared widget names, nothing imported from
/// or into those files. Same app palette, its own motif (SIM-chip grid,
/// not arches or a road), its own card shape (left colour rail, not a full
/// border or a circle badge), its own bottom nav style (flat white bar,
/// blue pill behind the active icon). Scoped to lib/screens/transactions/
/// only.
class WakalaTheme {
  static TextStyle display({
    required double size,
    FontWeight weight = FontWeight.w700,
    double? height,
    double? letterSpacing,
    Color? color,
  }) {
    return GoogleFonts.spaceGrotesk(
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

  /// primaryLight, not amber -- the one deliberate colour difference from
  /// Lodge/Contracts' eyebrow (see the handover's mode comparison table).
  static TextStyle eyebrow() =>
      body(size: 12, height: 16, weight: FontWeight.w700, color: AppColors.primaryLight).copyWith(letterSpacing: 1.2);

  /// A flat-bottomed charcoal header with SIM-chip art and the tri-colour
  /// stripe -- every Transactions/e-Wakala screen's header in the
  /// handover. Built as a plain widget (not a stock AppBar) for the same
  /// reason Lodge/Contracts' headers are: AppBar vertically centers
  /// title+actions as one block within toolbarHeight, which reads wrong
  /// once the title is this big -- pins the icon row to the top and the
  /// eyebrow/title to the bottom instead.
  static PreferredSizeWidget appBar({
    required bool isDark,
    required String eyebrow,
    required String title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return _LedgerHeader(isDark: isDark, eyebrow: eyebrow, title: title, actions: actions, leading: leading);
  }
}

class _LedgerHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isDark;
  final String eyebrow;
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const _LedgerHeader({
    required this.isDark,
    required this.eyebrow,
    required this.title,
    this.actions,
    this.leading,
  });

  static const double _iconRowHeight = 44;
  // Sized for the worst case, not the common case: the handover's own spec
  // has titles wrap to two lines ("Customer Transactions", "Lipa Namba
  // Transactions") within the 250px max width, and both the eyebrow and
  // title now use an explicit line-height (16 and 34) matching the
  // handover exactly, so this is eyebrow(16) + title(2x34) + bottom
  // padding(16) = 100, plus a small safety margin -- same overflow lesson
  // as Lodge/Contracts' headers: pad the estimate, don't trim it to the
  // single-line minimum.
  static const double _titleBlockHeight = 104;
  static const double _stripeHeight = 4;

  @override
  Size get preferredSize => const Size.fromHeight(_iconRowHeight + _titleBlockHeight + _stripeHeight);

  @override
  Widget build(BuildContext context) {
    final headerColor = isDark ? AppColors.darkSurface : AppColors.secondary;
    // Same reasoning as Lodge/Contracts' headers: a pushed route (every
    // Transactions screen reached from the drawer) sits at the physical
    // top of the screen and needs the real status-bar inset; a
    // TransactionsShell tab embedded as a transactions-only tenant's Home
    // tab sits *inside* MainNavigation's own Scaffold, below its own bar,
    // which already consumes the status bar.
    final isStandaloneRoute = Navigator.canPop(context);
    final canPop = leading == null && isStandaloneRoute;

    return Material(
      color: headerColor,
      elevation: 0,
      child: SafeArea(
        top: isStandaloneRoute,
        bottom: false,
        child: Stack(
          children: [
            const Positioned(right: 14, bottom: _stripeHeight + 18, child: SimChipArt(width: 104)),
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(eyebrow.toUpperCase(), style: WakalaTheme.eyebrow()),
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: WakalaTheme.display(
                                  size: 30, height: 34, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: _stripeHeight,
                  child: Row(
                    children: const [
                      Expanded(child: ColoredBox(color: AppColors.primary)),
                      Expanded(child: ColoredBox(color: AppColors.warning)),
                      Expanded(child: ColoredBox(color: AppColors.success)),
                    ],
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

/// SIM-chip header art: a rounded-rect grid with an amber chip in the
/// centre cell -- the module's one repeated motif. Drawn with CustomPaint,
/// matching the handover's SVG path 1:1 (viewBox 120x90).
class SimChipArt extends StatelessWidget {
  final double width;
  const SimChipArt({super.key, this.width = 104});

  @override
  Widget build(BuildContext context) {
    final height = width * 90 / 120;
    return IgnorePointer(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _SimChipPainter(scale: width / 120)),
      ),
    );
  }
}

class _SimChipPainter extends CustomPainter {
  final double scale;
  _SimChipPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = AppColors.primaryLight.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    final rect = Rect.fromLTWH(22 * scale, 8 * scale, 80 * scale, 66 * scale);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(12 * scale)), outline);

    final grid = Paint()
      ..color = AppColors.primaryLight.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale;
    canvas.drawLine(Offset(22 * scale, 30 * scale), Offset(102 * scale, 30 * scale), grid);
    canvas.drawLine(Offset(22 * scale, 52 * scale), Offset(102 * scale, 52 * scale), grid);
    canvas.drawLine(Offset(52 * scale, 8 * scale), Offset(52 * scale, 74 * scale), grid);
    canvas.drawLine(Offset(72 * scale, 8 * scale), Offset(72 * scale, 74 * scale), grid);

    final chipRect = Rect.fromLTWH(52 * scale, 30 * scale, 20 * scale, 22 * scale);
    canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect, Radius.circular(3 * scale)), Paint()..color = AppColors.warning);
  }

  @override
  bool shouldRepaint(covariant _SimChipPainter oldDelegate) => oldDelegate.scale != scale;
}

/// The module's semantic tint tokens -- rounded-square icon holders and
/// row rails both use these.
class WakalaTint {
  final Color background;
  final Color foreground;
  const WakalaTint(this.background, this.foreground);

  static const blue = WakalaTint(Color(0xFFDBEAFE), Color(0xFF1E40AF));
  static const amber = WakalaTint(Color(0xFFFEF3C7), Color(0xFF92400E));
  static const green = WakalaTint(Color(0xFFD1FAE5), Color(0xFF047857));
  static const red = WakalaTint(Color(0xFFFEE2E2), Color(0xFFB91C1C));
  static const grey = WakalaTint(Color(0xFFE9ECEF), Color(0xFF2B2D42));
}

/// 44x44 rounded-square icon holder (radius 12) -- Wakala's recurring icon
/// shape. Contrast with Lodge's arch and Contracts' circle.
class WakalaIconTile extends StatelessWidget {
  final IconData icon;
  final WakalaTint tint;
  final double size;

  const WakalaIconTile({super.key, required this.icon, this.tint = WakalaTint.blue, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint.background, borderRadius: BorderRadius.circular(size * 12 / 44)),
      child: Icon(icon, color: tint.foreground, size: size * 22 / 44),
    );
  }
}

/// The left-rail card -- white, 1px border, a 4px colour rail on the left,
/// asymmetric radius (4 16 16 4) so the rail reads as a spine. Used for
/// every list row/detail card in this mode, in place of Lodge/Contracts'
/// fully-rounded bordered card.
class WakalaCard extends StatelessWidget {
  final Widget child;
  final Color railColor;
  final EdgeInsetsGeometry padding;

  const WakalaCard({
    super.key,
    required this.child,
    this.railColor = AppColors.primary,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: railColor),
          Expanded(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }
}

/// Plain (no rail) white panel -- used for hero/summary sections instead
/// of list rows (the handover's `.pc` class).
class WakalaPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WakalaPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Two-option segmented control (Categories|Transactions, SIM Cards|Float
/// Transactions, Deposits|Withdrawals) -- content-level, not in the
/// header. Backed by a stock TabController where the screen already uses
/// one for its TabBarView, so this is just the pill chrome.
class WakalaSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const WakalaSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkDivider : const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? (isDark ? AppColors.darkCard : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected
                      ? [BoxShadow(color: AppColors.secondary.withOpacity(0.18), blurRadius: 3, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(labels[i],
                    style: WakalaTheme.body(
                        size: 14,
                        weight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected
                            ? (isDark ? AppColors.darkText : AppColors.secondary)
                            : (isDark ? AppColors.darkTextLight : const Color(0xFF6C757D)))),
              ),
            ),
          );
        }),
      ),
    );
  }
}
