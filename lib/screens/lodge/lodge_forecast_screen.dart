import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_theme.dart';

/// `GET lodge/forecast` -- README 3.16: projected revenue at a chosen
/// occupancy. Nothing is saved; every slider move re-asks the server
/// (debounced) since the math (rate x occupancy x days, scenarios) lives
/// there, not on the device.
class LodgeForecastScreen extends StatefulWidget {
  const LodgeForecastScreen({super.key});

  @override
  State<LodgeForecastScreen> createState() => _LodgeForecastScreenState();
}

class _LodgeForecastScreenState extends State<LodgeForecastScreen> {
  final ApiService _apiService = ApiService();
  Timer? _debounce;

  double? _occupancy; // null until the first response sets it to actual
  LodgeForecast? _forecast;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final response = await _apiService.getLodgeForecast(occupancy: _occupancy);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _forecast = response.data;
        // First load only (occupancy still null): the slider starts where
        // the server defaulted it (actual occupancy, or 70% with no
        // history), never overriding a position the user already picked.
        _occupancy ??= _forecast!.actualOccupancy > 0 ? _forecast!.actualOccupancy : 70;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  void _onSliderChanged(double v) {
    setState(() => _occupancy = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(isDark: isDark, eyebrow: 'Projection', title: 'Forecast'),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading && _forecast == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _forecast == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final f = _forecast!;
    final occupancy = _occupancy!;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Occupancy: ${occupancy.round()}%', style: LodgeTheme.display(weight: FontWeight.w700, size: 16)),
            TextButton(
              onPressed: () => _onSliderChanged(f.actualOccupancy),
              child: const Text('Use actual'),
            ),
          ],
        ),
        Slider(
          value: occupancy,
          min: 1,
          max: 100,
          divisions: 99,
          activeColor: AppColors.brandPrimary,
          onChanged: _onSliderChanged,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _totalCard('Day', f.totalDay, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _totalCard('Month', f.totalMonth, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _totalCard('Year', f.totalYear, isDark)),
          ],
        ),
        const SizedBox(height: 16),
        _card(isDark, children: [
          _row('Full capacity: day', f.fullCapacity.day, isDark),
          _row('Full capacity: month', f.fullCapacity.month, isDark),
          _row('Full capacity: year', f.fullCapacity.year, isDark),
          _row('Expenses (avg/month)', -f.expensesMonth, isDark),
          _row('Net (month)', f.netMonth, isDark, highlight: true),
          _row('Net (year)', f.netYear, isDark, highlight: true),
        ]),
        const SizedBox(height: 20),
        Text('Rooms', style: LodgeTheme.display(weight: FontWeight.w700, size: 15, color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 8),
        ...f.rooms.map((r) => Card(
              color: isDark ? AppColors.darkCard : Colors.white,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ),
              elevation: 0,
              child: ListTile(
                dense: true,
                title: Text(r.roomNumber),
                subtitle: Text('${Formatters.formatCurrency(r.rate)}/night · actual ${r.actualOccupancy.toStringAsFixed(0)}%'),
                trailing: Text(Formatters.formatCompactCurrency(r.month)),
              ),
            )),
        if (f.scenarios.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Scenarios', style: LodgeTheme.display(weight: FontWeight.w700, size: 15, color: isDark ? AppColors.darkText : AppColors.lightText)),
          const SizedBox(height: 8),
          ...f.scenarios.map((s) => Card(
                color: isDark ? AppColors.darkCard : Colors.white,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ),
                elevation: 0,
                child: ListTile(
                  dense: true,
                  title: Text('${s.label} (${s.occupancy.toStringAsFixed(0)}%)'),
                  subtitle: Text('Day ${Formatters.formatCompactCurrency(s.day)} · '
                      'Month ${Formatters.formatCompactCurrency(s.month)} · '
                      'Year ${Formatters.formatCompactCurrency(s.year)}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Net/mo ${Formatters.formatCompactCurrency(s.netMonth)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.success)),
                      Text('Net/yr ${Formatters.formatCompactCurrency(s.netYear)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.success)),
                    ],
                  ),
                ),
              )),
        ],
      ],
    );
  }

  Widget _totalCard(String label, double value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Formatters.formatCompactCurrency(value),
              style: LodgeTheme.display(weight: FontWeight.w700, size: 15, color: AppColors.success)),
          Text(label, style: LodgeTheme.body(size: 11, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
        ],
      ),
    );
  }

  Widget _card(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, double value, bool isDark, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
          Text(Formatters.formatCurrency(value),
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: highlight ? (value >= 0 ? AppColors.success : AppColors.error) : null)),
        ],
      ),
    );
  }
}
