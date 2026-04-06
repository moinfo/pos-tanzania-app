import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import 'create_transfer_screen.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _apiService = ApiService();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _transfers = [];

  // Default to today
  late DateTime _dateFrom;
  late DateTime _dateTo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = DateTime(now.year, now.month, now.day);
    _dateTo   = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _apiService.getTransfers(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _transfers = result.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateRange(bool isDark) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _dateFrom, end: _dateTo),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.brandPrimary,
            onPrimary: Colors.white,
            surface: isDark ? AppColors.darkCard : Colors.white,
            onSurface: isDark ? AppColors.darkText : AppColors.text,
          ),
          dialogBackgroundColor: isDark ? AppColors.darkCard : Colors.white,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo   = picked.end;
      });
      _load();
    }
  }

  String _formatDateRange() {
    final now = DateTime.now();
    final isToday = _dateFrom.year == now.year &&
        _dateFrom.month == now.month &&
        _dateFrom.day == now.day &&
        _dateTo.year == now.year &&
        _dateTo.month == now.month &&
        _dateTo.day == now.day;
    if (isToday) return 'Today';
    if (_dateFrom == _dateTo ||
        (_dateFrom.year == _dateTo.year &&
            _dateFrom.month == _dateTo.month &&
            _dateFrom.day == _dateTo.day)) {
      return '${_dateFrom.day} ${_monthName(_dateFrom.month)}';
    }
    return '${_dateFrom.day} ${_monthName(_dateFrom.month)} – ${_dateTo.day} ${_monthName(_dateTo.month)}';
  }

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        title: Text(
          'Stock Transfer',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.text,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? AppColors.darkText : AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? AppColors.darkText : AppColors.text),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => const CreateTransferScreen()),
          );
          if (created == true) _load();
        },
        backgroundColor: AppColors.brandPrimary,
        icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
        label: const Text('New Transfer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Date range filter bar
          Container(
            color: isDark ? AppColors.darkCard : Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _pickDateRange(isDark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.brandPrimary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 14, color: AppColors.brandPrimary),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateRange(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down_rounded,
                            size: 18, color: AppColors.brandPrimary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _transfers.isEmpty
                        ? _buildEmpty(isDark)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 96),
                              itemCount: _transfers.length,
                              itemBuilder: (_, i) =>
                                  _buildTransferCard(_transfers[i], isDark),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz_rounded,
              size: 64,
              color: (isDark ? AppColors.darkTextLight : AppColors.textLight)
                  .withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No transfers yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + New Transfer to convert\nwholesale (CTN) to retail (PC)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextLight : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(Map<String, dynamic> transfer, bool isDark) {
    final source = transfer['source'] as Map<String, dynamic>?;
    final dest = transfer['destination'] as Map<String, dynamic>?;
    final receivingId = transfer['receiving_id'] as int? ?? 0;
    final locationName = transfer['location_name'] as String? ?? '';
    final timeStr = transfer['receiving_time'] as String? ?? '';
    final DateTime? time =
        timeStr.isNotEmpty ? DateTime.tryParse(timeStr) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$receivingId',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (locationName.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.store_outlined,
                              size: 13,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight),
                          const SizedBox(width: 3),
                          Text(
                            locationName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (time != null)
                  Text(
                    DateFormat('dd MMM, HH:mm').format(time),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextLight
                          : AppColors.textLight,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Transfer arrow row
            Row(
              children: [
                Expanded(child: _itemChip(source, 'CTN', isDark, isSource: true)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                ),
                Expanded(
                    child: _itemChip(dest, 'PC', isDark, isSource: false)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemChip(
      Map<String, dynamic>? item, String unit, bool isDark,
      {required bool isSource}) {
    if (item == null) return const SizedBox.shrink();
    final name = item['item_name'] as String? ?? '';
    final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
    final color = isSource ? AppColors.error : AppColors.success;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${isSource ? "-" : "+"}${qty % 1 == 0 ? qty.toInt() : qty} $unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
