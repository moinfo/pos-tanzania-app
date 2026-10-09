import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// A wide table that scrolls sideways, with a visible track and thumb
/// underneath it plus arrow buttons at each end. Fades and slides in on
/// first build and styles the heading row for every table that uses it.
class HorizontalScrollTable extends StatefulWidget {
  final Widget child;

  const HorizontalScrollTable({super.key, required this.child});

  @override
  State<HorizontalScrollTable> createState() => _HorizontalScrollTableState();
}

class _HorizontalScrollTableState extends State<HorizontalScrollTable> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: DataTableTheme(
              data: DataTableThemeData(
                headingRowColor: WidgetStatePropertyAll(AppColors.brandPrimary.withValues(alpha: 0.08)),
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.brandPrimary,
                ),
              ),
              child: widget.child,
            ),
          ),
          const SizedBox(height: 6),
          _ScrollBar(controller: _controller),
        ],
      ),
    );
  }
}

class _ScrollBar extends StatelessWidget {
  final ScrollController controller;

  const _ScrollBar({required this.controller});

  void _scrollBy(double delta) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + delta).clamp(0.0, position.maxScrollExtent).toDouble();
    controller.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Widget _arrow(IconData icon, double delta) {
    return InkWell(
      onTap: () => _scrollBy(delta),
      child: Container(
        width: 28,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Icon(icon, size: 16, color: Colors.grey.shade700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          children: [
            _arrow(Icons.arrow_left, -160),
            const SizedBox(width: 6),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = constraints.maxWidth;
                  double viewport = 0, maxExtent = 0, offset = 0;
                  if (controller.hasClients) {
                    final position = controller.position;
                    viewport = position.viewportDimension;
                    maxExtent = position.maxScrollExtent;
                    offset = position.pixels;
                  }
                  final contentWidth = viewport + maxExtent;
                  final thumbWidth = contentWidth > 0
                      ? (trackWidth * viewport / contentWidth).clamp(40.0, trackWidth).toDouble()
                      : trackWidth;
                  final thumbLeft =
                      maxExtent > 0 ? (trackWidth - thumbWidth) * offset / maxExtent : 0.0;

                  return GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (maxExtent <= 0 || trackWidth <= thumbWidth) return;
                      _scrollBy(details.delta.dx * maxExtent / (trackWidth - thumbWidth));
                    },
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: thumbLeft,
                            width: thumbWidth,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            _arrow(Icons.arrow_right, 160),
          ],
        );
      },
    );
  }
}
