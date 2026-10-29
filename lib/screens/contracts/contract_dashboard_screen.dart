import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../contract_details_screen.dart';
import 'contract_theme.dart';

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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: ContractTheme.appBar(isDark: isDark, eyebrow: 'Overview', title: 'Dashboard'),
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
    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ContractRingGauge(value: behindCount, total: liveOnes.length),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Active contracts', style: ContractTheme.body(size: 13, color: subColor)),
                        Text('${liveOnes.length} of ${contracts.length}',
                            style: ContractTheme.display(size: 30, weight: FontWeight.w700, letterSpacing: -0.5, color: textColor)),
                        if (behindCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                  width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('$behindCount behind',
                                  style: ContractTheme.body(size: 14, weight: FontWeight.w600, color: const Color(0xFFB91C1C))),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Formatters.formatCurrency(toCollectNow),
                            style: ContractTheme.display(size: 24, weight: FontWeight.w700, color: const Color(0xFFB91C1C))),
                        Text('To collect now', style: ContractTheme.body(size: 13, color: subColor)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Formatters.formatCurrency(collected),
                            style: ContractTheme.display(size: 24, weight: FontWeight.w700, color: const Color(0xFF047857))),
                        Text('Collected', style: ContractTheme.body(size: 13, color: subColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ContractHeroPanel(
          caption: 'Still owed on active',
          value: 'TZS ${Formatters.formatCurrency(stillOwedOnActive)}',
        ),
      ],
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

    final textColor = isDark ? AppColors.darkText : AppColors.text;
    final subColor = isDark ? AppColors.darkTextLight : AppColors.textLight;

    if (behind.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Nothing to collect right now -- every active contract is on track.',
                  style: ContractTheme.body(size: 13.5, color: subColor)),
            ),
          ],
        ),
      );
    }

    // The unpaid-days bar is a visual ratio only, capped at a sensible max
    // (same convention the handover uses) -- not a claim about the longest
    // possible unpaid streak.
    const maxBarDays = 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Most behind', style: ContractTheme.display(size: 17, weight: FontWeight.w700, color: textColor)),
        const SizedBox(height: 10),
        ...behind.take(10).toList().asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final c = entry.value;
          final barFraction = (c.daysUnpaid / maxBarDays).clamp(0.0, 1.0);
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openDetails(c),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ContractCircleBadge(text: '$rank', size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: ContractTheme.display(size: 17, weight: FontWeight.w700, color: textColor)),
                        Text('${c.daysUnpaid.toStringAsFixed(0)} day(s) unpaid',
                            style: ContractTheme.body(size: 13, color: subColor)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: barFraction,
                            minHeight: 6,
                            backgroundColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(Formatters.formatCurrency(c.currentUnpaid),
                      style: ContractTheme.display(size: 17, weight: FontWeight.w700, color: const Color(0xFFB91C1C))),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
