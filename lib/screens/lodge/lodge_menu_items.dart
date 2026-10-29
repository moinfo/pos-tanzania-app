import 'package:flutter/material.dart';
import '../../models/permission_model.dart';
import 'lodge_board_screen.dart';
import 'lodge_bookings_list_screen.dart';
import 'lodge_calendar_screen.dart';
import 'lodge_rooms_screen.dart';
import 'lodge_payments_screen.dart';
import 'lodge_guests_screen.dart';
import 'lodge_expenses_screen.dart';
import 'lodge_report_screen.dart';
import 'lodge_forecast_screen.dart';
import 'lodge_day_close_screen.dart';
import 'lodge_messages_screen.dart';

/// One definition of "every Lodge destination", used by the drawer's Lodge
/// section -- the single place all eleven destinations live (LodgeShell's
/// bottom nav only has room for four of them: Board, Bookings, Calendar,
/// Rooms). Matches the web's own nav (`lodge/partial_nav.php`) order.
class LodgeMenuEntry {
  final String key;
  final String label;
  final IconData icon;
  final String permissionId;
  final WidgetBuilder? builder;

  const LodgeMenuEntry({
    required this.key,
    required this.label,
    required this.icon,
    required this.permissionId,
    this.builder,
  });
}

/// Matches the web's tab order (`lodge/partial_nav.php`): Board, Bookings,
/// Payments, Guests, Messages, Calendar, Rooms, Expenses, Report, Forecast,
/// Day close.
final List<LodgeMenuEntry> lodgeMenuEntries = [
  LodgeMenuEntry(
    key: 'board',
    label: 'Board',
    icon: Icons.dashboard_outlined,
    permissionId: PermissionIds.lodge,
    builder: (_) => const LodgeBoardScreen(),
  ),
  LodgeMenuEntry(
    key: 'bookings',
    label: 'Bookings',
    icon: Icons.event_note_outlined,
    permissionId: PermissionIds.lodgeBookings,
    builder: (_) => const LodgeBookingsListScreen(),
  ),
  LodgeMenuEntry(
    key: 'payments',
    label: 'Payments',
    icon: Icons.payments_outlined,
    permissionId: PermissionIds.lodgePayments,
    builder: (_) => const LodgePaymentsScreen(),
  ),
  LodgeMenuEntry(
    key: 'guests',
    label: 'Guests',
    icon: Icons.people_outline,
    permissionId: PermissionIds.lodgeGuests,
    builder: (_) => const LodgeGuestsScreen(),
  ),
  LodgeMenuEntry(
    key: 'messages',
    label: 'Messages',
    icon: Icons.sms_outlined,
    permissionId: PermissionIds.lodgeMessages,
    builder: (_) => const LodgeMessagesScreen(),
  ),
  LodgeMenuEntry(
    key: 'calendar',
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    permissionId: PermissionIds.lodgeCalendar,
    builder: (_) => const LodgeCalendarScreen(),
  ),
  LodgeMenuEntry(
    key: 'rooms',
    label: 'Rooms',
    icon: Icons.meeting_room_outlined,
    permissionId: PermissionIds.lodgeRooms,
    builder: (_) => const LodgeRoomsScreen(),
  ),
  LodgeMenuEntry(
    key: 'expenses',
    label: 'Expenses',
    icon: Icons.receipt_long_outlined,
    permissionId: PermissionIds.lodgeExpenses,
    builder: (_) => const LodgeExpensesScreen(),
  ),
  LodgeMenuEntry(
    key: 'report',
    label: 'Report',
    icon: Icons.bar_chart_outlined,
    permissionId: PermissionIds.lodgeReports,
    builder: (_) => const LodgeReportScreen(),
  ),
  LodgeMenuEntry(
    key: 'forecast',
    label: 'Forecast',
    icon: Icons.trending_up,
    permissionId: PermissionIds.lodgeForecast,
    builder: (_) => const LodgeForecastScreen(),
  ),
  LodgeMenuEntry(
    key: 'day_close',
    label: 'Day close',
    icon: Icons.lock_clock_outlined,
    permissionId: PermissionIds.lodgeDayClose,
    builder: (_) => const LodgeDayCloseScreen(),
  ),
];

void openLodgeMenuEntry(BuildContext context, LodgeMenuEntry entry) {
  if (entry.builder == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entry.label} is coming soon')),
    );
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: entry.builder!));
}
