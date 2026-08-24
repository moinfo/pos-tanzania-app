import 'package:flutter/material.dart';

import '../services/read_cache.dart';

// Re-exported so a screen that shows a CachedDataBanner needs one import, not
// two. The label and the banner are always used together.
export '../services/read_cache.dart' show describeCacheAge;
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
    required this.isDark,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final bool isDark;

  /// Omit when retrying cannot help — a permission refusal answers the same
  /// way every time, and a button that can only fail is worse than none.
  final VoidCallback? onRetry;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48,
                color: onRetry == null ? Colors.grey.shade400 : AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
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

/// A strip above a list saying the rows below are a saved copy, not live.
///
/// The shape here is the one that has produced RenderFlex overflows in this
/// app before: an icon, a long sentence and a button in a Row. The Text is
/// wrapped in Expanded so the sentence wraps instead of the row overflowing —
/// at 320px with a 12-word message it wraps to three lines and still fits.
class CachedDataBanner extends StatelessWidget {
  const CachedDataBanner({
    super.key,
    required this.fetchedAtLabel,
    required this.isDark,
    this.onRetry,
    this.noun = 'data',
  });

  /// A coarse age, e.g. "3 hours ago" — see CachedRead.describeAge.
  final String fetchedAtLabel;

  /// What is being shown, so the sentence reads naturally: "saved expenses".
  final String noun;

  final bool isDark;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: isDark ? 0.16 : 0.10),
        border: Border(
          bottom: BorderSide(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Offline — showing $noun saved $fetchedAtLabel. This is not live.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: AppColors.ink(context),
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.warning,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Offline, and this device has never loaded this screen.
///
/// Distinct on purpose from [EmptyStateView], which means "the server says
/// there is nothing". Someone who cannot tell those two apart goes looking for
/// a request that was never missing, or assumes a queue is clear when it is
/// not. This one never claims anything about what exists — only that it cannot
/// be seen from here, and what to do about it.
class OfflineEmptyView extends StatelessWidget {
  const OfflineEmptyView({
    super.key,
    required this.noun,
    required this.isDark,
    this.onRefresh,
    this.wasStale = false,
  });

  /// Plural, lowercase: "approvals", "expenses", "credit limit requests".
  final String noun;

  final bool isDark;
  final Future<void> Function()? onRefresh;

  /// True when a copy exists but is past its trust horizon, which is a
  /// different sentence: there IS something saved, it is just too old to show.
  final bool wasStale;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.cloud_off,
      title: wasStale
          ? 'Saved $noun are too old to show'
          : 'Cannot show $noun offline',
      message: wasStale
          ? 'The copy on this device is out of date and might not match what '
              'is really there. Connect to the internet to load the current $noun.'
          : 'You are offline and this device has not loaded $noun yet. '
              'Connect to the internet once and they will be saved for next time.',
      isDark: isDark,
      onRefresh: onRefresh,
    );
  }
}

/// A screen body with the "this is a saved copy" strip above it, or the body
/// untouched when [cachedAt] is null and the data is live.
///
/// The banner sits ABOVE the scrollable rather than as its first row on
/// purpose: as a row it scrolls away, and the moment a reader most needs to
/// know the list is stale is when they have scrolled to something and are
/// about to act on it.
class CachedBodyWrapper extends StatelessWidget {
  const CachedBodyWrapper({
    super.key,
    required this.cachedAt,
    required this.noun,
    required this.isDark,
    required this.child,
    this.onRetry,
  });

  /// Null means the data is live and nothing is drawn.
  final DateTime? cachedAt;

  final String noun;
  final bool isDark;
  final Widget child;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (cachedAt == null) return child;
    return Column(
      children: [
        CachedDataBanner(
          fetchedAtLabel: describeCacheAge(cachedAt!),
          noun: noun,
          isDark: isDark,
          onRetry: onRetry,
        ),
        Expanded(child: child),
      ],
    );
  }
}
