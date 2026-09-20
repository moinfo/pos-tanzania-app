import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'portal_change_password_screen.dart';
import 'portal_contract_detail_screen.dart';
import 'portal_login_screen.dart';
import 'portal_payments_screen.dart';
import 'portal_statement_screen.dart';

/// Customer portal shell: bottom-nav Dashboard / Malipo / Taarifa / Account
/// -- previously a single bare list with only a logout icon, and Malipo/
/// Taarifa hidden behind a "..." menu on the contract detail screen that
/// wasn't visible/discoverable enough, moved here so they're always one
/// tap away.
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
    final tabs = [
      _buildDashboardTab(),
      _buildContractScopedTab(
        icon: Icons.receipt_long,
        emptyLabel: 'Hakuna mkataba wa kuonyesha malipo yake.',
        builder: (contract) => PortalPaymentsScreen(contract: contract),
      ),
      _buildContractScopedTab(
        icon: Icons.description_outlined,
        emptyLabel: 'Hakuna mkataba wa kuonyesha taarifa yake.',
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
        selectedFontSize: 11,
        unselectedFontSize: 10.5,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Malipo'),
          BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Taarifa'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Account'),
        ],
      ),
    );
  }

  /// Malipo/Taarifa belong to a specific contract, not the account as a
  /// whole -- shows a contract picker above the tab when there's more than
  /// one, otherwise goes straight to the customer's only contract.
  Widget _buildContractScopedTab({
    required IconData icon,
    required String emptyLabel,
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
              Text(emptyLabel, textAlign: TextAlign.center),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<int>(
              initialValue: index,
              decoration: const InputDecoration(
                labelText: 'Mkataba',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                for (var i = 0; i < contracts.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      contracts[i].contractDescription.isNotEmpty
                          ? contracts[i].contractDescription
                          : 'Mkataba #${contracts[i].id}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (i) => setState(() => _selectedContractIndex = i ?? 0),
            ),
          ),
        Expanded(child: builder(selected)),
      ],
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildList(),
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

  Widget _buildList() {
    final contracts = _contracts ?? [];
    final activeContracts = contracts.where((c) => !c.isTerminated).toList();
    final totalOwed = activeContracts.fold<double>(
        0, (sum, c) => sum + (c.balance > 0 ? c.balance : 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _buildHero(totalOwed),
        const SizedBox(height: 20),
        if (contracts.isNotEmpty) ...[
          Row(
            children: [
              const Text('Mikataba Yako',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
              const SizedBox(width: 6),
              Text('(${contracts.length})',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textLight)),
            ],
          ),
          const SizedBox(height: 12),
          ...contracts.map(_buildContractCard),
        ] else
          _buildEmpty(),
      ],
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.receipt_long, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          const Text('No contracts found for this phone number.'),
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
          Text(_tenantName.isEmpty ? 'Deni lako lote kwa sasa' : _tenantName,
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
            const Text('Umeshalipa deni lako lote',
                style: TextStyle(
                    color: Color(0xFF6FCF97),
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Namba ya simu: $_phone',
              style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
        ],
      ),
    );
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
                              : 'Mkataba #${contract.id}',
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
                      child: const Text('Imelipwa',
                          style: TextStyle(
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
                        const Text('salio',
                            style: TextStyle(
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
                  Text('${(paidFraction * 100).round()}% imelipwa',
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
      ('Siku ya mkataba', 'Siku ${contract.days}'),
      (
        'Amepitisha siku',
        contract.daysUnpaid > 0
            ? '${contract.daysUnpaid.toInt()} siku'
            : 'Hakuna'
      ),
      (
        'Amelipa hadi sasa',
        'TSH ${Formatters.formatCurrency(contract.payments)}'
      ),
      (
        'Salio linalobaki',
        'TSH ${Formatters.formatCurrency(contract.balance)}'
      ),
      (
        'Anadaiwa hadi leo',
        'TSH ${Formatters.formatCurrency(contract.currentUnpaid)}'
      ),
      (
        'Kiwango cha kila siku',
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
        return (color: Colors.grey, label: 'Umesitishwa');
      case 'completed':
        return (color: AppColors.success, label: 'Imelipwa kamili');
      case 'on_track':
        return (color: AppColors.success, label: 'Inaendelea vizuri');
      case 'behind':
        return (color: AppColors.warning, label: 'Umechelewa');
      default:
        return (color: AppColors.error, label: 'Umechelewa sana');
    }
  }

  Widget _buildAccountTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
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
            title: const Text('Badilisha Password'),
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
            title: const Text('Toka', style: TextStyle(color: AppColors.error)),
            onTap: _logout,
          ),
        ),
      ],
    );
  }
}
