import 'package:intl/intl.dart';

class Formatters {
  /// Format currency (TZS)
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount);
  }

  /// Compact form for large currency amounts, e.g. 5,100,000 -> "5.1M" --
  /// for tight spaces (small stat tiles) where the full figure gets clipped.
  static String formatCompactCurrency(double amount) {
    final abs = amount.abs();
    if (abs >= 1000000) {
      return '${_trimTrailingZero((amount / 1000000).toStringAsFixed(1))}M';
    }
    if (abs >= 1000) {
      return '${_trimTrailingZero((amount / 1000).toStringAsFixed(1))}K';
    }
    return formatCurrency(amount);
  }

  static String _trimTrailingZero(String s) =>
      s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

  /// Format date
  static String formatDate(String? date, {String format = 'dd MMM yyyy'}) {
    if (date == null || date.isEmpty) return '-';
    try {
      final dateTime = DateTime.parse(date);
      return DateFormat(format).format(dateTime);
    } catch (e) {
      return date;
    }
  }

  /// Format date for API (yyyy-MM-dd)
  static String formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Get today's date formatted for API
  static String getTodayFormatted() {
    return formatDateForApi(DateTime.now());
  }
}
