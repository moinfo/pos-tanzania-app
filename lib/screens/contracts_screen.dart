import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/permission_provider.dart';
import '../services/api_service.dart';
import '../models/contract.dart';
import '../models/permission_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../widgets/skeleton_loader.dart';
import 'contract_details_screen.dart';
import 'contract_form_screen.dart';
import 'contract_settings_screen.dart';
import 'contracts/contract_theme.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  final ApiService _apiService = ApiService();
  List<Contract>? _contracts;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showCompleted = false;
  String _statusFilter = 'all'; // all / behind / on_track / completed / terminated
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesStatusFilter(Contract c) {
    switch (_statusFilter) {
      case 'behind':
        return c.status != 'on_track' && c.status != 'completed' && c.status != 'terminated';
      case 'on_track':
        return c.status == 'on_track';
      case 'completed':
        return c.status == 'completed';
      case 'terminated':
        return c.status == 'terminated';
      default:
        return true;
    }
  }

  List<Contract> get _visibleContracts {
    final query = _searchQuery.trim().toLowerCase();
    return _contracts!.where((c) {
      if (!_matchesStatusFilter(c)) return false;
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query) ||
          c.phone.toLowerCase().contains(query) ||
          (c.assetPlateNumber ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _apiService.getContracts();

    setState(() {
      if (result.isSuccess && result.data != null) {
        _contracts = result.data!;
        _errorMessage = null;
      } else {
        _contracts = null;
        _errorMessage = result.message ?? 'Failed to load contracts';
      }
      _isLoading = false;
    });
  }

  Future<void> _openNewContract({Contract? renewFrom}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ContractFormScreen(renewFrom: renewFrom)),
    );
    if (saved == true) _loadContracts();
  }

  /// Awaits the detail screen's pop value -- it pops `true` after a renewal
  /// started from inside it, so the list picks up the new contract too.
  Future<void> _openDetails(Contract contract) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ContractDetailsScreen(contract: contract)),
    );
    if (changed == true) _loadContracts();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final canAdd = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.contractsAdd);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: ContractTheme.appBar(
        isDark: isDark,
        eyebrow: 'Portfolio',
        title: 'Contracts',
        actions: [
          if (canAdd)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Contract Rules',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ContractSettingsScreen()),
              ),
            ),
        ],
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _openNewContract(),
              icon: const Icon(Icons.add),
              label: const Text('New Contract'),
              backgroundColor: AppColors.warning,
              foregroundColor: AppColors.secondary,
            )
          : null,
      body: _isLoading
          ? _buildSkeletonList(isDark)
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadContracts,
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
                )
              : _contracts == null || _contracts!.isEmpty
                  ? const Center(child: Text('No contracts available'))
                  : RefreshIndicator(
                      onRefresh: _loadContracts,
                      child: _buildContractsList(isDark),
                    ),
    );
  }

  /// Completed contracts are done -- collapsed into a single "Completed"
  /// section by default so a tenant with a long history isn't scrolling
  /// past dozens of finished contracts to see the ones still active.
  Widget _buildContractsList(bool isDark) {
    final visible = _visibleContracts;
    final active = visible.where((c) => c.status != 'completed').toList();
    final completed = visible.where((c) => c.status == 'completed').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSearchAndFilters(isDark),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('No contracts match this filter',
                  style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
            ),
          )
        else ...[
          ...active.map((c) => _buildContractCard(c, isDark)),
          if (completed.isNotEmpty) _buildCompletedSection(completed, isDark),
        ],
      ],
    );
  }

  /// Search by name/phone/plate plus the same five status filters the web
  /// list's chip row has (All/Behind/On track/Completed/Terminated) --
  /// counts come from the full unfiltered list so they stay stable as a
  /// reference while a filter/search narrows what's shown below.
  Widget _buildSearchAndFilters(bool isDark) {
    final all = _contracts!;
    final counts = {
      'all': all.length,
      'behind': all.where((c) =>
          c.status != 'on_track' && c.status != 'completed' && c.status != 'terminated').length,
      'on_track': all.where((c) => c.status == 'on_track').length,
      'completed': all.where((c) => c.status == 'completed').length,
      'terminated': all.where((c) => c.status == 'terminated').length,
    };
    final labels = {
      'all': 'All',
      'behind': 'Behind',
      'on_track': 'On track',
      'completed': 'Completed',
      'terminated': 'Terminated',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          style: ContractTheme.body(size: 15),
          decoration: InputDecoration(
            hintText: 'Search name, phone or plate...',
            hintStyle: ContractTheme.body(size: 15, color: AppColors.lightTextLight),
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            filled: true,
            fillColor: isDark ? AppColors.darkCard : Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightTextLight)),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labels.entries.map((e) {
            final selected = _statusFilter == e.key;
            return GestureDetector(
              onTap: () => setState(() => _statusFilter = e.key),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.secondary : (isDark ? AppColors.darkCard : Colors.white),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: selected
                          ? AppColors.secondary
                          : (isDark ? AppColors.darkDivider : AppColors.lightTextLight)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                    ],
                    Text('${e.value} ${counts[e.key]}',
                        style: ContractTheme.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: selected ? Colors.white : (isDark ? AppColors.darkText : AppColors.text))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCompletedSection(List<Contract> completed, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showCompleted = !_showCompleted),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        'Completed (${completed.length})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showCompleted ? Icons.expand_less : Icons.expand_more,
                    color:
                        isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
          if (_showCompleted)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: completed
                    .map((c) => _buildContractCard(c, isDark))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContractCard(Contract contract, bool isDark) {
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final canAdd = context.watch<PermissionProvider>().hasPermission(PermissionIds.contractsAdd);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openDetails(contract),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
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
                      Text(contract.name,
                          style: ContractTheme.display(size: 22, weight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          if (contract.phone.isNotEmpty)
                            _metaChip(Icons.call_outlined, contract.phone, subColor),
                          if (contract.contractDescription.isNotEmpty)
                            _metaChip(Icons.two_wheeler_outlined, contract.contractDescription, subColor),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(contract),
              ],
            ),
            const SizedBox(height: 14),
            ContractDayStrip(
              daysPaid: contract.daysPaid.round(),
              daysUnpaid: contract.daysUnpaid.round(),
              totalDays: contract.days,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDayInfo('Days', contract.days.toString(), textColor, subColor)),
                Expanded(
                    child: _buildDayInfo('Paid', contract.daysPaid.toStringAsFixed(0), const Color(0xFF047857), subColor)),
                Expanded(
                    child: _buildDayInfo('Unpaid', contract.daysUnpaid.toStringAsFixed(0),
                        contract.daysUnpaid > 0 ? const Color(0xFFB91C1C) : textColor, subColor)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Contract amount', Formatters.formatCurrency(contract.contractAmount),
                      textColor: textColor, subColor: subColor),
                  Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  _buildInfoRow('Payments', Formatters.formatCurrency(contract.payments),
                      color: const Color(0xFF047857), subColor: subColor),
                  Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  _buildInfoRow('Balance', Formatters.formatCurrency(contract.balance),
                      color: contract.balance > 0 ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                      subColor: subColor),
                  Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  _buildInfoRow('Profit', Formatters.formatCurrency(contract.profit),
                      color: contract.profit >= 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                      subColor: subColor),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (canAdd)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openNewContract(renewFrom: contract),
                      icon: const Icon(Icons.autorenew, size: 18),
                      label: const Text('Renew'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF047857),
                        side: const BorderSide(color: AppColors.success),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                if (canAdd) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openDetails(contract),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightTextLight),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('View statement'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(text, style: ContractTheme.body(size: 13.5, color: color)),
      ],
    );
  }

  /// Mirrors the web list's badge (completed/on_track/behind/overdue),
  /// reading Contract.status straight from the server instead of the
  /// screen's own balance>0 guess -- that couldn't tell "paid off" from
  /// "still within term" apart, and never showed "Completed" at all.
  Widget _buildStatusBadge(Contract contract) {
    switch (contract.status) {
      case 'terminated':
        return const ContractStatusBadge(
            label: 'Terminated', dot: Colors.grey, background: Color(0xFFE9ECEF), foreground: Color(0xFF6C757D));
      case 'completed':
        return const ContractStatusBadge(
            label: 'Completed', dot: AppColors.success, background: Color(0xFFD1FAE5), foreground: Color(0xFF047857));
      case 'on_track':
        return const ContractStatusBadge(
            label: 'On track', dot: AppColors.success, background: Color(0xFFD1FAE5), foreground: Color(0xFF047857));
      default:
        return ContractStatusBadge(label: 'Behind ${contract.daysUnpaid.toStringAsFixed(0)}d');
    }
  }

  Widget _buildInfoRow(String label, String value, {Color? color, required Color subColor, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ContractTheme.body(size: 14, color: subColor)),
          Text(value, style: ContractTheme.display(size: 17, weight: FontWeight.w700, color: color ?? textColor)),
        ],
      ),
    );
  }

  Widget _buildDayInfo(String label, String value, Color valueColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: ContractTheme.display(size: 26, weight: FontWeight.w700, color: valueColor)),
        const SizedBox(height: 2),
        Text(label, style: ContractTheme.body(size: 13, color: subColor)),
      ],
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );
  }

  Widget _buildSkeletonCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader(width: 150, height: 18, isDark: isDark),
                SkeletonLoader(
                    width: 80, height: 24, borderRadius: 12, isDark: isDark),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonLoader(width: 200, height: 14, isDark: isDark),
            const SizedBox(height: 16),
            ...List.generate(
                4,
                (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SkeletonLoader(
                              width: 100, height: 14, isDark: isDark),
                          SkeletonLoader(width: 80, height: 14, isDark: isDark),
                        ],
                      ),
                    )),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                  3,
                  (i) => Column(
                        children: [
                          SkeletonLoader(width: 40, height: 20, isDark: isDark),
                          const SizedBox(height: 4),
                          SkeletonLoader(width: 50, height: 12, isDark: isDark),
                        ],
                      )),
            ),
          ],
        ),
      ),
    );
  }
}
