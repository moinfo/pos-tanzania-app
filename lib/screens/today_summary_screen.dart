import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/location_provider.dart';
import '../services/api_service.dart';
import '../models/permission_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/glassmorphic_card.dart';

class TodaySummaryScreen extends StatefulWidget {
  const TodaySummaryScreen({super.key});

  @override
  State<TodaySummaryScreen> createState() => _TodaySummaryScreenState();
}

class _TodaySummaryScreenState extends State<TodaySummaryScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _summaryData;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;

    final currentClient = ApiService.currentClient;
    final clientId = currentClient?.id ?? 'sada';

    // Initialize location provider only for Come & Save
    if (clientId == 'come_and_save') {
      final locationProvider = context.read<LocationProvider>();
      await locationProvider.initialize(moduleId: 'sales');
    }

    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = Formatters.formatDateForApi(_selectedDate);

    // Get location only for Come & Save client
    final currentClient = ApiService.currentClient;
    final clientId = currentClient?.id ?? 'sada';

    int? selectedLocationId;
    if (clientId == 'come_and_save' && mounted) {
      final locationProvider = context.read<LocationProvider>();
      selectedLocationId = locationProvider.selectedLocation?.locationId;
    }

    final result = await _apiService.getCashSubmitTodaySummary(
      date: dateStr,
      locationId: selectedLocationId, // null for SADA, specific location for Come & Save
    );

    setState(() {
      if (result.isSuccess && result.data != null) {
        _summaryData = result.data!;
        _errorMessage = null;
      } else {
        _summaryData = null;
        _errorMessage = result.message ?? 'Failed to load summary';
      }
      _isLoading = false;
    });
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
      _loadSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final locationProvider = context.watch<LocationProvider>();
    final selectedLocation = locationProvider.selectedLocation;
    final locations = locationProvider.allowedLocations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today Summary'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector (Come & Save only)
          if (ApiService.currentClient?.id == 'come_and_save' && locations.isNotEmpty)
            PopupMenuButton<int>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    selectedLocation?.locationName ?? 'Location',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
              color: isDark ? AppColors.darkCard : Colors.white,
              offset: const Offset(0, 50),
              onSelected: (locationId) {
                final location = locations.firstWhere((loc) => loc.locationId == locationId);
                locationProvider.selectLocation(location);
                _loadSummary();
              },
              itemBuilder: (context) {
                return locations.map((location) {
                  return PopupMenuItem<int>(
                    value: location.locationId,
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: selectedLocation?.locationId == location.locationId
                              ? AppColors.primary
                              : (isDark ? Colors.white70 : AppColors.textLight),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          location.locationName,
                          style: TextStyle(
                            color: selectedLocation?.locationId == location.locationId
                                ? AppColors.primary
                                : (isDark ? Colors.white : AppColors.text),
                            fontWeight: selectedLocation?.locationId == location.locationId
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadSummary,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _summaryData == null
                  ? Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [AppColors.darkBackground, AppColors.darkSurface]
                              : [AppColors.lightBackground, Colors.white],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: RefreshIndicator(
                        onRefresh: _loadSummary,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Date card with glassmorphic design
                              GlassmorphicCard(
                                isDark: isDark,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      // Calendar icon with gradient
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary.withOpacity(0.8),
                                              AppColors.primary,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.calendar_today,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Summary Date',
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        Formatters.formatDate(_summaryData!['date']),
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkText : AppColors.text,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Summary table with permission-based rows
                              GlassmorphicCard(
                                isDark: isDark,
                                child: Column(
                                  children: _buildPermissionFilteredRows(context, isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  List<Widget> _buildPermissionFilteredRows(BuildContext context, bool isDark) {
    final permissionProvider = Provider.of<PermissionProvider>(context);
    final rows = <Widget>[];

    // Helper to add row with permission check
    void addRowIfPermitted(String permission, Widget row) {
      if (permissionProvider.hasPermission(permission)) {
        rows.add(row);
      }
    }

    // Opening - requires cash_submit_opening
    addRowIfPermitted(
      PermissionIds.cashSubmitOpening,
      _buildSummaryRow('Opening', _summaryData!['opening'], isDark: isDark),
    );
    rows.add(const Divider(height: 1));

    // Turnover - requires cash_submit_turnover
    addRowIfPermitted(
      PermissionIds.cashSubmitTurnover,
      _buildSummaryRow('Turnover A', _summaryData!['turnover']['a'], isDark: isDark),
    );
    addRowIfPermitted(
      PermissionIds.cashSubmitTurnover,
      _buildSummaryRow('Turnover C', _summaryData!['turnover']['c'], isDark: isDark),
    );
    rows.add(const Divider(height: 1));

    // All Sales - requires cash_submit_all_sales
    addRowIfPermitted(
      PermissionIds.cashSubmitAllSales,
      _buildSummaryRow('All Sales', _summaryData!['all_sales'], highlight: true, isDark: isDark),
    );

    // Cash Sales - requires cash_submit_cash_sales
    addRowIfPermitted(
      PermissionIds.cashSubmitCashSales,
      _buildSummaryRow('Cash Sales', _summaryData!['cash_sales'], isDark: isDark),
    );

    // Customer Credit - requires cash_submit_customer_credit
    addRowIfPermitted(
      PermissionIds.cashSubmitCustomerCredit,
      _buildSummaryRow('Customer Credit', _summaryData!['customer_credit'], isDark: isDark),
    );

    // Sales Return - requires cash_submit_sales_return
    addRowIfPermitted(
      PermissionIds.cashSubmitSalesReturn,
      _buildSummaryRow('Sales Return', _summaryData!['sales_return'], isNegative: true, isDark: isDark),
    );
    rows.add(const Divider(height: 1));

    // Customer Debit - requires cash_submit_debit_customer
    addRowIfPermitted(
      PermissionIds.cashSubmitDebitCustomer,
      _buildSummaryRow('Customer Debit', _summaryData!['customer_debit'], isDark: isDark),
    );

    // Supplier Debit Cash - requires cash_submit_debit_supplier_cash
    addRowIfPermitted(
      PermissionIds.cashSubmitDebitSupplierCash,
      _buildSummaryRow('Supplier Debit Cash', _summaryData!['supplier_debit_cash'], isDark: isDark),
    );

    // Supplier Debit Bank - requires cash_submit_debit_supplier_bank
    addRowIfPermitted(
      PermissionIds.cashSubmitDebitSupplierBank,
      _buildSummaryRow('Supplier Debit Bank', _summaryData!['supplier_debit_bank'], isDark: isDark),
    );
    rows.add(const Divider(height: 1));

    // Sales Discount - requires cash_submit_sales_discount
    addRowIfPermitted(
      PermissionIds.cashSubmitSalesDiscount,
      _buildSummaryRow('Sales Discount', _summaryData!['sales_discount'], isDark: isDark),
    );

    // Supplier Credit - requires cash_submit_supplier_credit
    addRowIfPermitted(
      PermissionIds.cashSubmitSupplierCredit,
      _buildSummaryRow('Supplier Credit', _summaryData!['supplier_credit'], isDark: isDark),
    );

    // Supplier Cash - requires cash_submit_supplier_cash
    addRowIfPermitted(
      PermissionIds.cashSubmitSupplierCash,
      _buildSummaryRow('Supplier Cash', _summaryData!['supplier_cash'], isDark: isDark),
    );

    // Receiving Return - requires cash_submit_receiving_return
    addRowIfPermitted(
      PermissionIds.cashSubmitReceivingReturn,
      _buildSummaryRow('Receiving Return', _summaryData!['receiving_return'], isDark: isDark),
    );
    rows.add(const Divider(height: 1));

    // Expenses - requires cash_submit_expenses
    addRowIfPermitted(
      PermissionIds.cashSubmitExpenses,
      _buildSummaryRow('Expenses', _summaryData!['expenses'], isNegative: true, isDark: isDark),
    );

    // Transportation Cost - requires cash_submit_transport_cost
    addRowIfPermitted(
      PermissionIds.cashSubmitTransportCost,
      _buildSummaryRow('Transportation Cost', _summaryData!['transportation_cost'], isDark: isDark),
    );
    rows.add(const Divider(height: 1));

    // Banking Amount - requires cash_submit_banking_amount
    addRowIfPermitted(
      PermissionIds.cashSubmitBankingAmount,
      _buildSummaryRow('Banking Amount', _summaryData!['banking_amount'], highlight: true, isDark: isDark),
    );

    // Cash Amount - requires cash_submit_cash_amount
    addRowIfPermitted(
      PermissionIds.cashSubmitCashAmount,
      _buildSummaryRow('Cash Amount', _summaryData!['cash_amount'], highlight: true, isDark: isDark),
    );

    // Cash Submitted - requires cash_submit_cash_submitted
    addRowIfPermitted(
      PermissionIds.cashSubmitCashSubmitted,
      _buildSummaryRow('Cash Submitted', _summaryData!['cash_submitted'], highlight: true, isDark: isDark),
    );

    // Profit Submitted - requires cash_submit_profit_submitted
    addRowIfPermitted(
      PermissionIds.cashSubmitProfitSubmitted,
      _buildSummaryRow('Profit Submitted', _summaryData!['profit_submitted'], isDark: isDark),
    );
    rows.add(const Divider(height: 1));

    // Profit - requires cash_submit_profit
    addRowIfPermitted(
      PermissionIds.cashSubmitProfit,
      _buildSummaryRow('Profit', _summaryData!['profit'], highlight: true, color: AppColors.success, isDark: isDark),
    );

    // Amount Due - requires cash_submit_amount_due (not in constants yet, using view permission)
    addRowIfPermitted(
      PermissionIds.cashSubmitAmountDue,
      _buildSummaryRow('Amount Due', _summaryData!['amount_due'], highlight: true, isDark: isDark),
    );

    // Amount Tendered - requires cash_submit_amount_tendered (not in constants yet, using view permission)
    addRowIfPermitted(
      PermissionIds.cashSubmitAmountTendered,
      _buildSummaryRow('Amount Tendered', _summaryData!['amount_tendered'], highlight: true, isDark: isDark),
    );

    // Gain/Loss - requires cash_submit_gain_loss
    addRowIfPermitted(
      PermissionIds.cashSubmitGainLoss,
      _buildSummaryRow(
        'Gain/Loss',
        _summaryData!['gain_loss'],
        highlight: true,
        color: (_summaryData!['gain_loss'] as num) >= 0 ? AppColors.success : AppColors.error,
        isDark: isDark,
      ),
    );

    return rows;
  }

  Widget _buildSummaryRow(String label, dynamic value, {bool highlight = false, bool isNegative = false, Color? color, required bool isDark}) {
    final numValue = value is num ? value.toDouble() : 0.0;
    final displayValue = isNegative && numValue != 0 ? -numValue.abs() : numValue;

    if (highlight) {
      // Highlighted rows with gradient accent
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: color != null
                ? [color.withOpacity(0.1), color.withOpacity(0.05)]
                : isDark
                    ? [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.1)]
                    : [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.05)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (color ?? AppColors.primary).withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color ?? AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color ?? (isDark ? AppColors.darkText : AppColors.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (color ?? AppColors.primary).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                Formatters.formatCurrency(displayValue),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color ?? AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Regular rows
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
            ),
          ),
          Text(
            Formatters.formatCurrency(displayValue),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? (isNegative ? AppColors.error : (isDark ? AppColors.darkText : AppColors.text)),
            ),
          ),
        ],
      ),
    );
  }
}
