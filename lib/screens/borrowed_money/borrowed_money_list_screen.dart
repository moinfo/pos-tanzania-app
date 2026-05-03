import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/borrowed_money.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/glassmorphic_card.dart';
import 'borrowed_money_form_screen.dart';

class BorrowedMoneyListScreen extends StatefulWidget {
  const BorrowedMoneyListScreen({super.key});

  @override
  State<BorrowedMoneyListScreen> createState() =>
      _BorrowedMoneyListScreenState();
}

class _BorrowedMoneyListScreenState extends State<BorrowedMoneyListScreen> {
  final ApiService _apiService = ApiService();

  List<BorrowedMoneyItem> _records = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now().copyWith(day: 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getBorrowedMoneyList(
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        limit: 200,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _records = response.data!;
          _records.sort((a, b) => b.date.compareTo(a.date));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadRecords();
    }
  }

  Future<void> _deleteRecord(BorrowedMoneyItem record) async {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text('Delete Record',
            style: TextStyle(color: isDark ? Colors.white : AppColors.text)),
        content: Text(
          'Delete this borrowed money record?\n\nAmount: ${_formatCurrency(record.amount)}\nDate: ${_formatDate(record.date)}',
          style: TextStyle(color: isDark ? AppColors.darkText : AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await _apiService.deleteBorrowedMoney(record.id);
    if (!mounted) return;

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record deleted'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadRecords();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _formatDate(String dateString) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateString));
    } catch (_) {
      return dateString;
    }
  }

  String _formatCurrency(double amount) {
    return '${NumberFormat('#,##0', 'en_US').format(amount)} TSh';
  }

  double get _total => _records.fold(0.0, (sum, r) => sum + r.amount);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Borrowed Money'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const BorrowedMoneyFormScreen()),
        ).then((_) => _loadRecords()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Date range + total summary bar
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark
                ? AppColors.darkSurface
                : AppColors.primary.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${DateFormat('MMM dd, yyyy').format(_startDate)} – ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? AppColors.darkText : AppColors.primary,
                    ),
                  ),
                ),
                if (!_isLoading && _records.isNotEmpty)
                  Text(
                    'Total: ${_formatCurrency(_total)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark ? Colors.white : AppColors.primaryDark,
                    ),
                  ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_errorMessage!,
                                style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkText
                                        : AppColors.text)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadRecords,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _records.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money_off,
                                    size: 64,
                                    color: isDark
                                        ? AppColors.darkTextLight
                                        : Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No borrowed money records',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark
                                        ? AppColors.darkText
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadRecords,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _records.length,
                              itemBuilder: (context, index) {
                                final record = _records[index];
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  child: GlassmorphicCard(
                                    isDark: isDark,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Row(
                                        children: [
                                          // Icon
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFE65100),
                                                  Color(0xFFFF6D00),
                                                ],
                                              ),
                                            ),
                                            child: const Icon(
                                                Icons.account_balance_wallet,
                                                color: Colors.white,
                                                size: 22),
                                          ),
                                          const SizedBox(width: 14),

                                          // Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _formatCurrency(
                                                      record.amount),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : AppColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDate(record.date),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? AppColors.darkTextLight
                                                        : AppColors.textLight,
                                                  ),
                                                ),
                                                if (record.description
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    record.description,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? AppColors
                                                              .darkTextLight
                                                          : AppColors
                                                              .textLight,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),

                                          // Actions
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.edit_outlined,
                                                    size: 20),
                                                color: AppColors.primary,
                                                onPressed: () => Navigator
                                                    .push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        BorrowedMoneyFormScreen(
                                                            record: record),
                                                  ),
                                                ).then(
                                                    (_) => _loadRecords()),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 20),
                                                color: AppColors.error,
                                                onPressed: () =>
                                                    _deleteRecord(record),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}