import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/constants.dart';

/// The date range a list is currently showing, and the way to change it.
///
/// Every list that carries one of these defaults to TODAY, and widening the
/// range is a privilege the server grants — not something this bar decides.
/// It is given [canFilterDate] straight off the last response rather than
/// inferring it, because the server is the only thing that knows: a caller
/// without the grant has their date parameters read and discarded, so a bar
/// that offered the picker anyway would be offering a control that does
/// nothing.
///
/// It always states the range in words. The screens above it show totals, and
/// a filtered total read as a grand total is the specific mistake this is here
/// to prevent — "1,892 records" meant every record ever raised, and now means
/// every record raised in the range named right here.
class DateRangeFilterBar extends StatelessWidget {
  const DateRangeFilterBar({
    super.key,
    required this.dateFrom,
    required this.dateTo,
    required this.canFilterDate,
    required this.onChange,
    required this.onResetToToday,
    this.note,
  });

  /// 'yyyy-MM-dd', as the server applied them — not as they were asked for.
  final String? dateFrom;
  final String? dateTo;

  /// Whether this employee holds the grant that unlocks other days.
  final bool canFilterDate;

  final VoidCallback onChange;
  final VoidCallback onResetToToday;

  /// An extra line of explanation, used when part of the list is pinned to
  /// today because it is governed by a grant this employee does not hold.
  final String? note;

  static String today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool get isToday =>
      dateFrom != null && dateFrom == today() && dateTo == today();

  /// Whether the current range is anything other than the default.
  bool get isFiltered => !isToday && dateFrom != null;

  /// The range in words, for a bar that has to stay on one line on a small
  /// phone. Not a raw 'yyyy-MM-dd — yyyy-MM-dd', which reads as machinery.
  static String describe(String? from, String? to) {
    if (from == null && to == null) return 'All dates';

    final todayString = today();
    if (from == to) {
      if (from == todayString) return 'Today';
      final yesterday = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(const Duration(days: 1)));
      if (from == yesterday) return 'Yesterday';
      return _pretty(from);
    }

    // Same year on both ends is the common case; printing it twice wastes the
    // width this bar does not have.
    final left = _parse(from);
    final right = _parse(to);
    if (left != null && right != null && left.year == right.year) {
      return '${DateFormat('d MMM').format(left)} – ${_pretty(to)}';
    }
    return '${_pretty(from)} – ${_pretty(to)}';
  }

  static DateTime? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  static String _pretty(String? raw) {
    final parsed = _parse(raw);
    return parsed == null ? '—' : DateFormat('d MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.muted(context);
    final ink = AppColors.ink(context);
    final label = describe(dateFrom, dateTo);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.sunken(context),
        border: Border(
          bottom: BorderSide(color: AppColors.hairline(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canFilterDate ? Icons.event_outlined : Icons.lock_outline,
                size: 16,
                color: isFiltered ? AppColors.primary : muted,
              ),
              const SizedBox(width: 8),
              // Expanded, so a long range shortens rather than pushing the
              // buttons off the edge. This bar sits above a list that was
              // laid out carefully and must not start an overflow.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isFiltered ? AppColors.primary : ink,
                      ),
                    ),
                    if (!canFilterDate)
                      Text(
                        'You may only view today',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: muted),
                      ),
                  ],
                ),
              ),
              if (canFilterDate) ...[
                if (isFiltered)
                  _CompactButton(
                    label: 'Today',
                    icon: Icons.restart_alt,
                    onTap: onResetToToday,
                    tone: muted,
                  ),
                _CompactButton(
                  label: 'Change',
                  icon: Icons.date_range,
                  onTap: onChange,
                  tone: AppColors.primary,
                ),
              ],
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note!,
                    style: TextStyle(fontSize: 10.5, height: 1.3, color: muted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A text button narrow enough that two of them fit beside a range label on a
/// 320pt phone.
class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: tone,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// The date picker every one of these screens opens, so the bounds and the
/// wording cannot drift between them.
///
/// Returns null if the user backed out.
Future<DateTimeRange?> showListDateRangePicker(
  BuildContext context, {
  DateTimeRange? initial,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return showDateRangePicker(
    context: context,
    // The oldest request on this system is from December 2025; a picker that
    // opens on 1970 makes reaching last week a scroll through half a century.
    firstDate: DateTime(2024),
    lastDate: now,
    // Opening with today already selected shows the range being replaced. An
    // empty picker leaves the user guessing what they are currently looking
    // at, which is the thing this whole bar exists to stop.
    initialDateRange: initial ?? DateTimeRange(start: today, end: today),
    helpText: 'Select date range',
    saveText: 'Apply',
    fieldStartLabelText: 'From',
    fieldEndLabelText: 'To',
  );
}
