import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../widgets/app_bottom_navigation.dart';

/// The day's takings per payment type for one location, with a drill-down
/// into the customers behind each type.
///
/// Both levels arrive in ONE response, so tapping a type opens instantly.
/// The customer list is ordered by the supervisor's visit route -- the same
/// ordering (and the same map_route source) as the suspended list -- so the
/// seller reads their collections in the order the shops were served.
class PaymentSummaryScreen extends StatefulWidget {
  const PaymentSummaryScreen({super.key});

  @override
  State<PaymentSummaryScreen> createState() => _PaymentSummaryScreenState();
}

class _PaymentSummaryScreenState extends State<PaymentSummaryScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _money = NumberFormat('#,##0', 'en_US');

  bool _isLoading = false;
  String? _error;
  DateTime _date = DateTime.now();

  List<Map<String, dynamic>> _totals = [];
  Map<String, List<Map<String, dynamic>>> _customers = {};
  Map<int, int> _routeOrder = {};

  /// Which payment type is drilled into; null = the summary cards.
  String? _selectedType;

  static const _typeStyles = <String, (IconData, Color)>{
    'Cash': (Icons.payments, Color(0xFF12833C)),
    'Bank': (Icons.account_balance, Color(0xFF1D7DC4)),
    'Credit Card': (Icons.credit_card, Color(0xFFB4770B)),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    await context.read<LocationProvider>().initialize(moduleId: 'sales');
    _load();
  }

  Future<void> _load() async {
    final location = context.read<LocationProvider>().selectedLocation;
    if (location == null) {
      setState(() => _error = 'Select a stock location first');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Summary and route order are independent -- fetched together, exactly
    // like the suspended list does.
    final results = await Future.wait([
      _apiService.getPaymentSummary(
        locationId: location.locationId,
        date: DateFormat('yyyy-MM-dd').format(_date),
      ),
      _apiService.getMapRoute(locationId: location.locationId),
    ]);

    if (!mounted) return;

    final route = results[1] as dynamic;
    if (route.isSuccess && route.data != null) {
      _routeOrder = {
        for (final customer in route.data!.customers)
          customer.personId: customer.sortOrder,
      };
    }

    final summary = results[0] as dynamic;
    if (summary.isSuccess && summary.data != null) {
      final data = summary.data! as Map<String, dynamic>;
      final totals = (data['totals'] as List? ?? [])
          .map((t) => (t as Map).cast<String, dynamic>())
          .toList();
      // Cash, Bank, Credit Card first (the ones sellers reconcile), anything
      // else after, largest first.
      const order = ['Cash', 'Bank', 'Credit Card'];
      totals.sort((a, b) {
        final ia = order.indexOf(a['payment_type'] as String? ?? '');
        final ib = order.indexOf(b['payment_type'] as String? ?? '');
        if (ia != -1 || ib != -1) {
          return (ia == -1 ? order.length : ia)
              .compareTo(ib == -1 ? order.length : ib);
        }
        return ((b['total'] ?? 0) as num).compareTo((a['total'] ?? 0) as num);
      });

      final rawCustomers = (data['customers'] as Map? ?? {});
      final customers = <String, List<Map<String, dynamic>>>{};
      rawCustomers.forEach((type, list) {
        final rows = (list as List)
            .map((c) => (c as Map).cast<String, dynamic>())
            .toList();
        _sortByRoute(rows);
        customers[type as String] = rows;
      });

      setState(() {
        _totals = totals;
        _customers = customers;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = summary.message ?? 'Failed to load payment summary';
        _isLoading = false;
      });
    }
  }

  /// Route position first (walk-ins and off-route customers sink to the end,
  /// largest amount first) -- the suspended list's ordering.
  void _sortByRoute(List<Map<String, dynamic>> rows) {
    rows.sort((a, b) {
      final routeA =
          a['customer_id'] != null ? _routeOrder[a['customer_id']] : null;
      final routeB =
          b['customer_id'] != null ? _routeOrder[b['customer_id']] : null;

      if (routeA != null && routeB != null) return routeA.compareTo(routeB);
      if (routeA != null) return -1;
      if (routeB != null) return 1;

      return ((b['amount'] ?? 0) as num).compareTo((a['amount'] ?? 0) as num);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _selectedType = null;
      });
      _load();
    }
  }

  (IconData, Color) _styleFor(String type) =>
      _typeStyles[type] ?? (Icons.payment, const Color(0xFF5C6675));

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedType ?? 'Payment Summary'),
        leading: _selectedType != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedType = null),
              )
            : null,
        actions: [
          if (locationProvider.selectedLocation != null)
            PopupMenuButton<StockLocation>(
              icon: const Icon(Icons.location_on),
              tooltip: locationProvider.selectedLocation!.locationName,
              onSelected: (location) async {
                await locationProvider.selectLocation(location);
                setState(() => _selectedType = null);
                _load();
              },
              itemBuilder: (context) => locationProvider.allowedLocations
                  .map((location) => PopupMenuItem<StockLocation>(
                        value: location,
                        child: Text(location.locationName),
                      ))
                  .toList(),
            ),
          IconButton(
              icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // Context line: which day and which shop this summary covers.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.darkCard : Colors.grey.shade100,
            child: Text(
              '${DateFormat('EEE, d MMM yyyy').format(_date)}'
              ' · ${locationProvider.selectedLocation?.locationName ?? '—'}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error)))
                    : _selectedType == null
                        ? _buildTotals(isDark)
                        : _buildCustomers(isDark),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildTotals(bool isDark) {
    if (_totals.isEmpty) {
      return const Center(child: Text('No payments recorded for this day'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _totals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final row = _totals[index];
          final type = row['payment_type'] as String? ?? '?';
          final (icon, color) = _styleFor(type);
          final customerCount = (row['customers'] ?? 0) as num;

          return Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedType = type),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '$customerCount customers · ${row['sales'] ?? 0} sales',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_money.format((row['total'] ?? 0) as num)} TSh',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomers(bool isDark) {
    final rows = _customers[_selectedType] ?? const [];
    if (rows.isEmpty) {
      return Center(child: Text('No $_selectedType payments for this day'));
    }
    final (_, color) = _styleFor(_selectedType!);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Stop number on the route -- the same circled serial the
                // suspended, items and customers lists carry.
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.5)),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['customer_name'] as String? ?? 'Walk-in Customer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row['sales'] ?? 0} sale(s)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_money.format((row['amount'] ?? 0) as num)} TSh',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
