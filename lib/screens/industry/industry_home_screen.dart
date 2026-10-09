import 'package:flutter/material.dart';
import '../../services/industry_service.dart';
import '../../utils/constants.dart';
import 'industry_general_screen.dart';
import 'industry_casual_labourers_screen.dart';
import 'industry_attendance_screen.dart';
import 'industry_attendance_log_screen.dart';
import 'industry_wages_screen.dart';
import 'industry_settings_screen.dart';
import 'industry_machines_screen.dart';
import 'industry_roller_screen.dart';
import 'industry_mattress_screen.dart';
import 'industry_production_screen.dart';
import 'industry_stock_screen.dart';
import 'industry_report_screen.dart';
import 'industry_daily_report_screen.dart';
import 'industry_lines_screen.dart';
import 'industry_packing_screen.dart';

/// The web session (session-cookie login) is established silently right
/// after the app's normal login - see AuthProvider.login() - and refreshed
/// automatically if it expires - see WebSessionService.getHeaders()/getJson().
/// There is deliberately no second sign-in prompt here: visibility of this
/// whole screen is already gated by the 'industry' permission grant in
/// main_navigation.dart, matching the web dashboard's own access control.
///
/// Drawer navigation mirrors the web dashboard's 12 Industry tabs exactly
/// (General, Casual Labourers, Attendance, Attendance Log, Wages, Settings,
/// Machines, Roller, Mattress, Production, Stock, Report).
class IndustryHomeScreen extends StatefulWidget {
  const IndustryHomeScreen({super.key});

  @override
  State<IndustryHomeScreen> createState() => _IndustryHomeScreenState();
}

class _IndustryHomeScreenState extends State<IndustryHomeScreen> {
  final IndustryService _industryService = IndustryService();
  String _currentTitle = 'General';
  late Widget _currentBody;

  @override
  void initState() {
    super.initState();
    _currentBody = IndustryGeneralScreen(
      service: _industryService,
      onSessionExpired: _onSessionExpired,
    );
  }

  /// A screen calls this if a request comes back with an expired web session
  /// that silent re-authentication couldn't recover (no remembered
  /// credentials yet, e.g. the user was logged into the app before this
  /// module existed). Rather than a password prompt, this just points them
  /// at the normal fix: log out and back in once to pick up silent access.
  void _onSessionExpired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Industry session expired. Please log out and log back in.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _select(String title, Widget Function() builder) {
    Navigator.pop(context); // close drawer
    setState(() {
      _currentTitle = title;
      _currentBody = builder();
    });
  }

  /// Casual Labourers/Machines use ManagedListScreen, which already has its
  /// own Scaffold/AppBar/FAB - pushed as a full screen instead of swapped in
  /// as a body, so it isn't double-wrapped.
  void _push(Widget screen) {
    Navigator.pop(context); // close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_currentTitle), backgroundColor: AppColors.brandPrimary),
      drawer: _buildDrawer(),
      body: _currentBody,
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: AppColors.brandPrimary),
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: Text('Industry', style: TextStyle(color: Colors.white, fontSize: 22)),
            ),
          ),
          _item(Icons.info_outline, 'General', () => IndustryGeneralScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          ListTile(
            leading: Icon(Icons.people_outline, color: AppColors.brandPrimary),
            title: const Text('Casual Labourers'),
            onTap: () => _push(IndustryCasualLabourersScreen(
              service: _industryService,
              onSessionExpired: _onSessionExpired,
            )),
          ),
          _item(Icons.event_available, 'Attendance', () => IndustryAttendanceScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.list_alt, 'Attendance Log', () => IndustryAttendanceLogScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.attach_money, 'Wages', () => IndustryWagesScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.settings_outlined, 'Settings', () => IndustrySettingsScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          ListTile(
            leading: Icon(Icons.precision_manufacturing_outlined, color: AppColors.brandPrimary),
            title: const Text('Machines'),
            onTap: () => _push(IndustryMachinesScreen(
              service: _industryService,
              onSessionExpired: _onSessionExpired,
            )),
          ),
          _item(Icons.grid_view, 'Lines / Timu', () => IndustryLinesScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.grid_view, 'Roller', () => IndustryRollerScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.bed_outlined, 'Mattress', () => IndustryMattressScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.factory_outlined, 'Production', () => IndustryProductionScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.inventory_outlined, 'Packing', () => IndustryPackingScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.inventory_2_outlined, 'Stock', () => IndustryStockScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.bar_chart, 'Report', () => IndustryReportScreen(
                service: _industryService,
                onSessionExpired: _onSessionExpired,
              )),
          _item(Icons.summarize_outlined, 'Daily Report', () => const IndustryDailyReportScreen()),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String title, Widget Function() builder) {
    return ListTile(
      leading: Icon(icon, color: AppColors.brandPrimary),
      title: Text(title),
      selected: _currentTitle == title,
      onTap: () => _select(title, builder),
    );
  }
}
