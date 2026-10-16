import 'package:flutter/material.dart' hide Text;
import '../utils/constants.dart';
import '../widgets/tr_text.dart';

/// A navigation item for the curved bottom navigation bar
class CurvedNavItem {
  final IconData icon;
  final String label;

  const CurvedNavItem({
    required this.icon,
    required this.label,
  });
}

/// A curved bottom navigation bar with a notch for the selected item
/// Supports animation when switching between tabs
class CurvedBottomNavigation extends StatefulWidget {
  final List<CurvedNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? backgroundColor;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final Color? borderColor;

  /// Colour of the disc the selected icon sits on (white by default).
  final Color? selectedBadgeColor;

  const CurvedBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.borderColor,
    this.selectedBadgeColor,
  });

  @override
  State<CurvedBottomNavigation> createState() => _CurvedBottomNavigationState();
}

class _CurvedBottomNavigationState extends State<CurvedBottomNavigation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  double _currentRotationOffset = 0;
  bool _initialPositionSet = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CurvedBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _animateToIndex(widget.currentIndex);
    }
  }

  /// How many items sit left of the centred one. The right side gets the
  /// remainder, so an even count has one more on the left.
  static int _leftCount(int itemCount) =>
      (itemCount - 1) - (itemCount - 1) ~/ 2;

  void _animateToIndex(int index) {
    final itemCount = widget.items.length;
    final centerIndex = _leftCount(itemCount).toDouble();
    final targetOffset = centerIndex - index;

    _rotationAnimation = Tween<double>(
      begin: _currentRotationOffset,
      end: targetOffset,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward(from: 0).then((_) {
      _currentRotationOffset = targetOffset;
    });
  }

  /// Height of the bar itself (the strip the items sit in).
  static const double _barHeight = 64;

  /// How far the selected disc rises above the bar's top edge.
  static const double _discRise = 24;

  static const double _discSize = 56;
  static const double _discRing = 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same colour as the top app bar: the client's brand colour, or the dark
    // surface in dark mode.
    final bgColor = widget.backgroundColor ??
        (isDark ? AppColors.darkSurface : AppColors.brandPrimary);
    final selectedColor = widget.selectedItemColor ?? AppColors.primary;
    final unselectedColor = widget.unselectedItemColor ?? Colors.white;
    final discColor = widget.selectedBadgeColor ?? Colors.white;
    // The ring around the disc is the screen behind the bar, so the disc reads
    // as cut out of the bar's top edge.
    final ringColor = Theme.of(context).scaffoldBackgroundColor;

    // Set initial position on first build
    if (!_initialPositionSet && widget.items.isNotEmpty) {
      _initialPositionSet = true;
      final centerIndex = _leftCount(widget.items.length).toDouble();
      _currentRotationOffset = centerIndex - widget.currentIndex;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final rotationOffset = _animationController.isAnimating
                ? _rotationAnimation.value
                : _currentRotationOffset;

            return SizedBox(
              height: _barHeight + _discRise,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Flat bar.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _barHeight,
                    child: ColoredBox(color: bgColor),
                  ),
                  // Items: all visible, circular reorder so the selected one is
                  // always at the centre.
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final itemCount = widget.items.length;
                        final width = constraints.maxWidth;
                        // The centred item gets one ordinary slot; the rest
                        // share the two halves either side of it, so the
                        // selected disc is always exactly centred even when
                        // the item count is even.
                        final leftN = _leftCount(itemCount);
                        final rightN = itemCount - 1 - leftN;
                        final centreZone = width / itemCount;
                        final half = (width - centreZone) / 2;
                        final leftW = leftN > 0 ? half / leftN : half;
                        final rightW = rightN > 0 ? half / rightN : half;
                        final itemWidth = leftW < rightW ? leftW : rightW;

                        // Centre x of the item at ring position [p], where
                        // position leftN is the centred one.
                        double centreOf(int k) {
                          if (k < leftN) return leftW * (k + 0.5);
                          if (k == leftN) return width / 2;
                          return half + centreZone + rightW * (k - leftN - 0.5);
                        }

                        double xFor(double p) {
                          final k = p.floor();
                          final f = p - k;
                          final a = centreOf(k);
                          // Past the last slot an item slides off the right
                          // edge before it wraps round to the left.
                          final b = k + 1 < itemCount ? centreOf(k + 1) : a + rightW;
                          return a + (b - a) * f;
                        }

                        return Stack(
                          clipBehavior: Clip.none,
                          children: widget.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;

                            // Which visual slot this item is in right now.
                            double displayPosition = index + rotationOffset;
                            while (displayPosition < 0) {
                              displayPosition += itemCount;
                            }
                            while (displayPosition >= itemCount) {
                              displayPosition -= itemCount;
                            }

                            return Positioned(
                              left: xFor(displayPosition) - itemWidth / 2,
                              top: 0,
                              bottom: 0,
                              width: itemWidth,
                              child: _buildNavItem(
                                item.icon,
                                item.label,
                                index,
                                widget.currentIndex == index,
                                selectedColor,
                                unselectedColor,
                                discColor,
                                ringColor,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // System navigation inset, in the bar's colour.
        ColoredBox(
          color: bgColor,
          child: SizedBox(
            height: MediaQuery.of(context).viewPadding.bottom,
            width: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    bool isSelected,
    Color selectedColor,
    Color unselectedColor,
    Color discColor,
    Color ringColor,
  ) {
    return InkWell(
      onTap: () => widget.onTap(index),
      child: isSelected
          // Selected: icon on a white disc ringed in the screen colour, rising
          // above the bar's top edge, with its label in bold white below.
          ? Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  child: Container(
                    width: _discSize,
                    height: _discSize,
                    decoration: BoxDecoration(
                      color: discColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: _discRing),
                    ),
                    child: Icon(icon, color: selectedColor, size: 28),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: unselectedColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          // Unselected: icon with label, centred in the bar.
          : Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: unselectedColor, size: 24),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(fontSize: 11, color: unselectedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
