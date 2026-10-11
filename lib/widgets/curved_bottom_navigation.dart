import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'brand_backdrop.dart';

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

  const CurvedBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.backgroundColor,
    this.selectedItemColor,
    this.unselectedItemColor,
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

  void _animateToIndex(int index) {
    final itemCount = widget.items.length;
    final centerIndex = (itemCount - 1) / 2.0;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ?? (isDark ? AppColors.darkCard : Colors.white);
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final selectedColor = widget.selectedItemColor ?? AppColors.primary;

    // Same look as the main shell's bar: on a client with a brand gradient the
    // bar is filled with it and the idle items turn white.
    final brand = BrandBackdrop.gradientFor(ApiService.currentClient);
    final gradient = brand == null
        ? null
        : LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: brand,
          );
    final unselectedColor = gradient != null
        ? Colors.white
        : (widget.unselectedItemColor ?? AppColors.textLight);

    // Set initial position on first build
    if (!_initialPositionSet && widget.items.isNotEmpty) {
      _initialPositionSet = true;
      final centerIndex = (widget.items.length - 1) / 2.0;
      _currentRotationOffset = centerIndex - widget.currentIndex;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final rotationOffset = _animationController.isAnimating
            ? _rotationAnimation.value
            : _currentRotationOffset;

        final bar = SizedBox(
          height: 80,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Custom curved background - ALWAYS at center (0.5)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(double.infinity, 80),
                  painter: _CurvedNavPainter(
                    color: bgColor,
                    borderColor: gradient != null
                        ? Colors.white.withValues(alpha: 0.35)
                        : borderColor,
                    curvePosition: 0.5, // Always center
                    gradient: gradient,
                  ),
                ),
              ),
              // Navigation items - all visible, circular reorder so selected is at center
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = constraints.maxWidth;
                    final itemCount = widget.items.length;
                    final itemWidth = screenWidth / itemCount;

                    // Build items with animated positions (circular reorder)
                    return Stack(
                      children: widget.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;

                        // Calculate which visual slot this item should be in
                        double displayPosition = index + rotationOffset;

                        // Wrap around to keep all items in valid slots (0 to itemCount-1)
                        while (displayPosition < 0) {
                          displayPosition += itemCount;
                        }
                        while (displayPosition >= itemCount) {
                          displayPosition -= itemCount;
                        }

                        final xPos = displayPosition * itemWidth;

                        return Positioned(
                          left: xPos,
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

        if (gradient == null) return SafeArea(top: false, child: bar);

        // Same construction as the shell's bar: the gradient sits behind the
        // whole box (the bar, the 20px band above its curve, and the strip
        // under the system buttons), so it reads as one full-width rectangle
        // rather than a bar with the page showing through above the notch.
        return DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              bar,
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    bool isSelected,
    Color selectedColor,
    Color unselectedColor,
  ) {
    final brand = BrandBackdrop.gradientFor(ApiService.currentClient);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => widget.onTap(index),
      child: Center(
        child: isSelected
            // Selected: icon only, no label, moved up into the curve. On a
            // brand-gradient client it is ringed in red like the main bar.
            ? Transform.translate(
                offset: const Offset(0, -8),
                child: brand == null
                    ? Icon(
                        icon,
                        color: selectedColor,
                        size: 38,
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkCard : Colors.white,
                          border:
                              Border.all(color: AppColors.error, width: 2.5),
                        ),
                        child: Icon(icon, color: selectedColor, size: 28),
                      ),
              )
            // Unselected: smaller icon with label
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // On the brand gradient each idle icon sits on its own
                  // gradient tile, run the other way so it reads on the bar.
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: brand == null
                        ? null
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: brand,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1,
                            ),
                          ),
                    child: Icon(
                      icon,
                      color: unselectedColor,
                      size: brand == null ? 22 : 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: unselectedColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Custom painter for curved navigation bar with animated notch position
class _CurvedNavPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double curvePosition; // 0.0 = left edge, 1.0 = right edge

  /// When set it replaces [color] as the fill.
  final Gradient? gradient;

  _CurvedNavPainter({
    required this.color,
    required this.borderColor,
    this.curvePosition = 0.5,
    this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    if (gradient != null) {
      paint.shader = gradient!.createShader(Offset.zero & size);
    }

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    // Calculate curve center based on position
    final curveX = size.width * curvePosition;
    const curveRadius = 35.0;
    const curveDepth = 20.0;

    // Start from bottom left
    path.moveTo(0, size.height);
    // Line to top left
    path.lineTo(0, curveDepth);
    // Line to before curve
    path.lineTo(curveX - curveRadius - 10, curveDepth);
    // Curve down and around the selected item
    path.quadraticBezierTo(
      curveX - curveRadius,
      curveDepth,
      curveX - curveRadius + 5,
      curveDepth + 15,
    );
    path.arcToPoint(
      Offset(curveX + curveRadius - 5, curveDepth + 15),
      radius: const Radius.circular(30),
      clockwise: false,
    );
    path.quadraticBezierTo(
      curveX + curveRadius,
      curveDepth,
      curveX + curveRadius + 10,
      curveDepth,
    );
    // Line to top right
    path.lineTo(size.width, curveDepth);
    // Line to bottom right
    path.lineTo(size.width, size.height);
    // Close path
    path.close();

    // Draw fill
    canvas.drawPath(path, paint);

    // Draw border along the top edge only
    final borderPath = Path();
    borderPath.moveTo(0, curveDepth);
    borderPath.lineTo(curveX - curveRadius - 10, curveDepth);
    borderPath.quadraticBezierTo(
      curveX - curveRadius,
      curveDepth,
      curveX - curveRadius + 5,
      curveDepth + 15,
    );
    borderPath.arcToPoint(
      Offset(curveX + curveRadius - 5, curveDepth + 15),
      radius: const Radius.circular(30),
      clockwise: false,
    );
    borderPath.quadraticBezierTo(
      curveX + curveRadius,
      curveDepth,
      curveX + curveRadius + 10,
      curveDepth,
    );
    borderPath.lineTo(size.width, curveDepth);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedNavPainter oldDelegate) {
    return oldDelegate.curvePosition != curvePosition ||
        oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.gradient != gradient;
  }
}
