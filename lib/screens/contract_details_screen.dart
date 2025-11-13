import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/contract.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/app_bottom_navigation.dart';

class ContractDetailsScreen extends StatefulWidget {
  final Contract contract;

  const ContractDetailsScreen({super.key, required this.contract});

  @override
  State<ContractDetailsScreen> createState() => _ContractDetailsScreenState();
}

class _ContractDetailsScreenState extends State<ContractDetailsScreen> {
  final ApiService _apiService = ApiService();
  List<StatementEntry>? _statement;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Default to current month
    _startDate = DateTime(_startDate.year, _startDate.month, 1);
    _endDate = DateTime(_endDate.year, _endDate.month + 1, 0);
    _loadStatement();
  }

  Future<void> _loadStatement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getContractStatement(
      widget.contract.id,
      startDate: Formatters.formatDateForApi(_startDate),
      endDate: Formatters.formatDateForApi(_endDate),
    );

    setState(() {
      if (result.isSuccess && result.data != null) {
        final statementData = result.data!['statement'] as List;
        _statement = statementData.map((item) => StatementEntry.fromJson(item)).toList();
        _errorMessage = null;
      } else {
        _statement = null;
        _errorMessage = result.message ?? 'Failed to load statement';
      }
      _isLoading = false;
    });
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _startDate = date);
      _loadStatement();
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _endDate = date);
      _loadStatement();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contract.name),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Contract summary card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contract.contractDescription,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Balance', Formatters.formatCurrency(widget.contract.balance), isDark),
                      _buildSummaryItem('Profit', Formatters.formatCurrency(widget.contract.profit), isDark),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Days Paid', widget.contract.daysPaid.toStringAsFixed(0), isDark),
                      _buildSummaryItem('Days Unpaid', widget.contract.daysUnpaid.toStringAsFixed(0), isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Date range selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectStartDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      Formatters.formatDate(Formatters.formatDateForApi(_startDate)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to', style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectEndDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      Formatters.formatDate(Formatters.formatDateForApi(_endDate)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statement list
          Expanded(
            child: _isLoading
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
                                onPressed: _loadStatement,
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
                    : _statement == null || _statement!.isEmpty
                        ? const Center(child: Text('No statement data available'))
                        : RefreshIndicator(
                            onRefresh: _loadStatement,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _statement!.length,
                              itemBuilder: (context, index) {
                                final entry = _statement![index];
                                return _buildStatementEntry(entry, isDark);
                              },
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: 4),
    );
  }

  Widget _buildSummaryItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildStatementEntry(StatementEntry entry, bool isDark) {
    final isOpening = entry.type == 'opening';
    final isClosing = entry.type == 'closing';
    final isSpecial = isOpening || isClosing;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSpecial ? 2 : 1,
      color: isSpecial ? (isDark ? AppColors.darkSurface : AppColors.primary.withOpacity(0.05)) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and description
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.description,
                  style: TextStyle(
                    fontSize: isSpecial ? 14 : 13,
                    fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                Text(
                  Formatters.formatDate(entry.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                    fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Financial details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Credit
                Expanded(
                  child: _buildAmountColumn(
                    'Credit',
                    entry.credit,
                    AppColors.success,
                    isDark: isDark,
                  ),
                ),
                // Debit
                Expanded(
                  child: _buildAmountColumn(
                    'Debit',
                    entry.debit,
                    AppColors.error,
                    isDark: isDark,
                  ),
                ),
                // Balance
                Expanded(
                  child: _buildAmountColumn(
                    'Balance',
                    entry.balance,
                    entry.balance >= 0 ? AppColors.success : AppColors.error,
                    isBold: true,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountColumn(String label, double amount, Color color, {bool isBold = false, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.formatCurrency(amount),
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: amount == 0 ? (isDark ? AppColors.darkTextLight : AppColors.textLight) : color,
          ),
        ),
      ],
    );
  }
}
