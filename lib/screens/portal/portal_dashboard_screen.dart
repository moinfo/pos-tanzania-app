import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';
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
  }

  Future<void> _logout() async {
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
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) {
        final tabs = [
          _buildDashboardTab(),
          _buildMikatabaTab(),
          _buildContractScopedTab(
            icon: Icons.receipt_long,
            emptyKey: 'no_contract_for_payments',
            builder: (contract) => PortalPaymentsScreen(contract: contract),
          ),
          _buildContractScopedTab(
            icon: Icons.description_outlined,
            emptyKey: 'no_contract_for_statement',
            builder: (contract) => PortalStatementScreen(contract: contract),
          ),
          _buildAccountTab(),
        ];

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          body: SafeArea(child: tabs[_tabIndex]),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tabIndex,
            onTap: (i) => setState(() => _tabIndex = i),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textLight,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 10.5,
            unselectedFontSize: 10,
            items: [
              BottomNavigationBarItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  activeIcon: const Icon(Icons.dashboard),
                  label: PortalStrings.t('dashboard')),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.two_wheeler_outlined),
                  activeIcon: const Icon(Icons.two_wheeler),
                  label: PortalStrings.t('mikataba')),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.receipt_long_outlined),
                  activeIcon: const Icon(Icons.receipt_long),
                  label: PortalStrings.t('malipo')),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.description_outlined),
                  activeIcon: const Icon(Icons.description),
                  label: PortalStrings.t('taarifa')),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: PortalStrings.t('account')),
            ],
          ),
        );
      },
    );
  }

  // ── Dashboard: summary only ───────────────────────────────────────────

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildSummary(),
    );
  }

  Widget _buildSummary() {
    final contracts = _contracts ?? [];
    final activeContracts = contracts.where((c) => !c.isTerminated).toList();
    final totalOwed = activeContracts.fold<double>(
        0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0));
    final totalPaid = contracts.fold<double>(0, (sum, c) => sum + c.payments);
    final overdueCount =
        activeContracts.where((c) => c.currentUnpaid > 0).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: PortalLanguageSwitch.themed(dark: true),
        ),
        _buildHero(totalOwed),
        if (contracts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _summaryTile(Icons.two_wheeler, '${contracts.length}',
                      PortalStrings.t('mikataba'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryTile(
                      Icons.payments_outlined,
                      'TSH ${Formatters.formatCurrency(totalPaid)}',
                      PortalStrings.t('paid_so_far'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _summaryTile(Icons.warning_amber_rounded,
                      '$overdueCount', PortalStrings.t('days_overdue'))),
            ],
          ),
        ] else
          _buildEmpty(),
      ],
    );
  }

  Widget _summaryTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 9.5, color: AppColors.textLight),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.receipt_long, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Text(PortalStrings.t('no_contracts')),
          const SizedBox(height: 4),
          Text(_phone, style: const TextStyle(color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildHero(double totalOwed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 6),
          if (totalOwed > 0)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('TSH ',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
                Text(Formatters.formatCurrency(totalOwed),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ],
            )
          else
            Text(PortalStrings.t('fully_paid'),
                style: const TextStyle(
                    color: Color(0xFF6FCF97),
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
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

  Widget _buildMikatabaTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContractList(),
    );
  }

  Widget _buildContractList() {
    final contracts = _contracts ?? [];
    if (contracts.isEmpty) {
      return ListView(children: [_buildEmpty()]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(PortalStrings.t('your_contracts'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
                const SizedBox(width: 6),
                Text('(${contracts.length})',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textLight)),
              ],
            ),
            const PortalLanguageSwitch.themed(dark: true),
          ],
        ),
        const SizedBox(height: 4),
        ...contracts.map(_buildContractCard),
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
              Icon(icon, size: 48, color: AppColors.textLight),
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
        if (contracts.length > 1) _buildContractSwitcher(contracts, index),
        Expanded(child: builder(selected)),
      ],
    );
  }

  /// A tappable chip naming the contract in scope, opening a sheet to pick
  /// a different one -- only shown when there's more than one, so most
  /// customers (one contract) never see it.
  Widget _buildContractSwitcher(List<Contract> contracts, int index) {
    final selected = contracts[index];
    final label = selected.contractDescription.isNotEmpty
        ? selected.contractDescription
        : '${PortalStrings.t('contract_label')} #${selected.id}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pickContract(contracts, index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.lightBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
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
              const Icon(Icons.unfold_more,
                  size: 18, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickContract(List<Contract> contracts, int current) async {
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < contracts.length; i++)
              ListTile(
                leading: Icon(Icons.two_wheeler,
                    color:
                        i == current ? AppColors.primary : AppColors.textLight),
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

  Widget _buildContractCard(Contract contract) {
    final status = contract.status;
    final amount = contract.contractAmount;
    final paidFraction = amount > 0
        ? ((amount - contract.balance) / amount).clamp(0.0, 1.0)
        : 0.0;
    final statusStyle = _statusStyle(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
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
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                  if (status == 'completed')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
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
                            style: const TextStyle(
                                fontSize: 10.5, color: AppColors.textLight)),
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
                  backgroundColor: Colors.grey.shade200,
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
                      color: statusStyle.color.withOpacity(0.1),
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
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
                ],
              ),
              const Divider(height: 20),
              _buildMiniStats(contract),
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
  Widget _buildMiniStats(Contract contract) {
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
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textLight)),
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

  Widget _buildAccountTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: PortalLanguageSwitch.themed(dark: true),
        ),
        const SizedBox(height: 4),
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withOpacity(0.1),
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
              style: const TextStyle(color: AppColors.textLight)),
        ),
        const SizedBox(height: 32),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
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
            side: BorderSide(color: Colors.grey.shade200),
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
