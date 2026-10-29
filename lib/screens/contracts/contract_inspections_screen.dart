import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract_extras.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

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
      appBar: AppBar(
        title: const Text('Inspections'),
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
              : (_inspections == null || _inspections!.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No contracts have an inspection interval configured.\n\nSet one at My Subscription -> Contract Rules.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.textLight),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _inspections!.map((c) {
                          final color = c.inspectionOverdue ? AppColors.error : AppColors.success;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isDark ? AppColors.darkCard : Colors.white,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.15),
                                child: Icon(
                                  c.inspectionOverdue ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                  color: color,
                                ),
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text([
                                if (c.assetPlateNumber != null && c.assetPlateNumber!.isNotEmpty)
                                  c.assetPlateNumber!,
                                '${c.inspectionOverdue ? "Overdue since" : "Due"} ${Formatters.formatDate(c.inspectionDueDate)}',
                              ].join(' · ')),
                              trailing: canMark
                                  ? TextButton(
                                      onPressed: () => _markInspected(c),
                                      child: const Text('Mark'),
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
    );
  }
}
