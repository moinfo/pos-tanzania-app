import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/credit.dart';
import '../widgets/credit/credit_list_widgets.dart';
import '../providers/location_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/store_switcher_title.dart';
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

  /// Active 5.x preset, or null when the range came from the date picker.
  String? _periodPreset = 'month';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeAndLoad());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    late DateTime start;

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        break;
      default:
        start = DateTime(now.year, now.month, 1);
    }

    setState(() {
      _periodPreset = preset;
      _startDate = start;
      _endDate = now;
    });
    _loadReport();
  }

  Future<void> _initializeAndLoad() async {
    final locationProvider = context.read<LocationProvider>();
    await locationProvider.initialize(moduleId: 'sales');
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
      setState(() {
        _periodPreset = null;
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    if (ApiService.currentClient?.id == 'leruma') return _buildLerumaScreen();

    return Scaffold(
      appBar: AppBar(
        // Same top bar as the rest of the app: the store sits in the centre and
        // is the switcher, instead of a separate chip fighting the title for width.
        title: const StoreSwitcherTitle(subtitle: 'Debt Collection'),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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

  // ---------------------------------------------------------------------------
  // Leruma debt collection (design_handoff_home_credit, screen 5).
  // ---------------------------------------------------------------------------

  Widget _buildLerumaScreen() {
    // The search filters the total and the count as well as the list, so a
    // seller checking one customer sees that customer's figure, not the day's.
    final debts = [..._filteredDebts]
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = debts.fold<double>(0, (sum, d) => sum + d.amount);

    return Scaffold(
      backgroundColor: creditPageBg(context),
      appBar: AppBar(
        title: const StoreSwitcherTitle(subtitle: 'DEBT COLLECTION'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
            _buildLerumaTotalCard(total, debts.length),
            const SizedBox(height: 12),
            _buildLerumaPresets(),
            const SizedBox(height: 12),
            CreditSearchField(
              controller: _searchController,
              hintText: 'Search customer or supervisor',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorView()
            else if (debts.isEmpty)
              _buildLerumaEmpty()
            else
              _buildLerumaList(debts),
          ],
        ),
      ),
    );
  }

  /// 5 Total card.
  Widget _buildLerumaTotalCard(double total, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: creditCardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: creditShadow(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COLLECTED',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: creditInkMuted(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            _formatter.format(total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.3,
                              color: Color(0xFF12833C),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TSh',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: creditInkMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: creditTint(
                      context, const Color(0xFF12833C), const Color(0xFFE7F6EE)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.payments,
                    size: 22, color: Color(0xFF12833C)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: creditHairline(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: Color(0xFF1668A6)),
              const SizedBox(width: 7),
              Expanded(
                child: GestureDetector(
                  onTap: _selectDateRange,
                  child: Text(
                    '${_displayDateFormat.format(_startDate)} – ${_displayDateFormat.format(_endDate)}',
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: creditTrack(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count payments',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: creditInkMuted(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 5 Period presets. Replaces reaching for the date picker in the common
  /// cases; the picker is still there for a custom range.
  Widget _buildLerumaPresets() {
    const presets = {
      'today': 'Today',
      'week': 'This week',
      'month': 'This month'
    };

    return Row(
      children: presets.entries.map((entry) {
        final selected = _periodPreset == entry.key;

        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: entry.key == 'month' ? 0 : 8),
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
                    width: 1.5,
                  ),
                ),
                child: Text(
                  entry.value,
                  maxLines: 1,
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

  Widget _buildLerumaEmpty() {
    // The design offers a "Record payment" button here, but this screen has no
    // customer in context to record against, so it would dead-end in a picker
    // the handoff does not define. Left out until that flow is decided.
    final searching = _searchQuery.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: searching ? 44 : 34, horizontal: 24),
      decoration: BoxDecoration(
        color: creditCardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: creditShadow(context),
      ),
      child: searching
          ? Text(
              'No payment matches that search',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: creditInkMuted(context),
              ),
            )
          : Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: creditTint(
                        context, const Color(0xFF1668A6), const Color(0xFFF1F5FB)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.receipt_long,
                      size: 28, color: Color(0xFF9AA5B4)),
                ),
                const SizedBox(height: 14),
                Text(
                  'No collections in this period',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: creditInkStrong(context),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 230,
                  child: Text(
                    'Debt payments recorded against this store will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: creditInkMuted(context),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLerumaList(List<DailyDebtEntry> debts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: creditCardBg(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: creditShadow(context),
      ),
      child: Column(
        children: [
          for (int i = 0; i < debts.length; i++)
            _buildLerumaRow(debts[i], isLast: i == debts.length - 1),
        ],
      ),
    );
  }

  Widget _buildLerumaRow(DailyDebtEntry debt, {required bool isLast}) {
    final parts = <String>[];
    final date = DateTime.tryParse(debt.date);
    if (date != null) parts.add(DateFormat('d MMM, HH:mm').format(date));
    if (debt.locationName.trim().isNotEmpty) parts.add(debt.locationName);
    if (debt.description.trim().isNotEmpty) parts.add(debt.description.trim());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: creditTint(
                      context, const Color(0xFF12833C), const Color(0xFFE7F6EE)),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  creditInitials(debt.customerName),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF12833C),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                '+${_formatter.format(debt.amount)}',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF12833C),
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
