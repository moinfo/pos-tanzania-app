import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/customer_api_service.dart';
import '../../services/push_service.dart';
import '../../models/contract.dart';
import '../../models/portal_contract_detail.dart';
import '../../models/monthly_payment_total.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../widgets/curved_bottom_navigation.dart';
import '../../widgets/portal_top_bar.dart';
import 'portal_change_password_screen.dart';
import 'portal_contract_detail_screen.dart';
import 'portal_login_screen.dart';
import 'portal_payments_screen.dart';
import 'portal_statement_screen.dart';

/// Customer portal shell: bottom-nav Dashboard / Mikataba / Malipo / Taarifa
/// / Account. Dashboard is a summary only (total balance owed); the full
/// contract list lives in its own Mikataba tab -- previously Dashboard did
/// both jobs at once, and Malipo/Taarifa were hidden behind a "..." menu on
/// the contract detail screen that wasn't discoverable.
class PortalDashboardScreen extends StatefulWidget {
  const PortalDashboardScreen({super.key});

  @override
  State<PortalDashboardScreen> createState() => _PortalDashboardScreenState();
}

class _PortalDashboardScreenState extends State<PortalDashboardScreen> {
  final _service = CustomerApiService();
  List<Contract>? _contracts;
  bool _isLoading = true;
  String? _error;
  String _tenantName = '';
  String _phone = '';
  int _tabIndex = 0;
  int _selectedContractIndex = 0;

  /// The contract the Dashboard's chart section focuses on -- the first
  /// still-active one (not paid off, not terminated), so the customer sees
  /// the contract that actually needs their attention rather than an old
  /// completed one. Falls back to the first contract if all are settled.
  PortalContractDetail? _currentContractDetail;
  bool _isLoadingCurrentContract = false;

  /// Monthly totals across ALL of the customer's contracts, independent of
  /// which one is "current" -- shown even when the current contract itself
  /// has no payments yet (e.g. a brand-new renewal).
  List<MonthlyPaymentTotal>? _paymentHistory;
  bool _isLoadingPaymentHistory = false;

