import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/nfc_wallet.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';

class NfcConfirmationsScreen extends StatefulWidget {
  const NfcConfirmationsScreen({super.key});

  @override
  State<NfcConfirmationsScreen> createState() => _NfcConfirmationsScreenState();
}

class _NfcConfirmationsScreenState extends State<NfcConfirmationsScreen> {
  final ApiService _apiService = ApiService();
  List<NfcConfirmation> _confirmations = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 30));
    _loadConfirmations();
  }

  Future<void> _loadConfirmations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _apiService.getNfcConfirmations(
      startDate: _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null,
      endDate: _endDate != null
          ? DateFormat('yyyy-MM-dd').format(_endDate!)
          : null,
      type: _selectedType,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _confirmations = response.data!;
        } else {
          _errorMessage = response.message;
        }
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadConfirmations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final currencyFormat = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Confirmations'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConfirmations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters bar
          Container(
            padding: const EdgeInsets.all(12),
            color: isDark ? AppColors.darkSurface : Colors.grey[100],
            child: Row(
              children: [
                // Date range display
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _startDate != null && _endDate != null
                                ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                                : 'Select dates',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Type filter
                DropdownButton<String>(
                  value: _selectedType,
                  hint: const Text('All Types'),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Types')),
                    DropdownMenuItem(value: 'credit_sale', child: Text('Credit Sales')),
                    DropdownMenuItem(value: 'payment', child: Text('Payments')),
                    DropdownMenuItem(value: 'deposit', child: Text('Deposits')),
                    DropdownMenuItem(value: 'withdrawal', child: Text('Withdrawals')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedType = value);
                    _loadConfirmations();
                  },
                ),
              ],
            ),
          ),

          // Summary cards
          if (!_isLoading && _confirmations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildSummaryCard(
                    'Total Confirmations',
                    _confirmations.length.toString(),
                    Icons.verified,
                    AppColors.primary,
                    isDark,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Total Amount',
                    currencyFormat.format(
                      _confirmations.fold<double>(0, (sum, c) => sum + c.amount),
                    ),
                    Icons.account_balance_wallet,
                    AppColors.success,
                    isDark,
                  ),
                ],
              ),
            ),

          // Confirmations list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadConfirmations,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _confirmations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No confirmations found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'NFC confirmations will appear here',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadConfirmations,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _confirmations.length,
                              itemBuilder: (context, index) {
                                final confirmation = _confirmations[index];
                                return _buildConfirmationCard(
                                  confirmation,
                                  currencyFormat,
                                  dateFormat,
                                  isDark,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationCard(
    NfcConfirmation confirmation,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    bool isDark,
  ) {
    final typeColors = {
      'credit_sale': Colors.orange,
      'payment': Colors.green,
      'deposit': Colors.blue,
      'withdrawal': Colors.red,
    };

    final typeIcons = {
      'credit_sale': Icons.credit_card,
      'payment': Icons.payment,
      'deposit': Icons.arrow_downward,
      'withdrawal': Icons.arrow_upward,
    };

    final color = typeColors[confirmation.confirmationType] ?? Colors.grey;
    final icon = typeIcons[confirmation.confirmationType] ?? Icons.verified;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        confirmation.confirmationTypeDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        dateFormat.format(confirmation.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: confirmation.status == 'confirmed'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    confirmation.status.toUpperCase(),
                    style: TextStyle(
                      color: confirmation.status == 'confirmed'
                          ? Colors.green
                          : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Details
            _buildDetailRow(
              'Customer',
              confirmation.customerName,
              Icons.person,
              isDark,
            ),
            if (confirmation.customerPhone != null)
              _buildDetailRow(
                'Phone',
                confirmation.customerPhone!,
                Icons.phone,
                isDark,
              ),
            _buildDetailRow(
              'Amount',
              currencyFormat.format(confirmation.amount),
              Icons.attach_money,
              isDark,
            ),
            _buildDetailRow(
              'Card UID',
              confirmation.cardUid,
              Icons.nfc,
              isDark,
            ),
            if (confirmation.employeeName != null)
              _buildDetailRow(
                'Employee',
                confirmation.employeeName!,
                Icons.badge,
                isDark,
              ),
            if (confirmation.locationName != null)
              _buildDetailRow(
                'Location',
                confirmation.locationName!,
                Icons.store,
                isDark,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
