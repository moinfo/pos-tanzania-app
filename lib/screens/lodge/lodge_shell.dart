import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import 'lodge_theme.dart';
import 'lodge_board_screen.dart';
import 'lodge_bookings_list_screen.dart';
import 'lodge_calendar_screen.dart';
import 'lodge_expenses_screen.dart';
import 'lodge_day_close_screen.dart';

/// Holds the Lodge module's own bottom navigation -- same pattern as
/// ProductionShell, capped at the five destinations used every day (Board,
/// Bookings, Calendar, Expenses, Day close -- the last one added back on
/// request: closing out cash happens daily, so it earns a tab rather than
/// living a level deeper in the drawer; Rooms swapped out for Expenses on
/// request too). Everything else (Payments, Guests, Rooms, Report,
/// Forecast, Messages) lives in the drawer's Lodge section only
/// (lodge_menu_items.dart).
///
/// The nav bar itself is a floating dark pill (per the redesign), not the
/// stock Material bottom bar -- Scaffold's bottomNavigationBar slot still
/// reserves the space below the body, it's just a rounded, inset Container
/// rather than a flush full-width bar.
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
      if (permissions.hasPermission(PermissionIds.lodgeExpenses))
        const _Destination('Expenses', Icons.receipt_long_outlined, LodgeExpensesScreen()),
      if (permissions.hasPermission(PermissionIds.lodgeDayClose))
        const _Destination('Day close', Icons.lock_clock_outlined, LodgeDayCloseScreen()),
    ];

    final index = _index.clamp(0, destinations.length - 1);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: IndexedStack(
        index: index,
        children: destinations.map((d) => d.screen).toList(),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          height: 68,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: AppColors.primaryDark.withOpacity(0.35), blurRadius: 32, offset: const Offset(0, 14)),
            ],
          ),
          child: Row(
            children: destinations.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              final selected = i == index;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _index = i),
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.warning : Colors.transparent,
                      borderRadius: selected
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22),
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            )
                          : BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(d.icon, size: 20, color: selected ? AppColors.secondary : AppColors.lightDivider),
                        const SizedBox(height: 2),
                        Text(d.label,
                            style: LodgeTheme.body(
                              size: 11,
                              weight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? AppColors.secondary : AppColors.lightDivider,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
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