  @override
  void initState() {
    super.initState();
    PortalLocale.instance.load();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final tenantName = await _service.getTenantName();
    final phone = await _service.getPhone();
    final response = await _service.getContracts();

    if (!mounted) return;
    setState(() {
      _tenantName = tenantName ?? '';
      _phone = phone ?? '';
      _isLoading = false;
      if (response.isSuccess) {
        _contracts = response.data;
      } else {
        _error = response.message;
      }
    });

    _loadCurrentContractDetail();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoadingPaymentHistory = true);
    final response = await _service.getPaymentHistory(months: 6);
    if (!mounted) return;
    setState(() {
      _isLoadingPaymentHistory = false;
      if (response.isSuccess) _paymentHistory = response.data;
    });
  }

  Future<void> _loadCurrentContractDetail() async {
    final contracts = _contracts ?? [];
    if (contracts.isEmpty) return;
    final current = contracts.firstWhere(
      (c) => !c.isTerminated && !c.isCompleted,
      orElse: () => contracts.first,
    );

    setState(() => _isLoadingCurrentContract = true);
    final response = await _service.getContractDetail(current.id);
    if (!mounted) return;
    setState(() {
      _isLoadingCurrentContract = false;
      if (response.isSuccess) _currentContractDetail = response.data;
    });
  }

  Future<void> _logout() async {
    await PushService.instance.unregisterCustomer();
    await _service.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PortalLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) {
        final tabs = [
          _buildDashboardTab(isDark),
          _buildMikatabaTab(isDark),
          _buildContractScopedTab(
            icon: Icons.receipt_long,
            emptyKey: 'no_contract_for_payments',
            isDark: isDark,
            builder: (contract) =>
                PortalPaymentsScreen(contract: contract, embedded: true),
          ),
          _buildContractScopedTab(
            icon: Icons.description_outlined,
            emptyKey: 'no_contract_for_statement',
            isDark: isDark,
            builder: (contract) =>
                PortalStatementScreen(contract: contract, embedded: true),
          ),
          _buildAccountTab(isDark),
        ];

        return Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: PortalTopBar(tenantName: _tenantName),
          body: tabs[_tabIndex],
          bottomNavigationBar: CurvedBottomNavigation(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            selectedItemColor: AppColors.primary,
            unselectedItemColor:
                isDark ? AppColors.darkTextLight : AppColors.textLight,
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            items: [
              CurvedNavItem(
                  icon: Icons.dashboard_outlined,
                  label: PortalStrings.t('dashboard')),
              CurvedNavItem(
                  icon: Icons.two_wheeler_outlined,
                  label: PortalStrings.t('mikataba')),
              CurvedNavItem(
                  icon: Icons.receipt_long_outlined,
                  label: PortalStrings.t('malipo')),
              CurvedNavItem(
                  icon: Icons.description_outlined,
                  label: PortalStrings.t('taarifa')),
              CurvedNavItem(
                  icon: Icons.person_outline,
                  label: PortalStrings.t('account')),
            ],
          ),
        );
      },
    );
  }

  // ── Dashboard: summary only ───────────────────────────────────────────

  Widget _buildDashboardTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildSummary(isDark),
    );
  }

  Widget _buildSummary(bool isDark) {
    final contracts = _contracts ?? [];
    final activeContracts = contracts.where((c) => !c.isTerminated).toList();
    final totalOwed = activeContracts.fold<double>(
        0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0));
    final totalPaid = contracts.fold<double>(0, (sum, c) => sum + c.payments);
    final overdueCount =
        activeContracts.where((c) => c.currentUnpaid > 0).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      children: [
        _buildHero(totalOwed),
        if (contracts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _summaryTile(Icons.two_wheeler, '${contracts.length}',
                      PortalStrings.t('mikataba'), isDark)),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryTile(
                      Icons.payments_outlined,
                      'TSH ${Formatters.formatCurrency(totalPaid)}',
                      PortalStrings.t('paid_so_far'),
                      isDark)),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryTile(
                      Icons.warning_amber_rounded,
                      '$overdueCount',
                      PortalStrings.t('overdue_contracts_count'),
                      isDark)),
            ],
          ),
          const SizedBox(height: 10),
          _buildCurrentContractSection(isDark),
          const SizedBox(height: 8),
          _buildPaymentHistorySection(isDark),
        ] else
          _buildEmpty(isDark),
      ],
    );
  }

  Widget _buildCurrentContractSection(bool isDark) {
    if (_isLoadingCurrentContract) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final detail = _currentContractDetail;
    if (detail == null) return const SizedBox.shrink();
    final c = detail.contract;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PortalContractDetailScreen(contract: c),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(PortalStrings.t('current_contract'),
                          style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                              fontWeight: FontWeight.w600)),
                      Text(
                          c.contractDescription.isNotEmpty
                              ? c.contractDescription
                              : '${PortalStrings.t('contract_label')} #${c.id}',
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color:
                        isDark ? AppColors.darkTextLight : AppColors.textLight,
                    size: 20),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildPaidDonut(c, isDark),
              const SizedBox(width: 16),
              Expanded(child: _buildCurrentContractStats(c, isDark)),
            ],
          ),
          if (detail.paymentsList.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(PortalStrings.t('recent_payments'),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.darkTextLight
                        : AppColors.textLight)),
            const SizedBox(height: 6),
            SizedBox(
                height: 72,
                child: _buildRecentPaymentsChart(detail.paymentsList, isDark)),
          ],
        ],
      ),
    );
  }

  /// Monthly totals across every contract the customer has ever had here,
  /// not just the "current" one -- so it still shows something meaningful
  /// even when the current contract is brand new and has no payments yet.
  Widget _buildPaymentHistorySection(bool isDark) {
    if (_isLoadingPaymentHistory) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final history = _paymentHistory;
    if (history == null || history.isEmpty) return const SizedBox.shrink();

    final total = history.fold<double>(0, (sum, m) => sum + m.total);
    if (total <= 0) return const SizedBox.shrink();

    final maxTotal =
        history.map((m) => m.total).fold<double>(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(PortalStrings.t('payment_history'),
              style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('TSH ${Formatters.formatCurrency(total)}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Fixed height chosen to comfortably fit the bar-plot area PLUS
          // the full reserved height for the bottom month-label row below
          // it -- previously the reserved size was tight enough that the
          // labels (esp. at larger system font scales) got clipped by this
          // SizedBox's bottom edge instead of shrinking the bar area, so
          // they silently rendered off-screen with no scroll affordance.
          SizedBox(
            height: 112,
            child: BarChart(
              BarChartData(
                maxY: maxTotal > 0 ? maxTotal * 1.2 : 1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        'TSH ${Formatters.formatCurrency(rod.toY)}',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= history.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_monthLabel(history[i].month),
                              style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark
                                      ? AppColors.darkTextLight
                                      : AppColors.textLight)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < history.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: history[i].total,
                        color: history[i].total > 0
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkDivider
                                : Colors.grey.shade200),
                        width: 22,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthLabel(String ym) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final parts = ym.split('-');
    if (parts.length != 2) return ym;
    final monthIndex = int.tryParse(parts[1]);
    if (monthIndex == null || monthIndex < 1 || monthIndex > 12) return ym;
    return months[monthIndex - 1];
  }

  Widget _buildPaidDonut(Contract c, bool isDark) {
    final amount = c.contractAmount;
    final paid = amount > 0 ? (amount - c.balance).clamp(0, amount) : 0;
    final remaining = amount > 0 ? c.balance.clamp(0, amount) : 0;
    final pct = amount > 0 ? (paid / amount * 100).round() : 0;

    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: amount > 0 ? 2 : 0,
              centerSpaceRadius: 28,
              sections: amount > 0
                  ? [
                      PieChartSectionData(
                          value: paid.toDouble(),
                          color: AppColors.success,
                          showTitle: false,
                          radius: 14),
                      PieChartSectionData(
                          value: remaining.toDouble(),
                          color: isDark
                              ? AppColors.darkDivider
                              : Colors.grey.shade200,
                          showTitle: false,
                          radius: 14),
                    ]
                  : [
                      PieChartSectionData(
                          value: 1,
                          color: isDark
                              ? AppColors.darkDivider
                              : Colors.grey.shade200,
                          showTitle: false,
                          radius: 14),
                    ],
            ),
          ),
          Text('$pct%',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCurrentContractStats(Contract c, bool isDark) {
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statLine(PortalStrings.t('balance_remaining'),
            'TSH ${Formatters.formatCurrency(c.balance)}', textColor, isDark),
        const SizedBox(height: 2),
        _statLine(
            PortalStrings.t('owed_today'),
            'TSH ${Formatters.formatCurrency(c.currentUnpaid)}',
            c.currentUnpaid > 0 ? AppColors.error : AppColors.success,
            isDark),
        const SizedBox(height: 2),
        _statLine(PortalStrings.t('day_of_contract'),
            PortalStrings.t('n_days', {'0': '${c.days}'}), textColor, isDark),
      ],
    );
  }

  Widget _statLine(String label, String value, Color valueColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9.5,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildRecentPaymentsChart(List<PortalPayment> payments, bool isDark) {
    final recent =
        payments.length > 6 ? payments.sublist(payments.length - 6) : payments;
    final maxAmount =
        recent.map((p) => p.amount).fold<double>(0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxAmount > 0 ? maxAmount * 1.2 : 1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= recent.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_shortDate(recent[i].date),
                      style: TextStyle(
                          fontSize: 9,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < recent.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: recent[i].amount,
                color: AppColors.primary,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
      ),
    );
  }

  String _shortDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _summaryTile(IconData icon, String value, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 9.5,
                  color:
                      isDark ? AppColors.darkTextLight : AppColors.textLight),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    final textLight = isDark ? AppColors.darkTextLight : AppColors.textLight;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.receipt_long, size: 48, color: textLight),
          const SizedBox(height: 12),
          Text(PortalStrings.t('no_contracts')),
          const SizedBox(height: 4),
          Text(_phone, style: TextStyle(color: textLight)),
        ],
      ),
    );
  }

  Widget _buildHero(double totalOwed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2C45), Color(0xFF2C4165)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              _tenantName.isEmpty
                  ? PortalStrings.t('total_owed_label')
                  : _tenantName,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (totalOwed > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('TSH ',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text(Formatters.formatCurrency(totalOwed),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            )
          else
            Text(PortalStrings.t('fully_paid'),
                style: const TextStyle(
                    color: Color(0xFF6FCF97),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(PortalStrings.t('phone_number_colon', {'0': _phone}),
              style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  // ── Mikataba: full contract list ──────────────────────────────────────

  Widget _buildMikatabaTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContractList(isDark),
    );
  }

  Widget _buildContractList(bool isDark) {
    final contracts = _contracts ?? [];
    if (contracts.isEmpty) {
      return ListView(children: [_buildEmpty(isDark)]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Text(PortalStrings.t('your_contracts'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.text)),
            const SizedBox(width: 6),
            Text('(${contracts.length})',
                style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextLight
                        : AppColors.textLight)),
          ],
        ),
        const SizedBox(height: 4),
        ...contracts.map((c) => _buildContractCard(c, isDark)),
      ],
    );
  }

  // ── Malipo / Taarifa: scoped to one contract ──────────────────────────

  /// Malipo/Taarifa belong to a specific contract, not the account as a
  /// whole -- shows a contract picker above the tab when there's more than
  /// one, otherwise goes straight to the customer's only contract.
  Widget _buildContractScopedTab({
    required IconData icon,
    required String emptyKey,
    required bool isDark,
    required Widget Function(Contract contract) builder,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final contracts = _contracts ?? [];
    if (contracts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 48,
                  color:
                      isDark ? AppColors.darkTextLight : AppColors.textLight),
              const SizedBox(height: 12),
              Text(PortalStrings.t(emptyKey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    final index =
        _selectedContractIndex < contracts.length ? _selectedContractIndex : 0;
    final selected = contracts[index];

    return Column(
      children: [
        if (contracts.length > 1)
          _buildContractSwitcher(contracts, index, isDark),
        Expanded(child: builder(selected)),
      ],
    );
  }

  /// A tappable chip naming the contract in scope, opening a sheet to pick
  /// a different one -- only shown when there's more than one, so most
  /// customers (one contract) never see it.
  Widget _buildContractSwitcher(
      List<Contract> contracts, int index, bool isDark) {
    final selected = contracts[index];
    final label = selected.contractDescription.isNotEmpty
        ? selected.contractDescription
        : '${PortalStrings.t('contract_label')} #${selected.id}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pickContract(contracts, index, isDark),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isDark ? AppColors.darkDivider : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.two_wheeler, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(Icons.unfold_more,
                  size: 18,
                  color:
                      isDark ? AppColors.darkTextLight : AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickContract(
      List<Contract> contracts, int current, bool isDark) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < contracts.length; i++)
              ListTile(
                leading: Icon(Icons.two_wheeler,
                    color: i == current
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight)),
                title: Text(
                  contracts[i].contractDescription.isNotEmpty
                      ? contracts[i].contractDescription
                      : '${PortalStrings.t('contract_label')} #${contracts[i].id}',
                  style: TextStyle(
                      fontWeight:
                          i == current ? FontWeight.bold : FontWeight.normal),
                ),
                trailing: i == current
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, i),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) setState(() => _selectedContractIndex = choice);
  }

  Widget _buildContractCard(Contract contract, bool isDark) {
    final status = contract.status;
    final amount = contract.contractAmount;
    final paidFraction = amount > 0
        ? ((amount - contract.balance) / amount).clamp(0.0, 1.0)
        : 0.0;
    final statusStyle = _statusStyle(status);
    final textLight = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PortalContractDetailScreen(contract: contract),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contract.contractDescription.isNotEmpty
                              ? contract.contractDescription
                              : '${PortalStrings.t('contract_label')} #${contract.id}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        const SizedBox(height: 2),
                        Text('${contract.date} → ${contract.endDate}',
                            style: TextStyle(fontSize: 11.5, color: textLight)),
                      ],
                    ),
                  ),
                  if (status == 'completed')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            AppColors.success.withOpacity(isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.4)),
                      ),
                      child: Text(PortalStrings.t('status_completed'),
                          style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                            'TSH ${Formatters.formatCurrency(contract.balance)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text(PortalStrings.t('balance_label'),
                            style: TextStyle(fontSize: 10.5, color: textLight)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: paidFraction,
                  minHeight: 6,
                  backgroundColor:
                      isDark ? AppColors.darkDivider : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(statusStyle.color),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusStyle.color.withOpacity(isDark ? 0.22 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusStyle.label,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: statusStyle.color)),
                  ),
                  Text(
                      PortalStrings.t('percent_paid',
                          {'0': (paidFraction * 100).round().toString()}),
                      style: TextStyle(fontSize: 11, color: textLight)),
                ],
              ),
              const Divider(height: 20),
              _buildMiniStats(contract, isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// At-a-glance daily status the customer would otherwise have to tap
  /// into the contract to see: which day of the contract today is, what's
  /// been paid/remains, what's overdue as of today, the daily obligation,
  /// and how many days behind (if any).
  Widget _buildMiniStats(Contract contract, bool isDark) {
    final stats = <(String, String)>[
      (
        PortalStrings.t('day_of_contract'),
        PortalStrings.t('n_days', {'0': '${contract.days}'})
      ),
      (
        PortalStrings.t('days_overdue'),
        contract.daysUnpaid > 0
            ? PortalStrings.t(
                'n_days', {'0': contract.daysUnpaid.toInt().toString()})
            : PortalStrings.t('none')
      ),
      (
        PortalStrings.t('paid_so_far'),
        'TSH ${Formatters.formatCurrency(contract.payments)}'
      ),
      (
        PortalStrings.t('balance_remaining'),
        'TSH ${Formatters.formatCurrency(contract.balance)}'
      ),
      (
        PortalStrings.t('owed_today'),
        'TSH ${Formatters.formatCurrency(contract.currentUnpaid)}'
      ),
      (
        PortalStrings.t('daily_rate_label'),
        'TSH ${Formatters.formatCurrency(contract.returnAmount)}'
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 12,
      childAspectRatio: 3.4,
      children: stats
          .map((s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.$1,
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight)),
                  Text(s.$2,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ))
          .toList(),
    );
  }

  ({Color color, String label}) _statusStyle(String status) {
    switch (status) {
      case 'terminated':
        return (
          color: Colors.grey,
          label: PortalStrings.t('status_terminated')
        );
      case 'completed':
        return (
          color: AppColors.success,
          label: PortalStrings.t('status_completed')
        );
      case 'on_track':
        return (
          color: AppColors.success,
          label: PortalStrings.t('status_on_track')
        );
      case 'behind':
        return (
          color: AppColors.warning,
          label: PortalStrings.t('status_behind')
        );
      default:
        return (
          color: AppColors.error,
          label: PortalStrings.t('status_overdue')
        );
    }
  }

  // ── Account ────────────────────────────────────────────────────────

  Widget _buildAccountTab(bool isDark) {
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withOpacity(isDark ? 0.22 : 0.1),
            child: const Icon(Icons.person, size: 36, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(_phone,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(_tenantName,
              style: TextStyle(
                  color:
                      isDark ? AppColors.darkTextLight : AppColors.textLight)),
        ),
        const SizedBox(height: 32),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          child: ListTile(
            leading: const Icon(Icons.lock_outline, color: AppColors.primary),
            title: Text(PortalStrings.t('change_password_tile')),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PortalChangePasswordScreen()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: Text(PortalStrings.t('logout'),
                style: const TextStyle(color: AppColors.error)),
            onTap: _logout,
          ),
        ),
      ],
    );
  }
}
