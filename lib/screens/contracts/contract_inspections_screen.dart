import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract_extras.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'contract_theme.dart';

/// Every active contract with an inspection interval configured, overdue
/// first. "Mark inspected" resets the interval from today. Mirrors web
/// Contracts::inspections()/markInspected().
class ContractInspectionsScreen extends StatefulWidget {
  const ContractInspectionsScreen({super.key});

  @override
  State<ContractInspectionsScreen> createState() => _ContractInspectionsScreenState();
}

class _ContractInspectionsScreenState extends State<ContractInspectionsScreen> {
  final ApiService _apiService = ApiService();
  List<ContractInspectionDue>? _inspections;
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
    final response = await _apiService.getContractInspections();
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _inspections = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _markInspected(ContractInspectionDue c) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Mark ${c.name} inspected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Resets the inspection interval to start from today.'),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Mark inspected'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await _apiService.markContractInspected(
      c.contractId,
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
    );
    if (!mounted) return;
    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inspection recorded.'), backgroundColor: AppColors.success),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final canMark = context.watch<PermissionProvider>().hasPermission(PermissionIds.contractsInspectionsMark);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: ContractTheme.appBar(isDark: isDark, eyebrow: 'Maintenance checks', title: 'Inspections'),
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
              : (_inspections == null || _inspections!.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No contracts have an inspection interval configured.\n\nSet one at My Subscription -> Contract Rules.',
                          textAlign: TextAlign.center,
                          style: ContractTheme.body(size: 14, color: isDark ? AppColors.darkTextLight : AppColors.textLight),
                        ),
                      ),
                    )
                  : _buildGroupedList(isDark, canMark),
    );
  }

  Widget _buildGroupedList(bool isDark, bool canMark) {
    final today = DateTime.now();
    final todayStr = Formatters.formatDateForApi(today);
    final overdue = _inspections!.where((c) => c.inspectionOverdue).toList();
    final upcoming = _inspections!.where((c) => !c.inspectionOverdue).toList();
    final textColor = isDark ? AppColors.darkText : AppColors.text;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (overdue.isNotEmpty) ...[
            _groupHeader('Overdue', overdue.length, const Color(0xFFFEE2E2), const Color(0xFFB91C1C), textColor),
            const SizedBox(height: 8),
            ...overdue.map((c) => _inspectionRow(c, isDark, canMark, todayStr)),
            const SizedBox(height: 14),
          ],
          if (upcoming.isNotEmpty) ...[
            _groupHeader('Upcoming', upcoming.length, AppColors.lightDivider, textColor, textColor),
            const SizedBox(height: 8),
            ...upcoming.map((c) => _inspectionRow(c, isDark, canMark, todayStr)),
          ],
        ],
      ),
    );
  }

  Widget _groupHeader(String label, int count, Color badgeBg, Color badgeFg, Color textColor) {
    return Row(
      children: [
        Text(label, style: ContractTheme.display(size: 17, weight: FontWeight.w700, color: textColor)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
          child: Text('$count', style: ContractTheme.body(size: 12, weight: FontWeight.w600, color: badgeFg)),
        ),
      ],
    );
  }

  Widget _inspectionRow(ContractInspectionDue c, bool isDark, bool canMark, String todayStr) {
    final isDueToday = !c.inspectionOverdue && c.inspectionDueDate == todayStr;
    final IconData icon;
    final Color tintBg, tintFg, statusColor;
    final String statusText;
    if (c.inspectionOverdue) {
      icon = Icons.warning_amber_rounded;
      tintBg = const Color(0xFFFEE2E2);
      tintFg = const Color(0xFFB91C1C);
      statusColor = const Color(0xFFB91C1C);
      statusText = 'Overdue since ${Formatters.formatDate(c.inspectionDueDate)}';
    } else if (isDueToday) {
      icon = Icons.access_time_filled_rounded;
      tintBg = const Color(0xFFFEF3C7);
      tintFg = const Color(0xFF92400E);
      statusColor = const Color(0xFF92400E);
      statusText = 'Due today · ${Formatters.formatDate(c.inspectionDueDate)}';
    } else {
      icon = Icons.check_circle_outline;
      tintBg = const Color(0xFFD1FAE5);
      tintFg = const Color(0xFF047857);
      statusColor = isDark ? AppColors.darkTextLight : AppColors.textLight;
      statusText = 'Due ${Formatters.formatDate(c.inspectionDueDate)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Row(
        children: [
          ContractCircleBadge(icon: icon, background: tintBg, foreground: tintFg, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: ContractTheme.display(
                        size: 19, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                if (c.assetPlateNumber != null && c.assetPlateNumber!.isNotEmpty)
                  Text(c.assetPlateNumber!.toUpperCase(),
                      style: ContractTheme.body(
                          size: 13, weight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.text)
                          .copyWith(letterSpacing: 0.6)),
                Text(statusText, style: ContractTheme.body(size: 13, weight: FontWeight.w600, color: statusColor)),
              ],
            ),
          ),
          if (canMark)
            TextButton(
              onPressed: () => _markInspected(c),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Mark'),
            ),
        ],
      ),
    );
  }
}
