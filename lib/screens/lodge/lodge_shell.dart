import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import 'lodge_board_screen.dart';
import 'lodge_bookings_list_screen.dart';
import 'lodge_calendar_screen.dart';
import 'lodge_rooms_screen.dart';
import 'lodge_more_screen.dart';

/// Holds the Lodge module's own bottom navigation -- same pattern as
/// ProductionShell, capped at the handful of destinations that matter most
/// on a phone (Board, Bookings, Calendar, Rooms); everything else (Payments,
/// Guests, Expenses, Report, Forecast, Day close, Messages) lives behind
/// "More", which lists the same destinations as the drawer's Lodge section.
class LodgeShell extends StatefulWidget {
  final int initialIndex;

  const LodgeShell({super.key, this.initialIndex = 0});

  @override
  State<LodgeShell> createState() => _LodgeShellState();
}

class _LodgeShellState extends State<LodgeShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();

    final destinations = <_Destination>[
      const _Destination('Board', Icons.dashboard_outlined, LodgeBoardScreen()),
      if (permissions.hasPermission(PermissionIds.lodgeBookings))
        const _Destination('Bookings', Icons.event_note_outlined, LodgeBookingsListScreen()),
      if (permissions.hasPermission(PermissionIds.lodgeCalendar))
        const _Destination('Calendar', Icons.calendar_month_outlined, LodgeCalendarScreen()),
      if (permissions.hasPermission(PermissionIds.lodgeRooms))
        const _Destination('Rooms', Icons.meeting_room_outlined, LodgeRoomsScreen()),
      const _Destination('More', Icons.more_horiz, LodgeMoreScreen()),
    ];

    final index = _index.clamp(0, destinations.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: destinations.map((d) => d.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        selectedItemColor: AppColors.brandPrimary,
        unselectedItemColor: isDark ? AppColors.darkTextLight : Colors.grey[600],
        selectedFontSize: 11.5,
        unselectedFontSize: 11.5,
        items: destinations
            .map((d) => BottomNavigationBarItem(icon: Icon(d.icon, size: 22), label: d.label))
            .toList(),
      ),
    );
  }
}

class _Destination {
  final String label;
  final IconData icon;
  final Widget screen;

  const _Destination(this.label, this.icon, this.screen);
}
