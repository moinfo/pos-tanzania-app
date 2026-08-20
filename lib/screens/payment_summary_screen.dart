import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/stock_location.dart';
import '../models/permission_model.dart';
import '../models/sale.dart';
import '../providers/location_provider.dart';
import '../providers/permission_provider.dart';
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

    try {
    // Summary and route order are independent -- fetched together, exactly
    // like the suspended list does.
    final results = await Future.wait([
      _apiService.getPaymentSummary(
        locationId: location.locationId,
        date: _effectiveDate,
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
      final totals = (data['totals'] is List ? data['totals'] as List : const [])
          .whereType<Map>()
          .map((t) => t.cast<String, dynamic>())
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

      // An older server (or PHP encoding an empty array) hands back [] here
      // instead of {} -- treat anything that is not a map as "no customers".
      final rawCustomers = data['customers'];
      final customers = <String, List<Map<String, dynamic>>>{};
      if (rawCustomers is Map) {
        rawCustomers.forEach((type, list) {
          if (list is! List) return;
          final rows = list
              .whereType<Map>()
              .map((c) => c.cast<String, dynamic>())
              .toList();
          _sortByRoute(rows);
          customers[type.toString()] = rows;
        });
      }

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
    } catch (e) {
      // Never strand the spinner: show what went wrong instead.
      debugPrint('Payment summary load failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Could not load the payment summary. Pull to retry.';
          _isLoading = false;
        });
      }
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
    if (!_canPickDate) return;
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

  /// Whether this user may look at a day other than today.
  ///
  /// Same rule as the sales history: without sales_transaction_date a seller
  /// sees today's collections only. Hiding the picker is not enough on its
  /// own -- the request below is pinned to today too, so the restriction
  /// holds however the screen is reached.
  bool get _canPickDate => context
      .read<PermissionProvider>()
      .hasPermission(PermissionIds.salesTransactionDate);

  String get _effectiveDate => DateFormat('yyyy-MM-dd')
      .format(_canPickDate ? _date : DateTime.now());

  String _plural(num count, String singular) =>
      '${_money.format(count)} $singular${count == 1 ? '' : 's'}';

  double get _grandTotal => _totals.fold<double>(
      0, (sum, row) => sum + ((row['total'] ?? 0) as num).toDouble());

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
          if (_canPickDate)
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
              '${DateFormat('EEE, d MMM yyyy').format(_canPickDate ? _date : DateTime.now())}'
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

  /// APP / WEB / MIXED, from the channels a customer's sales carry.
  (String, Color)? _channelBadge(List<dynamic>? channels) {
    if (channels == null || channels.isEmpty) return null;
    final set = channels.map((c) => c.toString()).toSet();
    if (set.length > 1) return ('MIXED', const Color(0xFF7A5AF8));
    return set.first == 'mobile'
        ? ('APP', const Color(0xFF12833C))
        : ('WEB', const Color(0xFF5C6675));
  }

  /// What was sold to this customer on this day: the sales behind the amount,
  /// with their lines. Fetched on open (usually one sale) rather than bundled
  /// into the summary, which would carry every line of every customer.
  Future<void> _showCustomerSales(Map<String, dynamic> row) async {
    final ids = (row['sale_ids'] as List?)?.whereType<int>().toList() ?? [];
    if (ids.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['customer_name'] as String? ?? 'Walk-in Customer',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_money.format((row['amount'] ?? 0) as num)} TSh'
                        ' · ${_plural((row['sales'] ?? 0) as num, 'sale')}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 20),
                Expanded(
                  child: FutureBuilder<List<Sale>>(
                    future: Future.wait(ids.map((id) async {
                      final r = await _apiService.getSaleDetails(id);
                      return r.isSuccess && r.data != null ? r.data! : null;
                    })).then((list) => list.whereType<Sale>().toList()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      final sales = snapshot.data ?? const <Sale>[];
                      if (sales.isEmpty) {
                        return const Center(
                            child: Text('Could not load these sales'));
                      }

                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        children: [
                          for (final sale in sales) ...[
                            Row(
                              children: [
                                Text('Sale #${sale.saleId}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    )),
                                const Spacer(),
                                Text(
                                  '${_money.format(sale.total)} TSh',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...(sale.items ?? const <SaleItem>[]).map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.itemName,
                                              style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_money.format(item.quantity)}'
                                            ' × ${_money.format(item.unitPrice)}'
                                            '${item.discount > 0 ? '  −${_money.format(item.discount)}' : ''}',
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
                                    const SizedBox(width: 10),
                                    Text(
                                      _money.format(item.lineTotal),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 22),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotals(bool isDark) {
    if (_totals.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight * 0.7,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_outlined,
                          size: 56,
                          color: isDark
                              ? AppColors.darkTextLight
                              : Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No payments recorded',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight)),
                      const SizedBox(height: 4),
                      Text('Nothing was collected on this day',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // The day's grand total leads: it is the number being reconciled,
          // and each type below is a breakdown of it.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D7DC4), Color(0xFF155E92)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL COLLECTED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white.withOpacity(0.85),
                    )),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('${_money.format(_grandTotal)} TSh',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      )),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_plural(_totals.length, 'payment type')}'
                  ' · ${_plural(_totals.fold<int>(0, (n, r) => n + ((r['sales'] ?? 0) as num).toInt()), 'sale')}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._totals.map((row) {
            final type = row['payment_type'] as String? ?? '?';
            final (icon, color) = _styleFor(type);
            final share = _grandTotal > 0
                ? ((row['total'] ?? 0) as num) / _grandTotal
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name row: icon, type, chevron. The amount gets its
                        // own line below so a large figure never squeezes the
                        // meta text into a second line.
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(type,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.text,
                                  )),
                            ),
                            Icon(Icons.chevron_right,
                                size: 20,
                                color: isDark
                                    ? AppColors.darkTextLight
                                    : Colors.grey.shade400),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('${_money.format((row['total'] ?? 0) as num)} TSh',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: color,
                              )),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_plural((row['customers'] ?? 0) as num, 'customer')}'
                                ' · ${_plural((row['sales'] ?? 0) as num, 'sale')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkTextLight
                                      : AppColors.textLight,
                                ),
                              ),
                            ),
                            Text('${(share * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Share of the day, so the split reads at a glance.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: share.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCustomers(bool isDark) {
    final rows = _customers[_selectedType] ?? const [];
    if (rows.isEmpty) {
      return Center(child: Text('No $_selectedType payments for this day'));
    }
    final (icon, color) = _styleFor(_selectedType!);
    final total = rows.fold<double>(
        0, (sum, r) => sum + ((r['amount'] ?? 0) as num).toDouble());

    return Column(
      children: [
        // Sticky context: which type, how much, how many stops.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          color: color.withOpacity(isDark ? 0.16 : 0.09),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('${_money.format(total)} TSh',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: color,
                          )),
                    ),
                    Text(_plural(rows.length, 'customer'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = rows[index];
              final onRoute = row['customer_id'] != null &&
                  _routeOrder.containsKey(row['customer_id']);

              final badge = _channelBadge(row['channels'] as List?);

              return Material(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  // Tap to see what was actually sold to this customer.
                  onTap: () => _showCustomerSales(row),
                  child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    // Stop number on the route -- the same circled serial the
                    // suspended, items and customers lists carry. Customers
                    // off the route are numbered too but shown muted, so the
                    // route sequence stays readable.
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (onRoute ? AppColors.primary : Colors.grey)
                            .withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: (onRoute ? AppColors.primary : Colors.grey)
                                .withOpacity(0.5)),
                      ),
                      child: Text('${index + 1}',
                          style: TextStyle(
                            color: onRoute ? AppColors.primary : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['customer_name'] as String? ??
                                'Walk-in Customer',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? AppColors.darkText : AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                  _plural((row['sales'] ?? 0) as num, 'sale'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark
                                        ? AppColors.darkTextLight
                                        : AppColors.textLight,
                                  )),
                              if (badge != null) ...[
                                const SizedBox(width: 6),
                                // Which register completed it -- the same
                                // APP/WEB the web's Source column shows.
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: badge.$2.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(badge.$1,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: badge.$2,
                                      )),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${_money.format((row['amount'] ?? 0) as num)}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color,
                        )),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: isDark
                            ? AppColors.darkTextLight
                            : Colors.grey.shade400),
                  ],
                ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
