import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../contract_details_screen.dart';

/// A standalone overview -- the at-a-glance numbers the web list's header
/// row shows (Active contracts/Behind/To collect now/Collected/Still owed
/// on active), plus the contracts most behind, so a tenant can see where
/// they stand without scrolling the full Contracts list. Deliberately its
/// own screen/tab, not folded into ContractsScreen -- that one stays the
/// plain searchable list.
class ContractDashboardScreen extends StatefulWidget {
  const ContractDashboardScreen({super.key});

  @override
  State<ContractDashboardScreen> createState() => _ContractDashboardScreenState();
}

class _ContractDashboardScreenState extends State<ContractDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<Contract>? _contracts;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _apiService.getContracts();
    setState(() {
      _isLoading = false;
      if (result.isSuccess && result.data != null) {
        _contracts = result.data;
      } else {
        _errorMessage = result.message;
      }
    });
  }

  void _openDetails(Contract contract) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContractDetailsScreen(contract: contract)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : (_contracts == null || _contracts!.isEmpty)
                  ? Center(
                      child: Text('No contracts yet',
                          style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildStats(isDark),
                          const SizedBox(height: 20),
                          _buildMostBehind(isDark),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStats(bool isDark) {
    final contracts = _contracts!;
    final liveOnes = contracts.where((c) => !c.isCompleted && !c.isTerminated).toList();
    final behindCount = liveOnes.where((c) => c.status != 'on_track').length;
    final toCollectNow = liveOnes.fold<double>(0, (sum, c) => sum + c.currentUnpaid);
    final collected = contracts.fold<double>(0, (sum, c) => sum + c.payments);
    final stillOwedOnActive = liveOnes.fold<double>(0, (sum, c) => sum + c.balance);

    final stats = <_DashboardStat>[
      _DashboardStat('Active contracts', '${liveOnes.length} of ${contracts.length}',
          isDark ? AppColors.darkText : AppColors.text),
      _DashboardStat(
          'Behind', '$behindCount', behindCount > 0 ? AppColors.error : AppColors.success),
      _DashboardStat('To collect now', Formatters.formatCurrency(toCollectNow), AppColors.error),
      _DashboardStat('Collected', Formatters.formatCurrency(collected), AppColors.success),
      _DashboardStat('Still owed on active', Formatters.formatCurrency(stillOwedOnActive),
          isDark ? AppColors.darkText : AppColors.text),
    ];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      color: isDark ? AppColors.darkSurface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 20,
          runSpacing: 12,
          children: stats
              .map((s) => SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.value,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: s.color)),
                        const SizedBox(height: 2),
                        Text(s.label,
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  /// The contracts furthest behind, most-owing first -- the ones a tenant
  /// actually needs to chase today, surfaced without hunting through the
  /// full list.
  Widget _buildMostBehind(bool isDark) {
    final behind = _contracts!
        .where((c) => !c.isCompleted && !c.isTerminated && c.currentUnpaid > 0)
        .toList()
      ..sort((a, b) => b.currentUnpaid.compareTo(a.currentUnpaid));

    if (behind.isEmpty) {
      return Card(
        color: isDark ? AppColors.darkSurface : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(width: 10),
              Text('Nothing to collect right now -- every active contract is on track.',
                  style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Most behind',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.text)),
        const SizedBox(height: 8),
        ...behind.take(10).map((c) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isDark ? AppColors.darkCard : Colors.white,
              child: ListTile(
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${c.daysUnpaid.toStringAsFixed(0)} day(s) unpaid'),
                trailing: Text(Formatters.formatCurrency(c.currentUnpaid),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                onTap: () => _openDetails(c),
              ),
            )),
      ],
    );
  }
}

class _DashboardStat {
  final String label;
  final String value;
  final Color color;
  _DashboardStat(this.label, this.value, this.color);
}
