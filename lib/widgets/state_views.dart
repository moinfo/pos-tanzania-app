import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'skeleton_loader.dart';

/// The three things every list screen has to render besides its list: nothing
/// yet, something went wrong, and still loading.
///
/// These were hand-rolled in every screen, which is why the empty state on one
/// screen scrolls and the next one doesn't. Pulling them here also fixes the
/// two details that are easy to forget:
///
///   * an empty list still has to pull-to-refresh, which needs both a
///     scrollable and AlwaysScrollableScrollPhysics;
///   * it has to centre on a tall phone and a short one, which is what the
///     LayoutBuilder fraction is for rather than a fixed spacer.

/// Nothing to show — with pull-to-refresh preserved.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.isDark,
    this.message,
    this.onRefresh,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final bool isDark;

  /// Omit to render a plain centred block with no scroll behaviour, for use
  /// inside a sheet or a card.
  final Future<void> Function()? onRefresh;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;

    final body = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: isDark ? AppColors.darkTextLight : Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: muted),
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 18),
          action!,
        ],
      ],
    );

    if (onRefresh == null) {
      return Center(child: body);
    }

    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: onRefresh!,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight * 0.7, child: Center(child: body)),
          ],
        ),
      ),
    );
  }
}

/// Something failed, with a way back.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Jaribu tena'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of placeholder cards shaped like the rows that are coming.
///
/// A spinner tells the user to wait; this tells them what to expect and stops
/// the layout jumping when the data lands.
class SkeletonRowList extends StatelessWidget {
  const SkeletonRowList({
    super.key,
    required this.isDark,
    this.itemCount = 6,
    this.hasTrailingAmount = true,
  });

  final bool isDark;
  final int itemCount;
  final bool hasTrailingAmount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            SkeletonLoader(width: 28, height: 28, borderRadius: 14, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 120, height: 13, isDark: isDark),
                  const SizedBox(height: 7),
                  SkeletonLoader(width: 170, height: 11, isDark: isDark),
                ],
              ),
            ),
            if (hasTrailingAmount) ...[
              const SizedBox(width: 10),
              SkeletonLoader(width: 62, height: 15, isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }
}
