import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/transaction.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';

class CustomerBalanceScreen extends StatefulWidget {
  const CustomerBalanceScreen({super.key});

  @override
  State<CustomerBalanceScreen> createState() => _CustomerBalanceScreenState();
}

class _CustomerBalanceScreenState extends State<CustomerBalanceScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;

  List<CustomerTransactionBalance> _balances = [];
  double _totalDeposited = 0;
  double _totalWithdrawn = 0;
  double _totalBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getAllCustomersBalance();

      if (response.isSuccess && mounted) {
        final balances = response.data ?? [];

        // Calculate totals
        double totalDeposited = 0;
        double totalWithdrawn = 0;
        double totalBalance = 0;

        for (var b in balances) {
          totalDeposited += b.totalDeposited;
          totalWithdrawn += b.totalWithdrawn;
          totalBalance += b.balance;
        }

        setState(() {
          _balances = balances;
          _totalDeposited = totalDeposited;
          _totalWithdrawn = totalWithdrawn;
          _totalBalance = totalBalance;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load data: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Balances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [AppColors.lightBackground, Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildContent(isDark),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return Column(
      children: [
        // Summary Card
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSummaryCard(isDark),
        ),

        // Customer List
        Expanded(
          child: _balances.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 64,
                        color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No customer balances found',
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _balances.length,
                    itemBuilder: (context, index) {
                      return _buildCustomerCard(_balances[index], isDark);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.primary : AppColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Deposit',
                    _totalDeposited,
                    isDark ? Colors.greenAccent : Colors.green.shade700,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Withdraw',
                    _totalWithdrawn,
                    AppColors.primary,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryItem(
                    'Balance',
                    _totalBalance,
                    isDark ? Colors.white : AppColors.secondary,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_balances.length} customer(s) with balance',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            Formatters.formatCurrency(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(CustomerTransactionBalance customer, bool isDark) {
    final balanceColor = customer.balance >= 0
        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
        : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassmorphicCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      customer.customerName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Transaction Details
              Row(
                children: [
                  // Deposit
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deposit',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatCurrency(customer.totalDeposited),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.greenAccent : Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Withdraw
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Withdraw',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatCurrency(customer.totalWithdrawn),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Balance
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatCurrency(customer.balance),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: balanceColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}