import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/credit.dart';
import '../models/permission_model.dart';
import '../models/stock_location.dart';
import '../models/nfc_wallet.dart';
import '../providers/permission_provider.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../utils/constants.dart';
import '../widgets/permission_wrapper.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/nfc_scan_dialog.dart';
import '../widgets/credit/record_payment_sheet.dart';
import '../widgets/credit/credit_list_widgets.dart';
import 'sale_details_screen.dart';

class CustomerCreditScreen extends StatefulWidget {
  final int customerId;
  final String customerName;

  /// Powers the call button in the Leruma action bar (4.4). Optional because
  /// not every entry point has the number to hand; the button is hidden when
  /// it is missing rather than dialling nothing.
  final String? customerPhone;

  const CustomerCreditScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
  });

  @override
  State<CustomerCreditScreen> createState() => _CustomerCreditScreenState();
}

class _CustomerCreditScreenState extends State<CustomerCreditScreen> {
  final ApiService _apiService = ApiService();

  CreditStatement? _statement;
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedLocationId;

  String _startDate = DateFormat('yyyy-MM-dd').format(
    DateTime(DateTime.now().year, DateTime.now().month, 1),
  );
  String _endDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Which of the 4.2 presets is active, or null when the range came from the
  /// date picker instead.
  String? _periodPreset = 'month';

  /// Whether this user may look outside today.
  ///
  /// Mirrors the web, which puts the credit date controls behind
  /// `credits_edit_date` (views/credit/daily_debt_report.php and
  /// credit_account.php). Without it the statement is pinned to today.
  bool get _canPickPeriod => context
      .read<PermissionProvider>()
      .hasPermission(PermissionIds.creditsEditDate);

  static String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();

