import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/permission_model.dart';
import '../../models/receiving.dart';
import '../../models/stock_location.dart';
import '../../providers/location_provider.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/skeleton_loader.dart';
import 'receiving_details_screen.dart';
import 'new_receiving_screen.dart';
import 'receivings_summary_screen.dart';
import 'receivings_summary2_screen.dart';
import 'main_store_screen.dart';

class ReceivingsListScreen extends StatefulWidget {
  const ReceivingsListScreen({super.key});

  @override
  State<ReceivingsListScreen> createState() => _ReceivingsListScreenState();
}

class _ReceivingsListScreenState extends State<ReceivingsListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<ReceivingListItem> _receivings = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _currentOffset = 0;
  final int _limit = 20;
  int _totalCount = 0;
  bool _hasMore = true;

  String _searchQuery = '';

  // Date range filter
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Set default date range to today
    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
    _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
    // Initialize location after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocation();
    });
    _loadReceivings();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    final locationProvider = context.read<LocationProvider>();
    // Initialize for receivings module to get receivings-specific locations
    await locationProvider.initialize(moduleId: 'receivings');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadReceivings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentOffset = 0;
      _receivings.clear();
    });

    try {
      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId;

      final response = await _apiService.getReceivings(
        limit: _limit,
        offset: 0,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        locationId: selectedLocationId,
      );

      if (response.isSuccess && response.data != null) {
        final receivingsData = response.data!['receivings'] as List;
        final receivingsList = receivingsData
            .map((json) => ReceivingListItem.fromJson(json))
            .toList();

        setState(() {
          _receivings = receivingsList;
          _totalCount = response.data!['total_count'] ?? 0;
          _currentOffset = _limit;
          _hasMore = _receivings.length < _totalCount;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to load receivings';
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final locationProvider = context.read<LocationProvider>();
      final selectedLocationId = locationProvider.selectedLocation?.locationId;

      final response = await _apiService.getReceivings(
        limit: _limit,
        offset: _currentOffset,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        locationId: selectedLocationId,
      );

      if (response.isSuccess && response.data != null) {
        final receivingsData = response.data!['receivings'] as List;
        final receivingsList = receivingsData
            .map((json) => ReceivingListItem.fromJson(json))
            .toList();

        setState(() {
          _receivings.addAll(receivingsList);
          _currentOffset += _limit;
          _hasMore = _receivings.length < _totalCount;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadReceivings();
  }

  Future<void> _onRefresh() async {
    await _loadReceivings();
  }

  void _navigateToDetails(ReceivingListItem receiving) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceivingDetailsScreen(
          receivingId: receiving.receivingId,
        ),
      ),
    ).then((_) => _loadReceivings());
  }

  void _navigateToNewReceiving() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewReceivingScreen(),
      ),
    ).then((_) => _loadReceivings());
  }

  void _navigateToSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReceivingsSummaryScreen(),
      ),
    );
  }

  void _navigateToSummary2() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReceivingsSummary2Screen(),
      ),
    );
  }

  void _navigateToMainStore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MainStoreScreen(),
      ),
    ).then((_) => _loadReceivings());
  }

  Future<void> _selectDateRange() async {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                    secondary: AppColors.primary,
                    onSecondary: Colors.white,
                    surfaceContainerHighest: const Color(0xFF2D2D2D),
                  ),
                  dialogBackgroundColor: const Color(0xFF1E1E1E),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  datePickerTheme: DatePickerThemeData(
                    backgroundColor: const Color(0xFF1E1E1E),
                    headerBackgroundColor: AppColors.primary,
                    headerForegroundColor: Colors.white,
                    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      if (states.contains(WidgetState.disabled)) {
                        return Colors.grey.shade600;
                      }
                      return Colors.white;
                    }),
                    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary;
                      }
                      return null;
                    }),
                    todayForegroundColor: WidgetStateProperty.all(AppColors.primary),
                    todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
                    yearForegroundColor: WidgetStateProperty.all(Colors.white),
                    rangePickerBackgroundColor: const Color(0xFF1E1E1E),
                    rangePickerHeaderBackgroundColor: AppColors.primary,
                    rangePickerHeaderForegroundColor: Colors.white,
                    rangeSelectionBackgroundColor: AppColors.primary.withOpacity(0.3),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                    secondary: AppColors.primary,
                  ),
                  datePickerTheme: DatePickerThemeData(
                    headerBackgroundColor: AppColors.primary,
                    headerForegroundColor: Colors.white,
                    rangeSelectionBackgroundColor: AppColors.primary.withOpacity(0.2),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadReceivings();
    }
  }

  String _formatDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endDay = DateTime(_endDate.year, _endDate.month, _endDate.day);

    if (startDay == today && endDay == today) {
      return 'Today';
    } else if (startDay == endDay) {
      return DateFormat('dd MMM yyyy').format(_startDate);
    } else {
      return '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return '${formatter.format(amount)} TSh';
  }

  bool _hasReceivingsSummaryFeature() {
    try {
      return ApiService.currentClient?.features.hasReceivingsSummary ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final isDark = themeProvider.isDarkMode;
    final showSummaryButtons = _hasReceivingsSummaryFeature();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receivings'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Location selector - show if user has locations
          if (locationProvider.allowedLocations.isNotEmpty && locationProvider.selectedLocation != null)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 160),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
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
                      Flexible(
                        child: Text(
                          locationProvider.selectedLocation!.locationName,
                          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white),
                    ],
                  ),
                  onSelected: (location) async {
                    await locationProvider.selectLocation(location);
                    _loadReceivings(); // Reload receivings for new location
                  },
                  itemBuilder: (context) => locationProvider.allowedLocations
                      .map((location) => PopupMenuItem<StockLocation>(
                            value: location,
                            child: Row(
                              children: [
                                Icon(
                                  location.locationId == locationProvider.selectedLocation?.locationId
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: location.locationId == locationProvider.selectedLocation?.locationId
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  location.locationName,
                                  style: TextStyle(
                                    color: location.locationId == locationProvider.selectedLocation?.locationId
                                        ? AppColors.primary
                                        : Colors.black87,
                                    fontWeight: location.locationId == locationProvider.selectedLocation?.locationId
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary buttons - Leruma only (before date filter)
          if (showSummaryButtons)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              color: isDark ? AppColors.darkSurface : AppColors.primary,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToSummary,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.summarize, size: 18),
                          label: const Text('Summary', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToSummary2,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.analytics, size: 18),
                          label: const Text('Summary 2', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToMainStore,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.store, size: 18),
                          label: const Text('MS', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Date Range Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDark ? AppColors.darkSurface : AppColors.primary,
            child: InkWell(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _formatDateRange(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkText : AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by supplier, reference...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: _onSearch,
            ),
          ),

          // Summary bar
          if (_receivings.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppColors.darkSurface : AppColors.primary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: $_totalCount receivings',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : Colors.white,
                    ),
                  ),
                  Text(
                    'Showing ${_receivings.length}',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: _isLoading
                ? _buildSkeletonList(isDark)
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(_errorMessage!,
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadReceivings,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _receivings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No receivings found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start by creating your first receiving',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _onRefresh,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _receivings.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= _receivings.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final receiving = _receivings[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary,
                                      child: Icon(
                                        Icons.inventory_2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    title: Text(
                                      receiving.supplierName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.receipt_outlined,
                                                size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              'RECV #${receiving.receivingId}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            if (receiving.reference.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                '" ${receiving.reference}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time,
                                                size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                _formatDate(receiving.receivingTime),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${receiving.totalItems} items',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                receiving.paymentType,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatCurrency(receiving.totalCost),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                    onTap: () => _navigateToDetails(receiving),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: Consumer<PermissionProvider>(
        builder: (context, permissionProvider, child) {
          // Check receivings_add permission
          final hasAddPermission = permissionProvider.hasPermission(PermissionIds.receivingsAdd);

          if (!hasAddPermission) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _navigateToNewReceiving,
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add),
            label: const Text('New Receiving'),
          );
        },
      ),
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: 8,
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Circle avatar skeleton
            SkeletonLoader(
              width: 40,
              height: 40,
              borderRadius: 20,
              isDark: isDark,
            ),
            const SizedBox(width: 16),
            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 150, height: 16, isDark: isDark),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SkeletonLoader(width: 80, height: 12, isDark: isDark),
                      const SizedBox(width: 12),
                      SkeletonLoader(width: 100, height: 12, isDark: isDark),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SkeletonLoader(width: 60, height: 20, borderRadius: 4, isDark: isDark),
                      const SizedBox(width: 8),
                      SkeletonLoader(width: 50, height: 20, borderRadius: 4, isDark: isDark),
                    ],
                  ),
                ],
              ),
            ),
            // Trailing skeleton
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonLoader(width: 70, height: 16, isDark: isDark),
                const SizedBox(height: 8),
                SkeletonLoader(width: 16, height: 16, isDark: isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
