import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_theme.dart';

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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(
        isDark: isDark,
        eyebrow: 'Performance',
        title: 'Report',
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
          _netResultPanel(t),
          const SizedBox(height: 14),
          _collectedVsBalanceCard(t, isDark),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _kpiTile('Occupancy', '${t.occupancyPct.toStringAsFixed(0)}%', isDark)),
              const SizedBox(width: 10),
              Expanded(child: _kpiTile('Bookings', '${t.bookings}', isDark)),
              const SizedBox(width: 10),
              Expanded(child: _kpiTile('Nights sold', '${t.nightsSold}', isDark)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Rooms', style: LodgeTheme.display(weight: FontWeight.w700, size: 15, color: isDark ? AppColors.darkText : AppColors.lightText)),
          const SizedBox(height: 8),
          ..._report!.rooms.map((r) => Card(
                color: isDark ? AppColors.darkCard : Colors.white,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ),
                elevation: 0,
                child: ListTile(
                  leading: const LodgeArchIcon(),
                  title: Text(r.roomNumber, style: LodgeTheme.body(size: 15, weight: FontWeight.w600)),
                  subtitle: Text('${r.bookings} booking(s) · ${r.nightsSold} night(s) · '
                      '${r.occupancyPct.toStringAsFixed(0)}% occupancy'
                      '${r.maintenanceCost > 0 ? ' · Maintenance ${Formatters.formatCompactCurrency(r.maintenanceCost)}' : ''}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Formatters.formatCompactCurrency(r.revenue),
                          style: LodgeTheme.display(size: 17, weight: FontWeight.w700)),
                      if (r.balance > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(999)),
                            child: Text('${Formatters.formatCompactCurrency(r.balance)} due',
                                style: LodgeTheme.body(
                                    size: 11, weight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                          ),
                        ),
                    ],
                  ),
                ),
              )),
          if (_report!.guests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Guest list', style: LodgeTheme.display(weight: FontWeight.w700, size: 15, color: isDark ? AppColors.darkText : AppColors.lightText)),
            const SizedBox(height: 8),
            ..._report!.guests.map((g) => Card(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  ),
                  elevation: 0,
                  child: ListTile(
                    title: Text(g.guestName, style: LodgeTheme.display(size: 18, weight: FontWeight.w700)),
                    subtitle: Text([
                      if (g.roomNumber != null) 'Room ${g.roomNumber}',
                      if (g.checkInDate != null) '${Formatters.formatDate(g.checkInDate)} → ${Formatters.formatDate(g.checkOutDate)}',
                      '${g.nights} night(s)',
                    ].join(' · ')),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Formatters.formatCompactCurrency(g.total),
                            style: LodgeTheme.display(size: 18, weight: FontWeight.w700)),
                        if (g.status == 'checked_in')
                          const Padding(
                              padding: EdgeInsets.only(top: 4), child: LodgeStatusBadge(label: 'Checked in'))
                        else if (g.status != null)
                          Text(g.status!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _netResultPanel(LodgeReportTotals t) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Stack(
        children: [
          const Positioned(
            right: 0,
            top: 0,
            child: LodgeSkyline(width: 130, showBuildings: false),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Net result', style: TextStyle(fontSize: 13, color: Color(0xFFE9ECEF))),
              Text('TZS ${Formatters.formatCurrency(t.net)}',
                  style: LodgeTheme.display(size: 36, weight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 10),
              Divider(color: AppColors.brandPrimary, height: 1),
              const SizedBox(height: 8),
              _heroRow('Revenue', Formatters.formatCurrency(t.revenue)),
              _heroRow('Expenses', '−${Formatters.formatCurrency(t.expenses)}'),
              _heroRow('Maintenance cost', Formatters.formatCurrency(t.maintenanceCost)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFFE9ECEF))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _collectedVsBalanceCard(LodgeReportTotals t, bool isDark) {
    final pct = t.paid + t.balance > 0 ? t.paid / (t.paid + t.balance) : 1.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Collected vs balance',
              style: LodgeTheme.display(size: 17, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.lightText)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(flex: (pct * 1000).round().clamp(1, 1000), child: Container(color: AppColors.brandPrimary)),
                  Expanded(
                      flex: ((1 - pct) * 1000).round().clamp(1, 1000), child: Container(color: AppColors.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _legendValue('Paid', Formatters.formatCompactCurrency(t.paid), AppColors.brandPrimary,
                    isDark ? AppColors.darkText : AppColors.lightText)),
              Expanded(
                child: _legendValue('Balance', Formatters.formatCompactCurrency(t.balance), AppColors.error,
                    const Color(0xFFB91C1C))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendValue(String label, String value, Color dot, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: LodgeTheme.body(size: 12, color: Colors.grey)),
          ],
        ),
        Text(value, style: LodgeTheme.display(size: 22, weight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _kpiTile(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: LodgeTheme.body(size: 12, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
          Text(value, style: LodgeTheme.display(size: 22, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.lightText)),
        ],
      ),
    );
  }
}
