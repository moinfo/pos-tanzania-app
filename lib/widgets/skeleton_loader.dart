import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Reusable skeleton loader widget for lazy loading placeholders
/// Provides shimmer animation effect for loading states
class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isDark;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: isDark
                ? Colors.white.withOpacity(value * 0.15)
                : Colors.grey.withOpacity(value * 0.3),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

/// Animated skeleton with continuous shimmer effect
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isDark;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.isDark = false,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: widget.isDark
                ? Colors.white.withOpacity(_animation.value * 0.15)
                : Colors.grey.withOpacity(_animation.value * 0.3),
          ),
        );
      },
    );
  }
}

/// Skeleton for list items (common pattern)
class SkeletonListItem extends StatelessWidget {
  final bool isDark;
  final bool hasLeadingCircle;
  final bool hasTrailingIcon;
  final double? height;

  const SkeletonListItem({
    super.key,
    this.isDark = false,
    this.hasLeadingCircle = true,
    this.hasTrailingIcon = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (hasLeadingCircle) ...[
            SkeletonLoader(
              width: 48,
              height: 48,
              borderRadius: 24,
              isDark: isDark,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: 150,
                  height: 12,
                  borderRadius: 4,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          if (hasTrailingIcon) ...[
            const SizedBox(width: 12),
            SkeletonLoader(
              width: 24,
              height: 24,
              borderRadius: 4,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton for card with title and content
class SkeletonCard extends StatelessWidget {
  final bool isDark;
  final double? height;
  final int contentLines;

  const SkeletonCard({
    super.key,
    this.isDark = false,
    this.height,
    this.contentLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          SkeletonLoader(
            width: 180,
            height: 18,
            borderRadius: 4,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          // Content lines
          ...List.generate(contentLines, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SkeletonLoader(
                width: index == contentLines - 1 ? 120 : double.infinity,
                height: 14,
                borderRadius: 4,
                isDark: isDark,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Skeleton for stat card (used in dashboards)
class SkeletonStatCard extends StatelessWidget {
  final bool isDark;

  const SkeletonStatCard({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonLoader(
                width: 80,
                height: 28,
                borderRadius: 4,
                isDark: isDark,
              ),
              SkeletonLoader(
                width: 36,
                height: 36,
                borderRadius: 8,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SkeletonLoader(
            width: 100,
            height: 14,
            borderRadius: 4,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

/// Skeleton for table row
class SkeletonTableRow extends StatelessWidget {
  final bool isDark;
  final int columns;

  const SkeletonTableRow({
    super.key,
    this.isDark = false,
    this.columns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
      ),
      child: Row(
        children: List.generate(columns, (index) {
          return Expanded(
            flex: index == 0 ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SkeletonLoader(
                width: double.infinity,
                height: 14,
                borderRadius: 4,
                isDark: isDark,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Full screen skeleton loader with customizable items
class SkeletonListView extends StatelessWidget {
  final bool isDark;
  final int itemCount;
  final Widget Function(BuildContext, int, bool)? itemBuilder;
  final bool hasHeader;
  final Widget? header;

  const SkeletonListView({
    super.key,
    this.isDark = false,
    this.itemCount = 8,
    this.itemBuilder,
    this.hasHeader = false,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: hasHeader ? itemCount + 1 : itemCount,
      itemBuilder: (context, index) {
        if (hasHeader && index == 0) {
          return header ?? _buildDefaultHeader();
        }
        final actualIndex = hasHeader ? index - 1 : index;
        if (itemBuilder != null) {
          return itemBuilder!(context, actualIndex, isDark);
        }
        return SkeletonListItem(isDark: isDark);
      },
    );
  }

  Widget _buildDefaultHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(
            width: 200,
            height: 24,
            borderRadius: 4,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          SkeletonLoader(
            width: 150,
            height: 14,
            borderRadius: 4,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

/// Skeleton for glassmorphic cards (matches app style)
class SkeletonGlassCard extends StatelessWidget {
  final bool isDark;
  final double? height;
  final Widget? child;

  const SkeletonGlassCard({
    super.key,
    this.isDark = false,
    this.height,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A1A).withOpacity(0.95)
            : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.3),
        ),
      ),
      child: child ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonLoader(
                    width: 44,
                    height: 44,
                    borderRadius: 12,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(
                          width: 140,
                          height: 16,
                          borderRadius: 4,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 6),
                        SkeletonLoader(
                          width: 100,
                          height: 12,
                          borderRadius: 4,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  SkeletonLoader(
                    width: 60,
                    height: 24,
                    borderRadius: 12,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SkeletonLoader(
                width: double.infinity,
                height: 8,
                borderRadius: 4,
                isDark: isDark,
              ),
            ],
          ),
    );
  }
}

/// Skeleton for search/filter header
class SkeletonSearchHeader extends StatelessWidget {
  final bool isDark;
  final bool hasFilter;

  const SkeletonSearchHeader({
    super.key,
    this.isDark = false,
    this.hasFilter = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: SkeletonLoader(
              width: double.infinity,
              height: 48,
              borderRadius: 12,
              isDark: isDark,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 12),
            SkeletonLoader(
              width: 48,
              height: 48,
              borderRadius: 12,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton for summary stats row (4 stat cards)
class SkeletonSummaryStats extends StatelessWidget {
  final bool isDark;

  const SkeletonSummaryStats({super.key, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: SkeletonStatCard(isDark: isDark)),
          const SizedBox(width: 12),
          Expanded(child: SkeletonStatCard(isDark: isDark)),
        ],
      ),
    );
  }
}
