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
      appBar: AppBar(
        title: const Text('Contracts'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
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
              backgroundColor: AppColors.primary,
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
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _contracts!.length,
                        itemBuilder: (context, index) {
                          final contract = _contracts![index];
                          return _buildContractCard(contract, isDark);
                        },
                      ),
                    ),
    );
  }

  Widget _buildContractCard(Contract contract, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _openDetails(contract),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      contract.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                  ),
                  _buildStatusBadge(contract),
                ],
              ),
              const SizedBox(height: 8),

              // Phone and description
              if (contract.phone.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.phone,
                        size: 16,
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      contract.phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextLight
                            : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(
                contract.contractDescription,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Financial summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Contract Amount',
                        Formatters.formatCurrency(contract.contractAmount),
                        isDark: isDark),
                    const Divider(height: 16),
                    _buildInfoRow('Payments',
                        Formatters.formatCurrency(contract.payments),
                        color: AppColors.success, isDark: isDark),
                    const Divider(height: 16),
                    _buildInfoRow(
                        'Balance', Formatters.formatCurrency(contract.balance),
                        color: contract.balance > 0
                            ? AppColors.error
                            : AppColors.success,
                        isDark: isDark),
                    const Divider(height: 16),
                    _buildInfoRow(
                        'Profit', Formatters.formatCurrency(contract.profit),
                        color: contract.profit >= 0
                            ? AppColors.success
                            : AppColors.error,
                        isDark: isDark),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Days info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDayInfo('Days', contract.days.toString(),
                      isDark: isDark),
                  _buildDayInfo('Paid', contract.daysPaid.toStringAsFixed(0),
                      color: AppColors.success, isDark: isDark),
                  _buildDayInfo(
                      'Unpaid', contract.daysUnpaid.toStringAsFixed(0),
                      color: contract.daysUnpaid > 0
                          ? AppColors.error
                          : (isDark
                              ? AppColors.darkTextLight
                              : AppColors.textLight),
                      isDark: isDark),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (context
                      .watch<PermissionProvider>()
                      .hasPermission(PermissionIds.contractsAdd))
                    TextButton.icon(
                      onPressed: () => _openNewContract(renewFrom: contract),
                      icon: const Icon(Icons.autorenew, size: 18),
                      label: const Text('Renew'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.success,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => _openDetails(contract),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View Statement'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mirrors the web list's badge (completed/on_track/behind/overdue),
  /// reading Contract.status straight from the server instead of the
  /// screen's own balance>0 guess -- that couldn't tell "paid off" from
  /// "still within term" apart, and never showed "Completed" at all.
  Widget _buildStatusBadge(Contract contract) {
    final Color color;
    final String label;
    switch (contract.status) {
      case 'terminated':
        color = Colors.grey;
        label = 'Terminated';
        break;
      case 'completed':
        color = AppColors.success;
        label = 'Completed';
        break;
      case 'on_track':
        color = AppColors.success;
        label = 'On Track';
        break;
      case 'behind':
        color = AppColors.warning;
        label = 'Behind ${contract.daysUnpaid.toStringAsFixed(0)}d';
        break;
      default:
        color = AppColors.error;
        label = 'Behind ${contract.daysUnpaid.toStringAsFixed(0)}d';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color, required bool isDark}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? AppColors.darkText : AppColors.text),
          ),
        ),
      ],
    );
  }

  Widget _buildDayInfo(String label, String value,
      {Color? color, required bool isDark}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? AppColors.darkText : AppColors.text),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextLight : AppColors.textLight,
          ),
        ),
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
