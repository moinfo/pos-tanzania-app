import 'package:flutter/material.dart';

/// The range to open `showDateRangePicker` on, kept inside [lastDate].
///
/// Reports default to the whole month, so their end is often a day in the
/// future. The picker asserts (and never opens) when `initialDateRange` ends
/// after `lastDate`, so clamp what is shown without changing the range the
/// screen is actually using.
DateTimeRange pickerInitialRange(
  DateTime start,
  DateTime end,
  DateTime lastDate,
) {
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  final e = DateTime(end.year, end.month, end.day);
  final s = DateTime(start.year, start.month, start.day);
  final clampedEnd = e.isAfter(last) ? last : e;
  final clampedStart = s.isAfter(clampedEnd) ? clampedEnd : s;
  return DateTimeRange(start: clampedStart, end: clampedEnd);
}
