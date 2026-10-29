import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// `GET lodge/report` -- README 3.14: period summary + per-room breakdown +
/// guest list. Date range only when the user holds
/// lodge_reports_date_range_filter; otherwise the server forces this month.
class LodgeReportScreen extends StatefulWidget {
  const LodgeReportScreen({super.key});

  @override
  State<LodgeReportScreen> createState() => _LodgeReportScreenState();
}

class _LodgeReportScreenState extends State<LodgeReportScreen> {
  final ApiService _apiService = ApiService();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  LodgeReport? _report;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getLodgeReport(
      startDate: Formatters.formatDateForApi(_startDate),
      endDate: Formatters.formatDateForApi(_endDate),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _report = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: const Text('Report'),
        actions: [
          if (permissions.hasPermission(PermissionIds.lodgeReportsDateRangeFilter))
            IconButton(icon: const Icon(Icons.date_range, size: 20), onPressed: _pickRange),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null || _report == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage ?? 'Not found'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final t = _report!.totals;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            '${Formatters.formatDateForApi(_startDate)} to ${Formatters.formatDateForApi(_endDate)}',
            style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statTile('Revenue', Formatters.formatCompactCurrency(t.revenue), AppColors.success, isDark),
              _statTile('Paid', Formatters.formatCompactCurrency(t.paid), AppColors.info, isDark),
              _statTile('Balance', Formatters.formatCompactCurrency(t.balance),
                  t.balance > 0 ? AppColors.error : AppColors.success, isDark),
              _statTile('Occupancy', '${t.occupancyPct.toStringAsFixed(0)}%', AppColors.warning, isDark),
              _statTile('Bookings', '${t.bookings}', AppColors.brandPrimary, isDark),
              _statTile('Nights sold', '${t.nightsSold}', AppColors.brandPrimary, isDark),
              _statTile('Expenses', Formatters.formatCompactCurrency(t.expenses), AppColors.error, isDark),
              _statTile('Net', Formatters.formatCompactCurrency(t.net),
                  t.net >= 0 ? AppColors.success : AppColors.error, isDark),
              _statTile('Maintenance cost', Formatters.formatCompactCurrency(t.maintenanceCost), Colors.grey, isDark),
            ],
          ),
          const SizedBox(height: 20),
          Text('Rooms', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkText : AppColors.lightText)),
          const SizedBox(height: 8),
          ..._report!.rooms.map((r) => Card(
                color: isDark ? AppColors.darkCard : Colors.white,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  title: Text(r.roomNumber),
                  subtitle: Text('${r.occupancyPct.toStringAsFixed(0)}% occupancy'
                      '${r.maintenanceCost > 0 ? ' · Maintenance ${Formatters.formatCompactCurrency(r.maintenanceCost)}' : ''}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Formatters.formatCompactCurrency(r.revenue), style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (r.balance > 0)
                        Text(Formatters.formatCompactCurrency(r.balance), style: const TextStyle(color: AppColors.error, fontSize: 11)),
                    ],
                  ),
                ),
              )),
          if (_report!.guests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Guests', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.darkText : AppColors.lightText)),
            const SizedBox(height: 8),
            ..._report!.guests.map((g) => Card(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(g.name),
                    subtitle: Text('${g.stays} stay(s)'),
                    trailing: Text(Formatters.formatCompactCurrency(g.spent)),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color, bool isDark) {
    return Container(
      width: 108,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
        ],
      ),
    );
  }
}
