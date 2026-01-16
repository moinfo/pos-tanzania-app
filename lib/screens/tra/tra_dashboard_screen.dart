import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/tra.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../services/tra_service.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';

/// Dashboard content widget for embedding in TRAMainScreen
class TRADashboardContent extends StatefulWidget {
  final List<EFDDevice> efds;
  final int? defaultEfdId;
  final bool isLoadingEfds;

  const TRADashboardContent({
    super.key,
    required this.efds,
    this.defaultEfdId,
    this.isLoadingEfds = false,
  });

  @override
  State<TRADashboardContent> createState() => _TRADashboardContentState();
}

class _TRADashboardContentState extends State<TRADashboardContent> {
  final TRAService _traService = TRAService();
  final _currencyFormat = NumberFormat('#,##0', 'en_US');

  TRADashboard? _dashboard;
  int? _selectedEfdId;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedEfdId = widget.defaultEfdId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  @override
  void didUpdateWidget(TRADashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultEfdId != widget.defaultEfdId) {
      _selectedEfdId = widget.defaultEfdId;
      _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      final dashboard = await _traService.getDashboard(
        fromDate: startDateStr,
        toDate: endDateStr,
        efdId: _selectedEfdId,
      );

      if (mounted) {
        setState(() {
          _dashboard = dashboard;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final permissionProvider = context.read<PermissionProvider>();
    final hasDateRangePermission = permissionProvider.hasPermission(PermissionIds.traDateFilter);

    if (!hasDateRangePermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to change the date range'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final permissionProvider = context.watch<PermissionProvider>();

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and EFD Filters
            _buildFilterSection(isDark, permissionProvider),
            const SizedBox(height: 16),

            // Dashboard Cards
            if (_isLoading)
              _buildLoadingSkeleton(isDark)
            else if (_errorMessage != null)
              _buildErrorWidget()
            else if (_dashboard != null) ...[
              // Sales Section
              _buildSectionHeader('Sales', isDark),
              const SizedBox(height: 8),
              _buildSalesSummaryCards(isDark),
              const SizedBox(height: 16),

              // Purchases Section
              _buildSectionHeader('Purchases', isDark),
              const SizedBox(height: 8),
              _buildPurchasesSummaryCards(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isDark, PermissionProvider permissionProvider) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final hasDatePermission = permissionProvider.hasPermission(PermissionIds.traDateFilter);
    final hasAllEfdPermission = permissionProvider.hasPermission(PermissionIds.traFilterAllEfd);

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Date Range
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: hasDatePermission ? _selectDateRange : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : AppColors.lightText,
                              ),
                            ),
                          ),
                          if (hasDatePermission)
                            Icon(
                              Icons.arrow_drop_down,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // EFD Filter
            if (widget.efds.isNotEmpty && hasAllEfdPermission)
              DropdownButtonFormField<int?>(
                value: _selectedEfdId,
                decoration: InputDecoration(
                  labelText: 'EFD Device',
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.lightText,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All EFDs'),
                  ),
                  ...widget.efds.map((efd) => DropdownMenuItem<int?>(
                        value: efd.id,
                        child: Text(efd.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedEfdId = value);
                  _loadDashboard();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.lightText,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildSalesSummaryCards(bool isDark) {
    final d = _dashboard!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Leruma Sales',
                value: d.salesLeruma,
                icon: Icons.point_of_sale,
                color: AppColors.primary,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Financial Sales',
                value: d.salesFinancial,
                icon: Icons.account_balance,
                color: Colors.green,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Turnover',
                value: d.turnoverLeruma,
                icon: Icons.trending_up,
                color: Colors.orange,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Taxes',
                value: d.taxesLeruma,
                icon: Icons.receipt_long,
                color: Colors.purple,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPurchasesSummaryCards(bool isDark) {
    final d = _dashboard!;
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Purchases',
            value: d.totalPurchases,
            icon: Icons.shopping_cart,
            color: Colors.blue,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Purchase Taxes',
            value: d.purchasesTaxes,
            icon: Icons.receipt,
            color: Colors.teal,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'TZS ${_currencyFormat.format(value)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return Column(
      children: [
        SkeletonLoader(width: double.infinity, height: 150, isDark: isDark),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SkeletonLoader(width: double.infinity, height: 100, isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: SkeletonLoader(width: double.infinity, height: 100, isDark: isDark)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: SkeletonLoader(width: double.infinity, height: 100, isDark: isDark)),
            const SizedBox(width: 12),
            Expanded(child: SkeletonLoader(width: double.infinity, height: 100, isDark: isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadDashboard,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
