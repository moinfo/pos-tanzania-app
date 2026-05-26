import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

/// Business Intelligence dashboard — mirrors the web /bi page:
/// Top Performers, Period Comparison, Slow-Moving Stock and Stock Suggestions,
/// all driven by the /api/reports/bi/* endpoints and scoped to the tenant.
class BusinessIntelligenceScreen extends StatefulWidget {
  const BusinessIntelligenceScreen({super.key});

  @override
  State<BusinessIntelligenceScreen> createState() =>
      _BusinessIntelligenceScreenState();
}

class _BusinessIntelligenceScreenState
    extends State<BusinessIntelligenceScreen> {
  final ApiService _api = ApiService();
  final NumberFormat _money = NumberFormat('#,##0', 'en_US');

  bool _loading = true;
  String? _error;

  late DateTime _start;
  late DateTime _end;

  Map<String, dynamic>? _topItems;
  Map<String, dynamic>? _periodCmp;
  Map<String, dynamic>? _slowMoving;
  Map<String, dynamic>? _stockSugg;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, 1); // month-to-date (matches web default)
    _end = now;
    _load();
  }

  String get _sd => DateFormat('yyyy-MM-dd').format(_start);
  String get _ed => DateFormat('yyyy-MM-dd').format(_end);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final results = await Future.wait([
      _api.getBiTopItems(startDate: _sd, endDate: _ed, sortBy: 'revenue', limit: 15),
      _api.getBiPeriodComparison(startDate: _sd, endDate: _ed, limit: 10),
      _api.getBiSlowMoving(days: 30, limit: 50),
      _api.getBiStockSuggestions(startDate: _sd, endDate: _ed, limit: 50),
    ]);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!results[0].isSuccess) {
        final msg = results[0].message;
        _error = msg.isNotEmpty ? msg : 'Failed to load business intelligence';
        return;
      }
      _topItems = results[0].data;
      _periodCmp = results[1].data;
      _slowMoving = results[2].data;
      _stockSugg = results[3].data;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked != null) {
      setState(() {
        _start = picked.start;
        _end = picked.end;
      });
      _load();
    }
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic>? data) {
    final raw = data?['rows'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return const [];
  }

  num _summary(Map<String, dynamic>? data, String key) {
    final s = data?['summary'];
    if (s is Map && s[key] is num) return s[key] as num;
    return 0;
  }

  String _fmtMoney(num v) => '${_money.format(v)} TZS';

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Business Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _dateBar(isDark),
          Expanded(child: _body(isDark)),
        ],
      ),
    );
  }

  Widget _dateBar(bool isDark) {
    final fmt = DateFormat('dd MMM');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
          label: Text('${fmt.format(_start)} – ${fmt.format(_end)}'),
          onPressed: _pickRange,
        ),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          _kpiRow(isDark),
          const SizedBox(height: 8),
          _topPerformers(isDark),
          _periodComparison(isDark),
          _slowMovingSection(isDark),
          _stockSuggestionsSection(isDark),
        ],
      ),
    );
  }

  // ── KPI summary cards ──────────────────────────────────────────────────────
  Widget _kpiRow(bool isDark) {
    final kpis = [
      _Kpi('Revenue', _fmtMoney(_summary(_topItems, 'total_revenue')), Icons.payments_rounded, AppColors.primary),
      _Kpi('Items Sold', '${_summary(_topItems, 'item_count').toInt()}', Icons.inventory_2_rounded, AppColors.success),
      _Kpi('Slow-Moving', '${_summary(_slowMoving, 'total_idle_items').toInt()}', Icons.hourglass_bottom_rounded, AppColors.warning),
      _Kpi('To Restock', '${_summary(_stockSugg, 'items_to_restock').toInt()}', Icons.add_shopping_cart_rounded, AppColors.error),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: kpis.map((k) => _kpiCard(k, isDark)).toList(),
    );
  }

  Widget _kpiCard(_Kpi k, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: k.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: k.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(k.icon, color: k.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                const SizedBox(height: 2),
                Text(k.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section shell ──────────────────────────────────────────────────────────
  Widget _section(bool isDark, String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text)),
              ],
            ),
          ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text('No data for this period',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
            )
          else
            ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Color _muted(bool isDark) => isDark ? AppColors.darkTextLight : AppColors.textLight;
  Color _strong(bool isDark) => isDark ? AppColors.darkText : AppColors.text;

  // ── Top Performers ─────────────────────────────────────────────────────────
  Widget _topPerformers(bool isDark) {
    final rows = _rows(_topItems);
    return _section(isDark, 'Top Performers', Icons.emoji_events_rounded,
        rows.map((r) => _topRow(r, isDark)).toList());
  }

  Widget _topRow(Map<String, dynamic> r, bool isDark) {
    final share = (r['revenue_share_percent'] as num?)?.toDouble() ?? 0;
    final margin = (r['margin_percent'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                child: Text('#${r['rank']}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _muted(isDark))),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['item_name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, color: _strong(isDark))),
                    Text('${r['category'] ?? ''} · ${(r['quantity'] as num?)?.toInt() ?? 0} sold',
                        style: TextStyle(fontSize: 11, color: _muted(isDark))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmtMoney((r['revenue'] as num?) ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text('Profit ${_money.format((r['profit'] as num?) ?? 0)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.success)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (share / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: _muted(isDark).withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 3),
          Text('${share.toStringAsFixed(1)}% of revenue · ${margin.toStringAsFixed(1)}% margin',
              style: TextStyle(fontSize: 10, color: _muted(isDark))),
        ],
      ),
    );
  }

  // ── Period Comparison ────────────────────────────────────────────────────────
  Widget _periodComparison(bool isDark) {
    final rows = _rows(_periodCmp);
    return _section(isDark, 'Period Comparison (vs previous)', Icons.compare_arrows_rounded,
        rows.map((r) => _cmpRow(r, isDark)).toList());
  }

  Widget _cmpRow(Map<String, dynamic> r, bool isDark) {
    final qtyChange = (r['qty_change_percent'] as num?)?.toDouble() ?? 0;
    final profitChange = (r['profit_change_percent'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['item_name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: _strong(isDark))),
                Text('Qty ${(r['current_quantity'] as num?)?.toInt() ?? 0} vs ${(r['previous_quantity'] as num?)?.toInt() ?? 0}',
                    style: TextStyle(fontSize: 11, color: _muted(isDark))),
              ],
            ),
          ),
          _deltaChip('Qty', qtyChange),
          const SizedBox(width: 6),
          _deltaChip('Profit', profitChange),
        ],
      ),
    );
  }

  Widget _deltaChip(String label, double pct) {
    final up = pct >= 0;
    final color = up ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 16, color: color),
          Text('$label ${pct.abs().toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ── Slow-Moving ──────────────────────────────────────────────────────────────
  Widget _slowMovingSection(bool isDark) {
    final rows = _rows(_slowMoving);
    return _section(isDark, 'Slow-Moving Stock', Icons.hourglass_bottom_rounded,
        rows.map((r) => _slowRow(r, isDark)).toList());
  }

  Widget _slowRow(Map<String, dynamic> r, bool isDark) {
    final days = (r['days_since_last_sale'] as num?)?.toInt();
    final badgeColor = days == null
        ? AppColors.error
        : days > 90
            ? AppColors.error
            : days > 30
                ? AppColors.warning
                : AppColors.success;
    final badgeText = days == null ? 'Never sold' : '$days days idle';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['item_name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: _strong(isDark))),
                Text('Stock ${(r['stock_qty'] as num?)?.toInt() ?? 0} · ${_fmtMoney((r['stock_value'] as num?) ?? 0)}',
                    style: TextStyle(fontSize: 11, color: _muted(isDark))),
              ],
            ),
          ),
          _pill(badgeText, badgeColor),
        ],
      ),
    );
  }

  // ── Stock Suggestions ──────────────────────────────────────────────────────
  Widget _stockSuggestionsSection(bool isDark) {
    final rows = _rows(_stockSugg);
    return _section(isDark, 'Stock Suggestions (reorder)', Icons.add_shopping_cart_rounded,
        rows.map((r) => _suggRow(r, isDark)).toList());
  }

  Widget _suggRow(Map<String, dynamic> r, bool isDark) {
    final daysLeft = (r['days_of_stock'] as num?)?.toInt();
    final urgencyColor = daysLeft == null
        ? AppColors.warning
        : daysLeft < 7
            ? AppColors.error
            : daysLeft < 14
                ? AppColors.warning
                : AppColors.success;
    final order = (r['suggested_order_qty'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r['item_name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: _strong(isDark))),
                Text('Stock ${(r['stock_qty'] as num?)?.toInt() ?? 0} · '
                    '${daysLeft == null ? '—' : '$daysLeft d left'} · '
                    '${((r['daily_velocity'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}/day',
                    style: TextStyle(fontSize: 11, color: _muted(isDark))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _pill('Order $order', urgencyColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _Kpi(this.label, this.value, this.icon, this.color);
}
