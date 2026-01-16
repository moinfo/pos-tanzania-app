import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/credit.dart';
import '../models/stock_location.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/glassmorphic_card.dart';
import '../utils/constants.dart';

class DailyDebtReportScreen extends StatefulWidget {
  const DailyDebtReportScreen({super.key});

  @override
  State<DailyDebtReportScreen> createState() => _DailyDebtReportScreenState();
}

class _DailyDebtReportScreenState extends State<DailyDebtReportScreen> {
  final ApiService _apiService = ApiService();
  final NumberFormat _formatter = NumberFormat('#,###');
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  DailyDebtReportResponse? _reportData;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAndLoad());
  }

  Future<void> _initializeAndLoad() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'credits');
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _isLoading = true; _errorMessage = null; });

    final locationProvider = context.read<LocationProvider>();
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    List<int>? locationIds;
    if (isLeruma && locationProvider.selectedLocation != null) {
      locationIds = [locationProvider.selectedLocation!.locationId];
    } else if (locationProvider.allowedLocations.isNotEmpty) {
      locationIds = locationProvider.allowedLocations.map((loc) => loc.locationId).toList();
    }

    final response = await _apiService.getDailyDebtReport(
      startDate: _dateFormat.format(_startDate),
      endDate: _dateFormat.format(_endDate),
      locationIds: locationIds,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _reportData = response.data;
        } else {
          _errorMessage = response.message ?? 'Failed to load report';
        }
      });
    }
  }

  List<DailyDebtEntry> get _filteredDebts {
    if (_reportData == null) return [];
    if (_searchQuery.isEmpty) return _reportData!.debts;
    final query = _searchQuery.toLowerCase();
    return _reportData!.debts.where((d) =>
      d.customerName.toLowerCase().contains(query) ||
      d.supervisorName.toLowerCase().contains(query) ||
      d.locationName.toLowerCase().contains(query)
    ).toList();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;
    final isLeruma = ApiService.currentClient?.id == 'leruma';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Collection'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isLeruma && locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            _buildLocationSelector(locationProvider),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      body: Container(
        color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
        child: Column(
          children: [
            _buildDateRangeSelector(isDark),
            if (_reportData != null && !_isLoading) _buildSummaryCard(isDark),
            _buildSearchBar(isDark),
            if (_reportData != null && !_isLoading) _buildResultsCount(isDark),
            const SizedBox(height: 8),
            Expanded(child: _buildContent(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector(LocationProvider locationProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: PopupMenuButton<StockLocation>(
          offset: const Offset(0, 40),
          color: Colors.white,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(
                  locationProvider.selectedLocation!.locationName,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
            ],
          ),
          onSelected: (location) async {
            await locationProvider.selectLocation(location);
            _loadReport();
          },
          itemBuilder: (context) => locationProvider.allowedLocations
              .map((location) => PopupMenuItem<StockLocation>(
                    value: location,
                    child: Text(location.locationName),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: InkWell(
          onTap: _selectDateRange,
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date Range', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    Text(
                      '${_displayDateFormat.format(_startDate)} - ${_displayDateFormat.format(_endDate)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_calendar, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final summary = _reportData!.summary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 14,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.payments, color: AppColors.success, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Collection', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                  Text(_formatter.format(summary.totalAmount), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
              child: Text('${summary.count} payments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: EdgeInsets.zero,
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search customer, supervisor...',
            hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildResultsCount(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.receipt_long, size: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('${_filteredDebts.length} payments', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) return _buildSkeletonList(isDark);
    if (_errorMessage != null) return _buildErrorView();
    if (_filteredDebts.isEmpty) return _buildEmptyView();
    return _buildDebtsList(isDark);
  }

  Widget _buildDebtsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredDebts.length,
        itemBuilder: (context, index) => _buildDebtCard(_filteredDebts[index], isDark, index + 1),
      ),
    );
  }

  Widget _buildDebtCard(DailyDebtEntry debt, bool isDark, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassmorphicCard(
        isDark: isDark,
        borderRadius: 12,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.success, AppColors.success.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debt.customerName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      Row(children: [
                        Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(debt.date, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(_formatter.format(debt.amount), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: _buildDetailItem('Supervisor', debt.supervisorName, isDark)),
                  Container(width: 1, height: 30, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  Expanded(child: _buildDetailItem('Location', debt.locationName, isDark)),
                  Container(width: 1, height: 30, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                  Expanded(child: _buildDetailItem('Employee', debt.employeeName, isDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value.isNotEmpty ? value : '-', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassmorphicCard(isDark: isDark, padding: const EdgeInsets.all(14), child: Column(children: [
          Row(children: [
            SkeletonLoader(width: 36, height: 36, borderRadius: 10, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonLoader(width: 120, height: 14, isDark: isDark),
              const SizedBox(height: 6),
              SkeletonLoader(width: 80, height: 10, isDark: isDark),
            ])),
          ]),
          const SizedBox(height: 10),
          SkeletonLoader(width: double.infinity, height: 50, borderRadius: 8, isDark: isDark),
        ])),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 64, color: AppColors.error),
      const SizedBox(height: 16),
      Text(_errorMessage ?? 'An error occurred', style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _loadReport, icon: const Icon(Icons.refresh), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
    ]));
  }

  Widget _buildEmptyView() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
      const SizedBox(height: 16),
      Text(_searchQuery.isEmpty ? 'No debt collections for this period' : 'No results found', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
    ]));
  }
}
