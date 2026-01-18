import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/api_response.dart';
import '../../models/financial_banking.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../widgets/skeleton_loader.dart';

class FinancialBankingScreen extends StatefulWidget {
  const FinancialBankingScreen({super.key});

  @override
  State<FinancialBankingScreen> createState() => _FinancialBankingScreenState();
}

class _FinancialBankingScreenState extends State<FinancialBankingScreen> {
  final ApiService _apiService = ApiService();
  final _currencyFormat = NumberFormat('#,###', 'en_US');

  int _currentIndex = 0;
  FinancialDashboard? _dashboard;
  List<EfdAnalysisItem>? _efdAnalysis;
  bool _isLoading = false;
  String? _errorMessage;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int? _selectedEfdId;

  // Permission flags
  bool _canChangeDateRange = false;
  bool _canSelectAllEfds = false;
  bool _canViewMismatchReport = false;
  bool _canAddDeposit = false;
  bool _canEditDeposit = false;
  bool _canDeleteDeposit = false;

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    final permissionProvider = context.read<PermissionProvider>();

    setState(() {
      _canChangeDateRange =
          permissionProvider.hasPermission(PermissionIds.bankingDateRangeFilter);
      _canSelectAllEfds =
          permissionProvider.hasPermission(PermissionIds.bankingSelectAllEfds);
      _canViewMismatchReport =
          permissionProvider.hasPermission(PermissionIds.bankingMismatchReport);
      _canAddDeposit =
          permissionProvider.hasPermission(PermissionIds.bankingAddDeposit);
      _canEditDeposit =
          permissionProvider.hasPermission(PermissionIds.bankingEditDeposit);
      _canDeleteDeposit =
          permissionProvider.hasPermission(PermissionIds.bankingDeleteDeposit);
    });

    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate);

      // Load dashboard and EFD analysis in parallel
      final results = await Future.wait([
        _apiService.getFinancialDashboard(
          startDate: startDateStr,
          endDate: endDateStr,
          efdId: _selectedEfdId,
        ),
        _apiService.getEfdAnalysis(
          startDate: startDateStr,
          endDate: endDateStr,
        ),
      ]);

      final dashboardResponse = results[0] as ApiResponse<FinancialDashboard>;
      final efdAnalysisResponse = results[1] as ApiResponse<List<EfdAnalysisItem>>;

      if (dashboardResponse.isSuccess && dashboardResponse.data != null) {
        setState(() {
          _dashboard = dashboardResponse.data;
          _efdAnalysis = efdAnalysisResponse.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = dashboardResponse.message ?? 'Failed to load dashboard';
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
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    final picked = await showDateRangePicker(
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
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
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

  String _formatDateRange() {
    final formatter = DateFormat('MMM d');
    if (_startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day) {
      return DateFormat('MMM d, yyyy').format(_startDate);
    }
    return '${formatter.format(_startDate)} - ${formatter.format(_endDate)}, ${_endDate.year}';
  }

  // Build list of navigation items based on permissions
  List<_NavItem> _getNavItems() {
    final items = <_NavItem>[
      _NavItem(
        icon: Icons.home,
        label: 'Home',
        index: 0,
      ),
      _NavItem(
        icon: Icons.people,
        label: 'Beneficiaries',
        index: 1,
      ),
      _NavItem(
        icon: Icons.analytics,
        label: 'EFD Analysis',
        index: 2,
      ),
      _NavItem(
        icon: Icons.receipt_long,
        label: 'Deposits',
        index: 3,
      ),
    ];

    // Only add Mismatch Report if user has permission
    if (_canViewMismatchReport) {
      items.add(_NavItem(
        icon: Icons.warning_amber,
        label: 'Mismatch',
        index: 4,
      ));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final navItems = _getNavItems();

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters section (only show on Home tab)
          if (_currentIndex == 0) _buildFiltersSection(isDark),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingSkeleton(isDark)
                : _errorMessage != null
                    ? _buildErrorState(isDark)
                    : _dashboard == null
                        ? _buildEmptyState(isDark)
                        : _buildTabContent(isDark),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex.clamp(0, navItems.length - 1),
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: navItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.label,
        )).toList(),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Financial Banking';
      case 1:
        return 'Beneficiary Details';
      case 2:
        return 'EFD Analysis';
      case 3:
        return 'Deposit History';
      case 4:
        return 'Mismatch Report';
      default:
        return 'Financial Banking';
    }
  }

  Widget _buildTabContent(bool isDark) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(isDark);
      case 1:
        return _buildBeneficiaryDetailsTab(isDark);
      case 2:
        return _buildEfdAnalysisTab(isDark);
      case 3:
        return _buildDepositHistoryTab(isDark);
      case 4:
        return _buildMismatchReportTab(isDark);
      default:
        return _buildHomeTab(isDark);
    }
  }

  Widget _buildFiltersSection(bool isDark) {
    // Build EFD dropdown items based on permission
    List<DropdownMenuItem<int?>> efdItems = [];

    // Only show "All EFDs" option if user has permission
    if (_canSelectAllEfds) {
      efdItems.add(DropdownMenuItem<int?>(
        value: null,
        child: Text(
          'All EFDs',
          style: TextStyle(color: isDark ? AppColors.darkText : Colors.black87),
        ),
      ));
    }

    // Add individual EFDs
    efdItems.addAll((_dashboard?.efds ?? []).map((efd) => DropdownMenuItem<int?>(
          value: efd.id,
          child: Text(
            efd.name,
            style: TextStyle(color: isDark ? AppColors.darkText : Colors.black87),
          ),
        )));

    return Container(
      padding: const EdgeInsets.all(12),
      color: isDark ? AppColors.darkSurface : AppColors.primary,
      child: Column(
        children: [
          // EFD Dropdown (if EFDs available)
          if (_dashboard?.efds.isNotEmpty == true)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedEfdId,
                  isExpanded: true,
                  hint: Text(
                    _canSelectAllEfds ? 'All EFDs' : 'Select EFD',
                    style:
                        TextStyle(color: isDark ? AppColors.darkText : Colors.black87),
                  ),
                  items: efdItems,
                  onChanged: (value) {
                    setState(() => _selectedEfdId = value);
                    _loadDashboard();
                  },
                ),
              ),
            ),

          // Date Range Picker - only interactive if user has permission
          InkWell(
            onTap: _canChangeDateRange ? _selectDateRange : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _canChangeDateRange ? AppColors.primary : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatDateRange(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _canChangeDateRange
                          ? (isDark ? AppColors.darkText : AppColors.primary)
                          : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (_canChangeDateRange)
                    Icon(Icons.arrow_drop_down, color: AppColors.primary)
                  else
                    Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HOME TAB (Dashboard) ====================

  Widget _buildHomeTab(bool isDark) {
    final dashboard = _dashboard!;
    final summary = dashboard.summary;
    final stats = dashboard.statistics;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            _buildSummaryCards(summary, isDark),

            const SizedBox(height: 16),

            // Statistics Row
            _buildStatisticsRow(stats, isDark),

            const SizedBox(height: 20),

            // Statistics by EFD
            _buildStatisticsByEfd(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(bool isDark) {
    final actions = <Map<String, dynamic>>[
      {
        'icon': Icons.people_outline,
        'label': 'Beneficiaries',
        'color': const Color(0xFF3B82F6),
        'index': 1,
      },
      {
        'icon': Icons.analytics_outlined,
        'label': 'EFD Analysis',
        'color': const Color(0xFF8B5CF6),
        'index': 2,
      },
      {
        'icon': Icons.receipt_long_outlined,
        'label': 'Deposits',
        'color': const Color(0xFF10B981),
        'index': 3,
      },
      if (_canViewMismatchReport)
        {
          'icon': Icons.warning_amber_outlined,
          'label': 'Mismatch',
          'color': const Color(0xFFEF4444),
          'index': 4,
        },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((action) {
          return _buildQuickActionItem(
            icon: action['icon'] as IconData,
            label: action['label'] as String,
            color: action['color'] as Color,
            isDark: isDark,
            onTap: () => setState(() => _currentIndex = action['index'] as int),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Statistics by EFD table
  Widget _buildStatisticsByEfd(bool isDark) {
    final dashboard = _dashboard!;
    final deposits = dashboard.deposits;

    // Group deposits by EFD name and calculate statistics
    final Map<String, Map<String, dynamic>> efdStats = {};

    for (final deposit in deposits) {
      final efdName = deposit.efdName.isNotEmpty ? deposit.efdName : 'Unknown';

      if (!efdStats.containsKey(efdName)) {
        efdStats[efdName] = {
          'total': 0,
          'mismatches': 0,
          'notDeposited': 0,
        };
      }

      efdStats[efdName]!['total'] = (efdStats[efdName]!['total'] as int) + 1;

      if (deposit.status == 'Mismatch') {
        efdStats[efdName]!['mismatches'] = (efdStats[efdName]!['mismatches'] as int) + 1;
      } else if (deposit.status == 'Not yet deposited' || deposit.status == 'Pending') {
        efdStats[efdName]!['notDeposited'] = (efdStats[efdName]!['notDeposited'] as int) + 1;
      }
    }

    final sortedEfds = efdStats.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Statistics by EFD',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
          ),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'EFD Name',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Mismatch',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Not Dep.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table Rows
          if (sortedEfds.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No EFD data available',
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextLight : Colors.grey,
                  ),
                ),
              ),
            )
          else
            ...sortedEfds.map((efdName) {
              final stats = efdStats[efdName]!;
              final total = stats['total'] as int;
              final mismatches = stats['mismatches'] as int;
              final notDeposited = stats['notDeposited'] as int;
              final mismatchPercent = total > 0 ? (mismatches / total * 100) : 0.0;
              final notDepositedPercent = total > 0 ? (notDeposited / total * 100) : 0.0;
              final isAllClear = mismatches == 0 && notDeposited == 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // EFD Name
                    Expanded(
                      flex: 2,
                      child: Text(
                        efdName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkText : Colors.black87,
                        ),
                      ),
                    ),
                    // Total Transactions
                    Expanded(
                      flex: 1,
                      child: Text(
                        total.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : Colors.black87,
                        ),
                      ),
                    ),
                    // Mismatches
                    Expanded(
                      flex: 2,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$mismatches ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkText : Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text: '(${mismatchPercent.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.darkTextLight : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Not Deposited
                    Expanded(
                      flex: 2,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$notDeposited ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkText : Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text: '(${notDepositedPercent.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.darkTextLight : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Status
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAllClear
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAllClear ? 'All Clear' : 'Issues',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ==================== BENEFICIARY DETAILS TAB ====================

  Widget _buildBeneficiaryDetailsTab(bool isDark) {
    final targets = _dashboard!.beneficiaryTargets;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Beneficiary Details Section
            Text(
              'Beneficiary Details (${targets.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Beneficiary Table
            if (targets.isEmpty)
              _buildEmptyBeneficiaries(isDark)
            else
              ...targets.map((target) => _buildBeneficiaryCard(target, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficiaryCard(BeneficiaryTarget target, bool isDark) {
    final progressColor = target.isComplete
        ? Colors.green
        : target.hasDeposits
            ? Colors.orange
            : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: progressColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            target.isComplete
                ? Icons.check_circle
                : target.hasDeposits
                    ? Icons.schedule
                    : Icons.account_balance,
            color: progressColor,
            size: 24,
          ),
        ),
        title: Text(
          target.beneficiaryName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? AppColors.darkText : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              target.supplierName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextLight : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: target.progressPercentage / 100,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currencyFormat.format(target.depositedAmount)} / ${_currencyFormat.format(target.totalAmount)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                  ),
                ),
                Text(
                  '${target.progressPercentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          // Bank Accounts
          if (target.bankAccounts.isNotEmpty) ...[
            const Divider(),
            Text(
              'Bank Accounts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...target.bankAccounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.account_balance,
                        size: 16,
                        color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${account.bankName}: ${account.accountNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkText : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Description
          if (target.description != null && target.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Description', target.description!, isDark),
          ],

          // Amount Details
          const SizedBox(height: 8),
          _buildDetailRow(
            'Remaining',
            '${_currencyFormat.format(target.remainingAmount)} TZS',
            isDark,
            highlight: target.remainingAmount > 0,
          ),

          // Deposit Button
          if (_canAddDeposit && target.remainingAmount > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showMakeDepositDialog(target),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Make Deposit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyBeneficiaries(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No beneficiary targets found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextLight : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting the date range or EFD filter',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextLight : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EFD ANALYSIS TAB ====================

  Widget _buildEfdAnalysisTab(bool isDark) {
    final dashboard = _dashboard!;
    final efdAnalysis = _efdAnalysis ?? [];

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'EFD Analysis (${efdAnalysis.length} EFDs)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            if (efdAnalysis.isEmpty)
              _buildEmptyEfds(isDark)
            else
              // EFD Analysis Table
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'EFD Name',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Amount / Deposited',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextLight : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Table Rows - using new EFD Analysis data from API
                    ...efdAnalysis.map((efd) => _buildEfdAnalysisRow(efd, isDark)),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // EFD Summary Statistics
            Text(
              'EFD Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            _buildEfdStatsSummary(dashboard, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEfdAnalysisRow(EfdAnalysisItem efd, bool isDark) {
    final totalAmount = efd.totalAmount;
    final depositedAmount = efd.depositedAmount;
    final remainingAmount = efd.remainingAmount;
    final beneficiaryCount = efd.beneficiaryCount;
    final progress = efd.progressPercentage;
    final isComplete = efd.isComplete;

    // Status badge color based on status from API
    Color statusColor;
    if (efd.status == 'Completed') {
      statusColor = const Color(0xFF10B981); // Green
    } else if (efd.status == 'In Progress') {
      statusColor = const Color(0xFFF97316); // Orange
    } else {
      statusColor = Colors.grey; // Not Started
    }

    return InkWell(
      onTap: () {
        // Filter dashboard by this EFD
        setState(() {
          _selectedEfdId = efd.efdId;
          _currentIndex = 0; // Go back to home
        });
        _loadDashboard();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: EFD Name and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    efd.efdName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    efd.status,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Financial Details
            Row(
              children: [
                // Total Amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextLight : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(totalAmount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkText : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Deposited
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deposited',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextLight : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(depositedAmount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                // Remaining
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.darkTextLight : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(remainingAmount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: remainingAmount > 0 ? const Color(0xFFEF4444) : (isDark ? AppColors.darkText : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3: Progress bar and Beneficiaries
            Row(
              children: [
                // Progress bar
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextLight : Colors.grey,
                            ),
                          ),
                          Text(
                            '${progress.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkText : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (progress / 100).clamp(0.0, 1.0),
                          backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Beneficiaries count
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Beneficiaries',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? AppColors.darkTextLight : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      beneficiaryCount.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEfdStatsSummary(FinancialDashboard dashboard, bool isDark) {
    final stats = dashboard.statistics;
    final summary = dashboard.summary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEfdStatRow(
            'Total Transactions',
            stats.totalTransactions.toString(),
            Icons.receipt,
            const Color(0xFF3B82F6),
            isDark,
          ),
          const Divider(height: 24),
          _buildEfdStatRow(
            'Verified Deposits',
            stats.verifiedCount.toString(),
            Icons.check_circle,
            const Color(0xFF10B981),
            isDark,
          ),
          const Divider(height: 24),
          _buildEfdStatRow(
            'Pending Verification',
            stats.totalPending.toString(),
            Icons.pending,
            const Color(0xFFF59E0B),
            isDark,
          ),
          const Divider(height: 24),
          _buildEfdStatRow(
            'Active Beneficiaries',
            summary.activeBeneficiaries.toString(),
            Icons.people,
            const Color(0xFF8B5CF6),
            isDark,
          ),
          if (_canViewMismatchReport) ...[
            const Divider(height: 24),
            _buildEfdStatRow(
              'Mismatches Found',
              stats.totalMismatches.toString(),
              Icons.warning_amber,
              const Color(0xFFEF4444),
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEfdStatRow(String label, String value, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkText : Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyEfds(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.point_of_sale_outlined,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No EFDs found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextLight : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No electronic fiscal devices available',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextLight : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DEPOSIT HISTORY TAB ====================

  Widget _buildDepositHistoryTab(bool isDark) {
    final dashboard = _dashboard!;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deposits Section Title
            Text(
              'Deposits (${dashboard.deposits.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Deposits List
            if (dashboard.deposits.isEmpty)
              _buildEmptyDeposits(isDark)
            else
              ...dashboard.deposits.map((deposit) => _buildDepositCard(deposit, isDark)),
          ],
        ),
      ),
    );
  }

  // ==================== MISMATCH REPORT TAB ====================

  Widget _buildMismatchReportTab(bool isDark) {
    final dashboard = _dashboard!;
    final mismatchedDeposits = dashboard.deposits
        .where((d) => d.isMismatched)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mismatch Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber,
                      color: Color(0xFFEF4444),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${mismatchedDeposits.length} Mismatches Found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Discrepancies between POS and Leruma records',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Mismatch List
            Text(
              'Mismatch Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            if (mismatchedDeposits.isEmpty)
              _buildNoMismatches(isDark)
            else
              ...mismatchedDeposits.map((deposit) => _buildMismatchCard(deposit, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildMismatchCard(FinancialDeposit deposit, bool isDark) {
    final amountMismatch = deposit.amount != deposit.lerumaAmount;
    final refMismatch = deposit.referenceNumber != deposit.lerumaReference;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error,
            color: Colors.red,
            size: 24,
          ),
        ),
        title: Text(
          deposit.beneficiaryName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? AppColors.darkText : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              deposit.depositDate,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextLight : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (amountMismatch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Amount',
                      style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (refMismatch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Reference',
                      style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
        children: [
          // POS Record
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POS Record',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Amount', '${_currencyFormat.format(deposit.amount)} TZS', isDark),
                _buildDetailRow('Reference', deposit.referenceNumber, isDark),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Leruma Record
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leruma Record',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Amount',
                  deposit.lerumaAmount != null
                      ? '${_currencyFormat.format(deposit.lerumaAmount)} TZS'
                      : 'Not found',
                  isDark,
                  highlight: amountMismatch,
                ),
                _buildDetailRow(
                  'Reference',
                  deposit.lerumaReference ?? 'Not found',
                  isDark,
                  highlight: refMismatch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMismatches(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No mismatches found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextLight : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All records match between POS and Leruma',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextLight : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== MAKE DEPOSIT DIALOG ====================

  void _showMakeDepositDialog(BeneficiaryTarget target) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MakeDepositForm(
        target: target,
        startDate: _startDate,
        isDark: isDark,
        onSuccess: () {
          Navigator.pop(context);
          _loadDashboard();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deposit created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================

  Widget _buildSummaryCards(FinancialSummary summary, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Balance',
                amount: summary.totalBalance,
                icon: Icons.account_balance_wallet,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                title: 'Deposited',
                amount: summary.totalDeposited,
                icon: Icons.check_circle,
                color: const Color(0xFF10B981),
                isDark: isDark,
                percentage: summary.depositPercentage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Pending',
                amount: summary.pendingDeposits,
                icon: Icons.pending_actions,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryCard(
                title: 'Beneficiaries',
                count: summary.activeBeneficiaries,
                icon: Icons.people,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    double? amount,
    int? count,
    required IconData icon,
    required Color color,
    required bool isDark,
    double? percentage,
  }) {
    // Format large numbers with M/K suffix
    String formatValue(double value) {
      if (value >= 1000000) {
        return '${(value / 1000000).toStringAsFixed(2)}M';
      } else if (value >= 1000) {
        return '${(value / 1000).toStringAsFixed(1)}K';
      }
      return _currencyFormat.format(value);
    }

    return Container(
      height: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    amount != null ? formatValue(amount) : count.toString(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              if (percentage != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (percentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow(DepositStatistics stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', stats.totalTransactions, Colors.blue, isDark),
          _buildStatDivider(isDark),
          _buildStatItem('Verified', stats.verifiedCount, Colors.green, isDark),
          // Only show Mismatch if user has permission
          if (_canViewMismatchReport) ...[
            _buildStatDivider(isDark),
            _buildStatItem('Mismatch', stats.totalMismatches, Colors.red, isDark),
          ],
          _buildStatDivider(isDark),
          _buildStatItem('Pending', stats.totalPending, Colors.orange, isDark),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextLight : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      height: 30,
      width: 1,
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }

  Widget _buildDepositCard(FinancialDeposit deposit, bool isDark) {
    final statusColor = deposit.isVerified
        ? Colors.green
        : deposit.isMismatched
            ? Colors.red
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            deposit.isVerified
                ? Icons.check_circle
                : deposit.isMismatched
                    ? Icons.error
                    : Icons.pending,
            color: statusColor,
            size: 24,
          ),
        ),
        title: Text(
          deposit.beneficiaryName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? AppColors.darkText : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${_currencyFormat.format(deposit.amount)} TZS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  deposit.depositDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    deposit.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          // Expanded Details
          _buildDetailRow('Reference', deposit.referenceNumber, isDark),
          _buildDetailRow('Bank', deposit.bankName, isDark),
          _buildDetailRow('Account', deposit.accountNumber, isDark),
          _buildDetailRow('Supplier', deposit.supplierName, isDark),
          _buildDetailRow('EFD', deposit.efdName, isDark),
          _buildDetailRow('Payment', deposit.paymentMethod, isDark),
          if (deposit.lerumaAmount != null)
            _buildDetailRow(
              'Leruma Amount',
              '${_currencyFormat.format(deposit.lerumaAmount)} TZS',
              isDark,
              highlight: deposit.amount != deposit.lerumaAmount,
            ),
          if (deposit.lerumaReference != null)
            _buildDetailRow(
              'Leruma Ref',
              deposit.lerumaReference!,
              isDark,
              highlight: deposit.referenceNumber != deposit.lerumaReference,
            ),
          // Action Buttons (Edit/Delete)
          if (_canEditDeposit || _canDeleteDeposit) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_canEditDeposit)
                  ElevatedButton.icon(
                    onPressed: () => _showEditDepositDialog(deposit),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                if (_canEditDeposit && _canDeleteDeposit)
                  const SizedBox(width: 8),
                if (_canDeleteDeposit)
                  ElevatedButton.icon(
                    onPressed: () => _showDeleteDepositConfirmation(deposit),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Show edit deposit dialog
  Future<void> _showEditDepositDialog(FinancialDeposit deposit) async {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    // TODO: Implement full edit dialog with form fields
    // For now, show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Text(
          'Edit Deposit',
          style: TextStyle(
            color: isDark ? AppColors.darkText : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beneficiary: ${deposit.beneficiaryName}',
              style: TextStyle(
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: ${_currencyFormat.format(deposit.amount)} TZS',
              style: TextStyle(
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reference: ${deposit.referenceNumber}',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit functionality coming soon.',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show delete deposit confirmation dialog
  Future<void> _showDeleteDepositConfirmation(FinancialDeposit deposit) async {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Delete Deposit',
              style: TextStyle(
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this deposit?',
              style: TextStyle(
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deposit.beneficiaryName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkText : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_currencyFormat.format(deposit.amount)} TZS',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ref: ${deposit.referenceNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: const Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.darkTextLight : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteDeposit(deposit);
    }
  }

  /// Delete a deposit
  Future<void> _deleteDeposit(FinancialDeposit deposit) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final response = await _apiService.deleteDeposit(deposit.id);

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deposit deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload dashboard
          _loadDashboard();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Failed to delete deposit'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Hide loading if still showing
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value, bool isDark,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextLight : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: highlight
                    ? Colors.red
                    : isDark
                        ? AppColors.darkText
                        : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDeposits(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No deposits found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextLight : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting the date range or EFD filter',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextLight : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Summary cards skeleton
          Row(
            children: [
              Expanded(child: SkeletonStatCard(isDark: isDark)),
              const SizedBox(width: 8),
              Expanded(child: SkeletonStatCard(isDark: isDark)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SkeletonStatCard(isDark: isDark)),
              const SizedBox(width: 8),
              Expanded(child: SkeletonStatCard(isDark: isDark)),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row skeleton
          SkeletonLoader(width: double.infinity, height: 60, borderRadius: 12, isDark: isDark),
          const SizedBox(height: 16),
          // Items skeleton
          ...List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SkeletonLoader(width: double.infinity, height: 80, borderRadius: 12, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextLight : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
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
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: isDark ? Colors.grey[700] : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No Data Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Financial data will appear here once available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextLight : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== MAKE DEPOSIT FORM ====================

class _MakeDepositForm extends StatefulWidget {
  final BeneficiaryTarget target;
  final DateTime startDate;
  final bool isDark;
  final VoidCallback onSuccess;

  const _MakeDepositForm({
    required this.target,
    required this.startDate,
    required this.isDark,
    required this.onSuccess,
  });

  @override
  State<_MakeDepositForm> createState() => _MakeDepositFormState();
}

class _MakeDepositFormState extends State<_MakeDepositForm> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat = NumberFormat('#,###', 'en_US');
  final ImagePicker _imagePicker = ImagePicker();

  // Form controllers
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  // Form values
  BeneficiaryBankAccount? _selectedBankAccount;
  String _paymentMethod = 'BANK_TRANSFER';
  DateTime _depositDate = DateTime.now();
  DateTime _invoiceDate = DateTime.now();
  File? _attachmentFile;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _depositDate = widget.startDate;
    // Pre-select first bank account if available
    if (widget.target.bankAccounts.isNotEmpty) {
      _selectedBankAccount = widget.target.bankAccounts.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitDeposit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBankAccount == null) {
      setState(() => _errorMessage = 'Please select a bank account');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', ''));

      // Validate amount doesn't exceed remaining
      if (amount > widget.target.remainingAmount) {
        setState(() {
          _errorMessage =
              'Amount exceeds remaining amount (${_currencyFormat.format(widget.target.remainingAmount)} TZS)';
          _isSubmitting = false;
        });
        return;
      }

      final request = CreateDepositRequest(
        beneficiaryId: widget.target.beneficiaryId,
        supplierId: widget.target.supplierId,
        efdId: widget.target.efdId,
        amount: amount,
        depositDate: DateFormat('yyyy-MM-dd').format(_depositDate),
        invoiceDate: DateFormat('yyyy-MM-dd').format(_invoiceDate),
        referenceNumber: _referenceController.text.trim(),
        paymentMethod: _paymentMethod,
        bankName: _selectedBankAccount!.bankName,
        accountNumber: _selectedBankAccount!.accountNumber,
        beneficiaryAccountId: _selectedBankAccount!.beneficiaryAccountId,
        bankId: _selectedBankAccount!.bankId,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // Use API with attachment if file is selected
      final response = _attachmentFile != null
          ? await _apiService.createBankingDepositWithAttachment(
              request, _attachmentFile!.path)
          : await _apiService.createBankingDeposit(request);

      if (response.isSuccess) {
        widget.onSuccess();
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Failed to create deposit';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _selectDate(bool isDepositDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDepositDate ? _depositDate : _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: widget.isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDepositDate) {
          _depositDate = picked;
        } else {
          _invoiceDate = picked;
        }
      });
    }
  }

  Future<void> _pickAttachment() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() => _attachmentFile = File(image.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (image != null) {
                  setState(() => _attachmentFile = File(image.path));
                }
              },
            ),
            if (_attachmentFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Attachment', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _attachmentFile = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Make Deposit',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? AppColors.darkText : Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: widget.isDark ? AppColors.darkText : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Beneficiary Info (read-only)
                    _buildInfoCard(),

                    const SizedBox(height: 16),

                    // Bank Account Dropdown
                    _buildLabel('Bank Account *'),
                    DropdownButtonFormField<BeneficiaryBankAccount>(
                      value: _selectedBankAccount,
                      decoration: _inputDecoration('Select bank account'),
                      items: widget.target.bankAccounts.map((account) {
                        return DropdownMenuItem(
                          value: account,
                          child: Text('${account.bankName} - ${account.accountNumber}'),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedBankAccount = value),
                      validator: (value) =>
                          value == null ? 'Please select a bank account' : null,
                    ),

                    const SizedBox(height: 16),

                    // Remaining Amount Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Remaining: ${_currencyFormat.format(widget.target.remainingAmount)} TZS',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Deposit Amount
                    _buildLabel('Deposit Amount *'),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Enter amount'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter deposit amount';
                        }
                        final amount = double.tryParse(value.replaceAll(',', ''));
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        if (amount > widget.target.remainingAmount) {
                          return 'Amount exceeds remaining (${_currencyFormat.format(widget.target.remainingAmount)})';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Deposit Date
                    _buildLabel('Deposit Date *'),
                    InkWell(
                      onTap: () => _selectDate(true),
                      child: InputDecorator(
                        decoration: _inputDecoration(''),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('yyyy-MM-dd').format(_depositDate)),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Invoice Date
                    _buildLabel('Invoice Date *'),
                    InkWell(
                      onTap: () => _selectDate(false),
                      child: InputDecorator(
                        decoration: _inputDecoration(''),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('yyyy-MM-dd').format(_invoiceDate)),
                            const Icon(Icons.calendar_today, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Reference Number
                    _buildLabel('Reference Number *'),
                    TextFormField(
                      controller: _referenceController,
                      decoration: _inputDecoration('Enter reference number'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter reference number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Payment Method
                    _buildLabel('Payment Method *'),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: _inputDecoration(''),
                      items: const [
                        DropdownMenuItem(
                          value: 'BANK_TRANSFER',
                          child: Text('Bank Transfer'),
                        ),
                        DropdownMenuItem(
                          value: 'AGENT_BANKING',
                          child: Text('Agent Banking'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _paymentMethod = value);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    _buildLabel('Notes'),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: _inputDecoration('Optional notes'),
                    ),

                    const SizedBox(height: 16),

                    // Attachment
                    _buildLabel('Attachment (Receipt/Proof)'),
                    InkWell(
                      onTap: _pickAttachment,
                      child: Container(
                        height: _attachmentFile != null ? 200 : 100,
                        decoration: BoxDecoration(
                          color: widget.isDark ? AppColors.darkSurface : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: _attachmentFile != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _attachmentFile!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                        onPressed: () => setState(() => _attachmentFile = null),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 40,
                                    color: widget.isDark ? AppColors.darkTextLight : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap to upload receipt or proof',
                                    style: TextStyle(
                                      color: widget.isDark ? AppColors.darkTextLight : Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'JPG, PNG, PDF up to 5MB',
                                    style: TextStyle(
                                      color: widget.isDark ? AppColors.darkTextLight : Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // Error Message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitDeposit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit Deposit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Beneficiary', widget.target.beneficiaryName),
          const SizedBox(height: 8),
          _buildInfoRow('Supplier', widget.target.supplierName),
          if (widget.target.description != null &&
              widget.target.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Description', widget.target.description!),
          ],
          const SizedBox(height: 8),
          _buildInfoRow(
            'Total Target',
            '${_currencyFormat.format(widget.target.totalAmount)} TZS',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Already Deposited',
            '${_currencyFormat.format(widget.target.depositedAmount)} TZS',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: widget.isDark ? AppColors.darkTextLight : Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? AppColors.darkText : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: widget.isDark ? AppColors.darkText : Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: widget.isDark ? AppColors.darkSurface : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// Helper class for navigation items
class _NavItem {
  final IconData icon;
  final String label;
  final int index;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}