    // Initialize location provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      locationProvider.initialize(moduleId: 'sales').then((_) {
        if (mounted && locationProvider.selectedLocation != null) {
          setState(() {
            _selectedLocationId = locationProvider.selectedLocation!.locationId;
          });
        }
      });
    });

    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('🔴 DEBUG: Loading statement for customer ${widget.customerId}');
    print('🔴 DEBUG: Date range: $_startDate to $_endDate');

    // Enforced on the request, not just in the UI: the range lives in state
    // and a value left from before would otherwise still be sent.
    final restricted = !_canPickPeriod;
    final response = await _apiService.getCreditStatement(
      widget.customerId,
      startDate: restricted ? _today : _startDate,
      endDate: restricted ? _today : _endDate,
    );

    print('🔴 DEBUG: Statement response success: ${response.isSuccess}');
    if (response.isSuccess && response.data != null) {
      print('🔴 DEBUG: Statement has ${response.data!.transactions.length} transactions');
      for (var t in response.data!.transactions) {
        print('🔴 DEBUG: Transaction from API - Date: ${t.date}, Credit: ${t.credit}, Debit: ${t.debit}, StockLocationId: ${t.stockLocationId}');
      }
    }

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _statement = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _selectDateRange() async {
    if (!_canPickPeriod) return;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.parse(_startDate),
        end: DateTime.parse(_endDate),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateFormat('yyyy-MM-dd').format(picked.start);
        _endDate = DateFormat('yyyy-MM-dd').format(picked.end);
      });
      _loadStatement();
    }
  }

  void _showPaymentDialog() {
    // Get list of unpaid credit sales
    final creditSales = _statement?.transactions
        .where((t) => t.credit > 0 && t.saleId != null)
        .toList() ?? [];

    showDialog(
      context: context,
      builder: (context) => PaymentDialog(
        customerId: widget.customerId,
        customerName: widget.customerName,
        currentBalance: _statement?.currentBalance ?? 0,
        creditSales: creditSales,
        onPaymentComplete: () {
          Navigator.pop(context);
          _loadStatement();
        },
      ),
    );
  }

  void _showEditPaymentDialog(CreditTransaction transaction) {
    print('Edit button clicked - Transaction ID: ${transaction.id}');

    if (transaction.id == null) {
      print('ERROR: Transaction ID is null, cannot edit');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit: Transaction ID is missing')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => EditPaymentDialog(
        paymentId: transaction.id!,
        customerName: widget.customerName,
        currentAmount: transaction.debit,
        currentDescription: transaction.description ?? '',
        currentDate: transaction.date,
        currentLocationId: transaction.stockLocationId,
        onPaymentUpdated: () {
          Navigator.pop(context);
          _loadStatement();
        },
      ),
    );
  }

  Future<void> _deletePayment(CreditTransaction transaction) async {
    print('Delete button clicked - Transaction ID: ${transaction.id}');

    if (transaction.id == null) {
      print('ERROR: Transaction ID is null, cannot delete');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Transaction ID is missing')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete this payment of ${NumberFormat('#,###').format(transaction.debit)} TSh?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final response = await _apiService.deleteCreditPayment(transaction.id!);

    setState(() => _isLoading = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted successfully')),
        );
        _loadStatement();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    if (ApiService.currentClient?.id == 'leruma') return _buildLerumaScreen();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector
          Consumer<LocationProvider>(
            builder: (context, locationProvider, child) {
              if (locationProvider.allowedLocations.length > 1) {
                final selectedLocation = locationProvider.allowedLocations.firstWhere(
                  (loc) => loc.locationId == _selectedLocationId,
                  orElse: () => locationProvider.allowedLocations.first,
                );
                return PopupMenuButton<int>(
                  icon: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        selectedLocation.locationName,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  onSelected: (locationId) {
                    setState(() {
                      _selectedLocationId = locationId;
                      // List will be filtered automatically when rebuilt
                    });
                  },
                  itemBuilder: (context) {
                    return locationProvider.allowedLocations.map((location) {
                      return PopupMenuItem<int>(
                        value: location.locationId,
                        child: Row(
                          children: [
                            if (_selectedLocationId == location.locationId)
                              const Icon(Icons.check, size: 20),
                            if (_selectedLocationId == location.locationId)
                              const SizedBox(width: 8),
                            Text(location.locationName),
                          ],
                        ),
                      );
                    }).toList();
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_statement != null) _buildBalanceCard(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Period: ${DateFormat('MMM d, y').format(DateTime.parse(_startDate))} - ${DateFormat('MMM d, y').format(DateTime.parse(_endDate))}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  onPressed: _loadStatement,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(isDark)
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!,
                                style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadStatement,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _statement == null || _statement!.transactions.isEmpty
                        ? const Center(child: Text('No transactions found'))
                        : _buildTransactionsList(),
          ),
        ],
      ),
      // Only show Add Payment button when there's a balance to pay
      // Uses credits_pay permission for customer credit payments
      floatingActionButton: (_statement?.currentBalance ?? 0) > 0
          ? PermissionFAB(
              permissionId: PermissionIds.creditsPay,
              onPressed: _showPaymentDialog,
              backgroundColor: AppColors.success,
              tooltip: 'Add Payment',
              child: const Icon(Icons.payment, color: Colors.white),
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Leruma customer statement (design_handoff_home_credit, screen 4).
  // ---------------------------------------------------------------------------

  static final NumberFormat _money = NumberFormat('#,###');

  static const List<BoxShadow> _cardShadow = [
    BoxShadow(color: Color(0x0D103863), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x12103863), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Transactions inside the period, newest first, after the location filter.
  List<CreditTransaction> get _lerumaTransactions {
    if (_statement == null) return [];

    var list = _statement!.transactions
        .where((t) => t.credit > 0 || t.debit > 0)
        .toList();

    if (_selectedLocationId != null) {
      list = list
          .where((t) =>
              t.stockLocationId == _selectedLocationId ||
              t.stockLocationId == null)
          .toList();
    }

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  void _applyPreset(String preset) {
    if (!_canPickPeriod) return;

    final now = DateTime.now();
    late DateTime start;

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        // Monday-based, matching how sellers talk about "this week".
        start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }

    setState(() {
      _periodPreset = preset;
      _startDate = DateFormat('yyyy-MM-dd').format(start);
      _endDate = DateFormat('yyyy-MM-dd').format(now);
    });
    _loadStatement();
  }

  Widget _buildLerumaScreen() {
    return Scaffold(
      backgroundColor: creditPageBg(context),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STATEMENT',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Colors.white70,
              ),
            ),
            Text(
              widget.customerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildSkeletonList(false)
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _loadStatement,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                  children: [
                    if (_statement != null) ...[
                      _buildLerumaBalancesCard(),
                      const SizedBox(height: 14),
                    ],
                    _buildLerumaPeriodRow(),
                    if (_canPickPeriod) ...[
                      const SizedBox(height: 10),
                      _buildLerumaPresets(),
                    ],
                    const SizedBox(height: 16),
                    if (_lerumaTransactions.isEmpty)
                      _buildLerumaEmptyTransactions()
                    else
                      _buildLerumaTransactions(),
                  ],
                ),
      bottomNavigationBar: _buildLerumaActionBar(),
    );
  }

  /// 4.1 Balances card.
  Widget _buildLerumaBalancesCard() {
    final transactions = _lerumaTransactions;
    final creditGiven =
        transactions.fold<double>(0, (sum, t) => sum + t.credit);
    final paid = transactions.fold<double>(0, (sum, t) => sum + t.debit);
    final balance = _statement!.currentBalance;

    // Payments inside the period count negative, so unwinding the period's
    // movement from the current balance gives where the customer started.
    // It must not simply repeat the current balance -- that made the row
    // useless and it has to move when the preset changes.
    final openingBalance = balance - (creditGiven - paid);

    final collected = creditGiven > 0 ? (paid / creditGiven).clamp(0.0, 1.0) : 0.0;
    final settled = balance <= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: creditCardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: creditShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Balance at period start',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: creditInkMuted(context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _money.format(openingBalance),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: creditInkStrong(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: creditHairline(context)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT BALANCE',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: creditInkMuted(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      settled
                          ? 'Fully settled'
                          : 'Outstanding · ${(collected * 100).round()}% collected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: creditInkMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                    _money.format(balance),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                      color: creditInkStrong(context),
                    ),
                  ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'TSh',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: creditInkMuted(context),
                    ),
                  ),
                ],
              ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildLerumaSplitBlock(
                  'CREDIT GIVEN',
                  creditGiven,
                  const Color(0xFFF5F8FC),
                  const Color(0xFF6B7684),
                  const Color(0xFF103863),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLerumaSplitBlock(
                  'PAID',
                  paid,
                  const Color(0xFFEEF9F2),
                  const Color(0xFF3F7355),
                  const Color(0xFF12833C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLerumaSplitBlock(String label, double value, Color bg,
      Color labelColor, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: creditTint(context, valueColor, bg),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: creditDark(context) ? creditInkMuted(context) : labelColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _money.format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor == const Color(0xFF103863)
                  ? creditInkStrong(context)
                  : valueColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 4.2 Period row.
  Widget _buildLerumaPeriodRow() {
    final range =
        '${DateFormat('d MMM').format(DateTime.parse(_startDate))} – '
        '${DateFormat('d MMM y').format(DateTime.parse(_endDate))}';

    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF1668A6)),
        const SizedBox(width: 7),
        Expanded(
          child: GestureDetector(
            onTap: _canPickPeriod ? _selectDateRange : null,
            child: Text(
              _canPickPeriod
                  ? range
                  : 'Today · ${DateFormat('d MMM y').format(DateTime.now())}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: creditInkStrong(context),
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: _loadStatement,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 14, color: Color(0xFF1668A6)),
              SizedBox(width: 5),
              Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1668A6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 4.2 Presets.
  Widget _buildLerumaPresets() {
    const presets = {'today': 'Today', 'week': 'This week', 'month': 'This month'};

    return Row(
      children: presets.entries.map((entry) {
        final selected = _periodPreset == entry.key;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: entry.key == 'month' ? 0 : 8),
            child: GestureDetector(
              onTap: () => _applyPreset(entry.key),
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? (creditDark(context)
                          ? const Color(0xFF2C6FA8)
                          : const Color(0xFF103863))
                      : creditCardBg(context),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected ? Colors.transparent : creditBorder(context),
                  ),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : creditInkMuted(context),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 4.3 Empty state.
  Widget _buildLerumaEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      decoration: BoxDecoration(
        color: creditCardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: creditShadow(context),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: creditTint(context, const Color(0xFF1668A6), const Color(0xFFF1F5FB)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.receipt_long,
                size: 28, color: Color(0xFF9AA5B4)),
          ),
          const SizedBox(height: 14),
          Text(
            'No transactions in this period',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: creditInkStrong(context),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 240,
            child: Text(
              'Credit sales and debt payments made in this period will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: creditInkMuted(context),
              ),
            ),
          ),
          if (_canPickPeriod) ...[
          const SizedBox(height: 16),
          // Widens the period instead of dead-ending on an empty card.
          GestureDetector(
            onTap: () {
              final now = DateTime.now();
              setState(() {
                _periodPreset = null;
                _startDate = DateFormat('yyyy-MM-dd')
                    .format(DateTime(now.year, now.month - 3, now.day));
                _endDate = DateFormat('yyyy-MM-dd').format(now);
              });
              _loadStatement();
            },
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: creditTrack(context),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                'See last 3 months',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: creditInkStrong(context),
                ),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  /// 4.3 Populated list.
  Widget _buildLerumaTransactions() {
    final transactions = _lerumaTransactions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${transactions.length} TRANSACTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: creditInkMuted(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: creditCardBg(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: creditShadow(context),
          ),
          child: Column(
            children: [
              for (int i = 0; i < transactions.length; i++)
                _buildLerumaTransactionRow(
                  transactions[i],
                  isLast: i == transactions.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLerumaTransactionRow(CreditTransaction transaction,
      {required bool isLast}) {
    final isPayment = transaction.debit > 0;
    final amount = isPayment ? transaction.debit : transaction.credit;

    final parts = <String>[];
    final date = DateTime.tryParse(transaction.date);
    if (date != null) parts.add(DateFormat('d MMM, HH:mm').format(date));

    final locationProvider = context.read<LocationProvider>();
    final location = locationProvider.allowedLocations
        .where((loc) => loc.locationId == transaction.stockLocationId)
        .firstOrNull;
    if (location != null) parts.add(location.locationName);

    if (transaction.description != null &&
        transaction.description!.trim().isNotEmpty) {
      parts.add(transaction.description!.trim());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isPayment
                      ? creditTint(context, const Color(0xFF12833C),
                          const Color(0xFFE7F6EE))
                      : creditTint(context, const Color(0xFF1668A6),
                          const Color(0xFFF1F5FB)),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isPayment ? Icons.check : Icons.shopping_cart_outlined,
                  size: 16,
                  color: isPayment
                      ? const Color(0xFF12833C)
                      : const Color(0xFF1668A6),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPayment ? 'Debt payment' : 'Credit sale',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: creditInkStrong(context),
                      ),
                    ),
                    if (parts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        parts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: creditInkMuted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isPayment
                    ? '−${_money.format(amount)}'
                    : _money.format(amount),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isPayment
                      ? const Color(0xFF12833C)
                      : creditInkStrong(context),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 1, color: creditHairline(context)),
      ],
    );
  }

  /// 4.5 Record-payment sheet.
  ///
  /// The statement is reloaded from the API rather than having the new payment
  /// spliced into the local list: one payment has to move the customer's
  /// balance, the supervisor's aggregate and the daily-collection total, and
  /// only the server knows all three.
  Future<void> _openLerumaPaymentSheet() async {
    final recorded = await RecordPaymentSheet.show(
      context,
      customerId: widget.customerId,
      customerName: widget.customerName,
      currentBalance: _statement?.currentBalance ?? 0,
    );

    if (!recorded || !mounted) return;

    await _loadStatement();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF103863),
        elevation: 0,
        duration: const Duration(milliseconds: 2600),
        // Clear of the action bar, which would otherwise cover the toast.
        margin: const EdgeInsets.only(left: 14, right: 14, bottom: 90),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        content: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Payment recorded',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 4.4 Action bar. Replaces the floating green FAB, which sat over the list.
  Widget _buildLerumaActionBar() {
    final phone = widget.customerPhone?.trim();

    return Container(
      decoration: BoxDecoration(
        color: creditCardBg(context),
        border: Border(top: BorderSide(color: creditHairline(context))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (phone != null && phone.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse('tel:$phone')),
                  child: Container(
                    width: 54,
                    height: 52,
                    decoration: BoxDecoration(
                      color: creditTrack(context),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.call,
                        size: 21, color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: PermissionWrapper(
                  permissionId: PermissionIds.creditsPay,
                  child: GestureDetector(
                    onTap: _openLerumaPaymentSheet,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1D7DC4), Color(0xFF103863)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x42103863),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 20, color: Colors.white),
                          SizedBox(width: 7),
                          Text(
                            'Add payment',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Opening Balance:',
                    style: TextStyle(fontSize: 14)),
                Text(
                  '${NumberFormat('#,###').format(_statement!.openingBalance)} TSh',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Balance:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  '${NumberFormat('#,###').format(_statement!.currentBalance)} TSh',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statement!.currentBalance > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    print('🟢 DEBUG: Building transactions list');
    print('🟢 DEBUG: Total transactions: ${_statement!.transactions.length}');
    print('🟢 DEBUG: Selected location ID for filtering: $_selectedLocationId');

    // Filter out transactions where both credit and debit are 0
    var validTransactions = _statement!.transactions
        .where((t) => t.credit > 0 || t.debit > 0)
        .toList();

    print('🟢 DEBUG: Valid transactions (credit > 0 or debit > 0): ${validTransactions.length}');

    // Debug: Show all transaction stock_location_ids
    for (var t in validTransactions) {
      print('🟢 DEBUG: Transaction - Credit: ${t.credit}, Debit: ${t.debit}, StockLocationId: ${t.stockLocationId}');
    }

    // Filter by selected allowed location
    // Show transactions that match the selected location OR have no location assigned (null)
    if (_selectedLocationId != null) {
      validTransactions = validTransactions
          .where((t) => t.stockLocationId == _selectedLocationId || t.stockLocationId == null)
          .toList();
      print('🟢 DEBUG: After location filtering (including null): ${validTransactions.length} transactions');
    }

    // Sort by date (descending) - recent dates first
    validTransactions.sort((a, b) => b.date.compareTo(a.date));

    print('🟢 DEBUG: Final transaction count to display: ${validTransactions.length}');

    return ListView.builder(
      itemCount: validTransactions.length,
      itemBuilder: (context, index) {
        final transaction = validTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(CreditTransaction transaction) {
    final isCredit = transaction.credit > 0;
    final amount = isCredit ? transaction.credit : transaction.debit;
    final isPayment = !isCredit; // Payment transactions can be edited/deleted

    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCredit ? AppColors.error : AppColors.success,
          child: Icon(
            isCredit ? Icons.arrow_upward : Icons.arrow_downward,
            color: Colors.white,
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isCredit ? 'Credit Sale' : 'Payment',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${NumberFormat('#,###').format(amount)} TSh',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCredit ? AppColors.error : AppColors.success,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Date: ${DateFormat('MMM d, y').format(DateTime.parse(transaction.date))}'),
            if (transaction.saleId != null)
              Text('Sale ID: #${transaction.saleId}'),
            if (transaction.stockLocationId != null)
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  final location = locationProvider.allowedLocations.firstWhere(
                    (loc) => loc.locationId == transaction.stockLocationId,
                    orElse: () => StockLocation(
                      locationId: transaction.stockLocationId!,
                      locationName: 'Location ${transaction.stockLocationId}',
                    ),
                  );
                  return Text(
                    'Location: ${location.locationName}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  );
                },
              ),
            Text(
              'Balance: ${NumberFormat('#,###').format(transaction.balance)} TSh',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (isPayment) ...[
              const SizedBox(height: 8),
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  final hasEdit = permissionProvider.hasPermission(PermissionIds.creditsEdit);
                  final hasDelete = permissionProvider.hasPermission(PermissionIds.creditsDelete);

                  if (!hasEdit && !hasDelete) return const SizedBox.shrink();

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasEdit)
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _showEditPaymentDialog(transaction),
                        ),
                      if (hasDelete)
                        TextButton.icon(
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () => _deletePayment(transaction),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
        trailing: isCredit && transaction.saleId != null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
      ),
    );

    // Make credit sales tappable to view details
    if (isCredit && transaction.saleId != null) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleDetailsScreen(saleId: transaction.saleId!),
            ),
          );
        },
        child: card,
      );
    }

    return card;
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SkeletonLoader(width: 40, height: 40, borderRadius: 20, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 120, height: 14, isDark: isDark),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 80, height: 12, isDark: isDark),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonLoader(width: 70, height: 14, isDark: isDark),
                const SizedBox(height: 4),
                SkeletonLoader(width: 50, height: 18, borderRadius: 4, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentDialog extends StatefulWidget {
  final int customerId;
  final String customerName;
  final double currentBalance;
  final List<CreditTransaction> creditSales;
  final VoidCallback onPaymentComplete;

  const PaymentDialog({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentBalance,
    required this.creditSales,
    required this.onPaymentComplete,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isSubmitting = false;
  int? _selectedSaleId;
  int? _selectedLocationId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Initialize location provider for all clients
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      locationProvider.initialize(moduleId: 'sales');
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text);

    // Check if customer requires NFC confirmation
    final nfcSettingsResponse = await _apiService.getCustomerNfcSettings(widget.customerId);
    if (nfcSettingsResponse.isSuccess && nfcSettingsResponse.data != null) {
      final settings = nfcSettingsResponse.data!;

      if (settings.nfcConfirmRequired) {
        // Get customer's NFC card
        final cardsResponse = await _apiService.getCustomerCards(widget.customerId);
        if (!cardsResponse.isSuccess || cardsResponse.data == null || cardsResponse.data!.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Customer requires NFC confirmation but has no card linked'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        final card = cardsResponse.data!.first;

        // Show NFC confirmation dialog
        final confirmed = await showDialog<NfcScanResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => NfcScanDialog(
            title: 'Confirm Payment',
            subtitle: 'Customer must scan NFC card to confirm payment of TZS ${NumberFormat('#,###').format(amount)}',
            expectedCardUid: card.cardUid,
            lookupCustomer: false,
          ),
        );

        if (confirmed == null || !confirmed.success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment cancelled - NFC confirmation required'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
          return;
        }

        // Record the NFC confirmation
        await _apiService.confirmPaymentWithNfc(
          cardUid: card.cardUid,
          amount: amount,
        );
      }
    }

    setState(() => _isSubmitting = true);

    // Get location provider to access selected location
    final locationProvider = context.read<LocationProvider>();

    // Build description including selected sale if any
    String description = _descriptionController.text.trim();
    if (_selectedSaleId != null) {
      final saleNote = 'Payment for Sale #$_selectedSaleId';
      description = description.isEmpty
          ? saleNote
          : '$description - $saleNote';
    }

    // Ensure stock_location_id is always set (either from _selectedLocationId or default)
    final stockLocationId = _selectedLocationId ?? locationProvider.selectedLocation?.locationId;

    print('🔵 DEBUG: Submitting payment with stock_location_id: $stockLocationId');
    print('🔵 DEBUG: _selectedLocationId = $_selectedLocationId');
    print('🔵 DEBUG: locationProvider.selectedLocation?.locationId = ${locationProvider.selectedLocation?.locationId}');

    final formData = PaymentFormData(
      customerId: widget.customerId,
      amount: amount,
      saleId: _selectedSaleId,
      stockLocationId: stockLocationId,
      description: description.isEmpty ? null : description,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );

    print('🔵 DEBUG: PaymentFormData JSON: ${formData.toJson()}');

    final response = await _apiService.addCreditPayment(formData);

    print('🔵 DEBUG: Response success: ${response.isSuccess}');
    print('🔵 DEBUG: Response data: ${response.data}');

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment added successfully')),
        );
        widget.onPaymentComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${widget.customerName}'),
              const SizedBox(height: 8),
              Text(
                'Current Balance: ${NumberFormat('#,###').format(widget.currentBalance)} TSh',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: widget.currentBalance > 0
                      ? AppColors.error
                      : AppColors.success,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.creditSales.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  value: _selectedSaleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Credit Sale (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Choose a sale to pay against',
                  ),
                  items: widget.creditSales.map((sale) {
                    return DropdownMenuItem<int>(
                      value: sale.saleId,
                      child: Text(
                        'Sale #${sale.saleId} - ${NumberFormat('#,###').format(sale.credit)} TSh',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSaleId = value;
                      // Auto-populate location from the selected sale
                      if (value != null) {
                        final selectedSale = widget.creditSales.firstWhere(
                          (sale) => sale.saleId == value,
                        );
                        _selectedLocationId = selectedSale.stockLocationId;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              // Stock Location selector - for all clients
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  return Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedLocationId ?? locationProvider.selectedLocation?.locationId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Stock Location *',
                          border: const OutlineInputBorder(),
                          helperText: _selectedSaleId != null ? 'Location taken from selected sale' : null,
                        ),
                        items: locationProvider.allowedLocations.isEmpty
                            ? [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Loading locations...'),
                                )
                              ]
                            : locationProvider.allowedLocations.map((location) {
                                return DropdownMenuItem<int>(
                                  value: location.locationId,
                                  child: Text(
                                    location.locationName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                        onChanged: _selectedSaleId != null || locationProvider.allowedLocations.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedLocationId = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a stock location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount *',
                  border: OutlineInputBorder(),
                  prefixText: 'TSh ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter payment amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  if (double.parse(value) > widget.currentBalance) {
                    return 'Payment cannot exceed balance of ${NumberFormat('#,###').format(widget.currentBalance)} TSh';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Date field - only show if user has credits_edit_date permission
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  if (permissionProvider.hasPermission(PermissionIds.creditsEditDate)) {
                    return InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM d, y').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Submit Payment'),
        ),
      ],
    );
  }
}

class EditPaymentDialog extends StatefulWidget {
  final int paymentId;
  final String customerName;
  final double currentAmount;
  final String currentDescription;
  final String currentDate;
  final int? currentLocationId;
  final VoidCallback onPaymentUpdated;

  const EditPaymentDialog({
    super.key,
    required this.paymentId,
    required this.customerName,
    required this.currentAmount,
    required this.currentDescription,
    required this.currentDate,
    this.currentLocationId,
    required this.onPaymentUpdated,
  });

  @override
  State<EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<EditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  bool _isSubmitting = false;
  late DateTime _selectedDate;
  int? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.currentAmount.toString());
    _descriptionController = TextEditingController(text: widget.currentDescription);
    _selectedDate = DateTime.parse(widget.currentDate);
    _selectedLocationId = widget.currentLocationId;

    // Initialize location provider for all clients
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      locationProvider.initialize(moduleId: 'sales');
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Get location provider to access selected location
    final locationProvider = context.read<LocationProvider>();

    // Build update data with only changed fields
    final updateData = <String, dynamic>{};

    final newAmount = double.parse(_amountController.text);
    if (newAmount != widget.currentAmount) {
      updateData['amount'] = newAmount;
    }

    final newDescription = _descriptionController.text.trim();
    if (newDescription != widget.currentDescription) {
      updateData['description'] = newDescription;
    }

    final newDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    if (newDate != widget.currentDate) {
      updateData['date'] = newDate;
    }

    // Ensure we use either _selectedLocationId or fallback to provider's selected location
    final stockLocationId = _selectedLocationId ?? locationProvider.selectedLocation?.locationId;
    if (stockLocationId != widget.currentLocationId) {
      updateData['stock_location_id'] = stockLocationId;
    }

    if (updateData.isEmpty) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to save')),
        );
      }
      return;
    }

    final response = await _apiService.updateCreditPayment(
      widget.paymentId,
      updateData,
    );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (response.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment updated successfully')),
        );
        widget.onPaymentUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Payment'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${widget.customerName}'),
              const SizedBox(height: 16),
              // Stock Location selector - for all clients
              Consumer<LocationProvider>(
                builder: (context, locationProvider, child) {
                  return Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedLocationId ?? locationProvider.selectedLocation?.locationId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Stock Location *',
                          border: OutlineInputBorder(),
                        ),
                        items: locationProvider.allowedLocations.isEmpty
                            ? [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Loading locations...'),
                                )
                              ]
                            : locationProvider.allowedLocations.map((location) {
                                return DropdownMenuItem<int>(
                                  value: location.locationId,
                                  child: Text(
                                    location.locationName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                        onChanged: locationProvider.allowedLocations.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedLocationId = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a stock location';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount *',
                  border: OutlineInputBorder(),
                  prefixText: 'TSh ',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter payment amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Date field - only show if user has credits_edit_date permission
              Consumer<PermissionProvider>(
                builder: (context, permissionProvider, child) {
                  if (permissionProvider.hasPermission(PermissionIds.creditsEditDate)) {
                    return InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM d, y').format(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Update Payment'),
        ),
      ],
    );
  }
}
