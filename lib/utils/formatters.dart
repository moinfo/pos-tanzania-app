import 'package:intl/intl.dart';

class Formatters {
  /// Format currency (TZS)
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount);
  }

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
