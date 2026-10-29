import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/lipa_namba.dart';
import '../../models/permission_model.dart';
import '../../providers/theme_provider.dart';
import '../../providers/permission_provider.dart';
import '../../widgets/glassmorphic_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../../utils/formatters.dart' show Formatters;
import '../../utils/constants.dart';

class LipaNambaFeesScreen extends StatefulWidget {
  const LipaNambaFeesScreen({super.key});

  @override
  State<LipaNambaFeesScreen> createState() => _LipaNambaFeesScreenState();
}

class _LipaNambaFeesScreenState extends State<LipaNambaFeesScreen> {
  final _apiService = ApiService();
  bool _isLoading = false;
  String? _error;

  List<LipaNambaFeeTier> _fees = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _apiService.getLipaNambaFees();

    if (!mounted) return;
    if (response.isSuccess) {
      setState(() {
        _fees = response.data ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _showFeeDialog({LipaNambaFeeTier? existing}) async {
    final minController = TextEditingController(
      text: existing != null ? existing.minAmount.toStringAsFixed(0) : '',
    );
    final maxController = TextEditingController(
      text: existing != null ? existing.maxAmount.toStringAsFixed(0) : '',
    );
    final feeController = TextEditingController(
      text: existing != null ? existing.fee.toStringAsFixed(0) : '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Fee Tier' : 'Edit Fee Tier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              decoration: const InputDecoration(labelText: 'From amount', prefixText: 'TZS '),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxController,
              decoration: const InputDecoration(labelText: 'To amount', prefixText: 'TZS '),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feeController,
              decoration: const InputDecoration(labelText: 'Fee', prefixText: 'TZS '),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final minAmount = double.tryParse(minController.text);
              final maxAmount = double.tryParse(maxController.text);
              final fee = double.tryParse(feeController.text);
              if (minAmount == null || maxAmount == null || fee == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid amounts')),
                );
                return;
              }
              if (maxAmount < minAmount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('"To amount" must be greater than "From amount"')),
                );
                return;
              }

              Navigator.pop(context);

              final response = existing == null
                  ? await _apiService.addLipaNambaFee(minAmount: minAmount, maxAmount: maxAmount, fee: fee)
                  : await _apiService.editLipaNambaFee(
                      existing.id,
                      minAmount: minAmount,
                      maxAmount: maxAmount,
                      fee: fee,
                    );

              if (context.mounted) {
                if (response.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(existing == null ? 'Fee tier added successfully' : 'Fee tier updated successfully')),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(response.message)),
                  );
                }
              }
            },
            child: Text(existing == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFee(LipaNambaFeeTier fee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fee Tier'),
        content: Text(
          'Delete the tier ${Formatters.formatCurrency(fee.minAmount)} - ${Formatters.formatCurrency(fee.maxAmount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await _apiService.deleteLipaNambaFee(fee.id);

      if (context.mounted) {
        if (response.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fee tier deleted successfully')),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final permissionProvider = Provider.of<PermissionProvider>(context);
    final isDark = themeProvider.isDarkMode;

    // One permission (lipa_namba_fees) covers the whole page -- there are
    // no separate add/edit/delete sub-permissions on the web side.
    final canManage = permissionProvider.hasPermission(PermissionIds.lipaNambaFees);

    return Scaffold(
      appBar: AppBar(title: const Text('Lipa Namba Fee Tiers')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBackground, AppColors.darkSurface]
                : [const Color(0xFFF9FAFB), const Color(0xFFF3F4F6)],
          ),
        ),
        child: _isLoading
            ? _buildSkeletonList(isDark)
            : _error != null
                ? Center(child: Text(_error!))
                : _fees.isEmpty
                    ? Center(
                        child: Text(
                          'No fee tiers configured',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _fees.length,
                        itemBuilder: (context, index) {
                          final fee = _fees[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassmorphicCard(
                              isDark: isDark,
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Icon(Icons.percent, color: Colors.white),
                                ),
                                title: Text(
                                  '${Formatters.formatCurrency(fee.minAmount)} - ${Formatters.formatCurrency(fee.maxAmount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkText : const Color(0xFF1F2937),
                                  ),
                                ),
                                subtitle: Text(
                                  'Fee: ${Formatters.formatCurrency(fee.fee)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                                trailing: canManage
                                    ? PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: isDark ? AppColors.darkTextLight : const Color(0xFF6B7280),
                                        ),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showFeeDialog(existing: fee);
                                          } else if (value == 'delete') {
                                            _deleteFee(fee);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showFeeDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Tier'),
            )
          : null,
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassmorphicCard(
          isDark: isDark,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SkeletonLoader(width: 40, height: 40, borderRadius: 20, isDark: isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 140, height: 14, isDark: isDark),
                      const SizedBox(height: 8),
                      SkeletonLoader(width: 80, height: 12, isDark: isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
