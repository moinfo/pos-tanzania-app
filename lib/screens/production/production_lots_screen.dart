import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/production.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../utils/production_messages.dart';

/// Sand lots. A lot is a delivery of sand with its own landed cost; batches
/// draw bags from it, and closing one records what it actually yielded.
class ProductionLotsScreen extends StatefulWidget {
  const ProductionLotsScreen({super.key});

  @override
  State<ProductionLotsScreen> createState() => _ProductionLotsScreenState();
}

class _ProductionLotsScreenState extends State<ProductionLotsScreen> {
  final ApiService _apiService = ApiService();
  final _number = NumberFormat('#,##0.##');

  List<ProductionLot> _lots = [];
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

    final response = await _apiService.getProductionLots();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _lots = response.data!;
      } else {
        _errorMessage = productionErrorMessage(response.message);
      }
    });
  }

  Future<void> _newLot() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewLotDialog(),
    );
    if (created == true) _load();
  }

  Future<void> _closeLot(ProductionLot lot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close ${lot.lotNo}'),
        content: const Text(
          'Closing records the final yield of this sand lot. New batches can '
          'still be opened afterwards -- they will just need a different lot.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close lot'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final response = await _apiService.closeProductionLot(lot.lotId);
    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      // The API hands back the yield at close time -- show it straight away
      // rather than making the user hunt for it in a report.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${lot.lotNo} closed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _yieldRow('Batches', _number.format(response.data!.batches)),
              _yieldRow('Blocks produced', _number.format(response.data!.blocksProduced)),
              _yieldRow('Expected profit',
                  'TSh ${_number.format(response.data!.expectedProfit)}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      _load();
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(productionErrorMessage(response.message)),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _yieldRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    // Creating and closing a lot both sit behind production_lot server-side.
    final canWrite = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.productionLot);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Sand Lots'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
        onPressed: _newLot,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Lot', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: _buildBody(isDark, canWrite),
    );
  }

  Widget _buildBody(bool isDark, bool canWrite) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDark ? AppColors.darkTextLight : Colors.grey[600])),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_lots.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Icon(Icons.layers_outlined,
                size: 52, color: isDark ? Colors.grey[700] : Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No sand lots yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? AppColors.darkTextLight : Colors.grey[500],
                    fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _lots.length,
        itemBuilder: (_, i) => _buildCard(_lots[i], isDark, canWrite),
      ),
    );
  }

  Widget _buildCard(ProductionLot lot, bool isDark, bool canWrite) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : Colors.grey[600];
    final color = lot.isActive ? AppColors.success : Colors.grey;

    // Guard against a divide-by-zero if expected_bags is ever 0.
    final progress = lot.expectedBags > 0
        ? (lot.bagsConsumed / lot.expectedBags).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lot.lotNo,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: textColor)),
                      const SizedBox(height: 2),
                      Text('Opened ${_formatDate(lot.openedOn)}',
                          style: TextStyle(fontSize: 12, color: subColor)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(lot.status,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
            const SizedBox(height: 6),
            Text(
              '${_number.format(lot.bagsConsumed)} of '
              '${_number.format(lot.expectedBags)} bags used',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('Total TSh ${_number.format(lot.totalCost)}',
                      style: TextStyle(fontSize: 12.5, color: subColor)),
                ),
                Text('TSh ${_number.format(lot.costPerBag)} / bag',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
              ],
            ),
            if (lot.isActive && canWrite) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _closeLot(lot),
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Close lot'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewLotDialog extends StatefulWidget {
  const _NewLotDialog();

  @override
  State<_NewLotDialog> createState() => _NewLotDialogState();
}

class _NewLotDialogState extends State<_NewLotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _materialController = TextEditingController();
  final _transportController = TextEditingController(text: '0');
  final _utilityController = TextEditingController(text: '0');
  final _bagsController = TextEditingController();
  final _notesController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  @override
  void dispose() {
    _materialController.dispose();
    _transportController.dispose();
    _utilityController.dispose();
    _bagsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final response = await _apiService.createProductionLot(
      materialCost: _parse(_materialController),
      expectedBags: _parse(_bagsController),
      transportCost: _parse(_transportController),
      utilityCost: _parse(_utilityController),
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    final messenger = ScaffoldMessenger.of(context);
    if (response.isSuccess) Navigator.pop(context, true);
    messenger.showSnackBar(SnackBar(
      content: Text(productionErrorMessage(response.message)),
      backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Same formula the server uses, shown live so the cost per bag is not a
    // surprise after saving.
    final total = _parse(_materialController) +
        _parse(_transportController) +
        _parse(_utilityController);
    final bags = _parse(_bagsController);
    final perBag = bags > 0 ? total / bags : 0;

    return AlertDialog(
      title: const Text('New Sand Lot'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _money(_materialController, 'Material cost (sand) *', required: true),
              const SizedBox(height: 12),
              _money(_transportController, 'Transport cost'),
              const SizedBox(height: 12),
              _money(_utilityController, 'Utility cost (power + water)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bagsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Expected bags *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null) return 'Enter a number';
                  if (parsed <= 0) return 'Must be greater than zero';
                  return null;
                },
              ),
              if (perBag > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TSh ${NumberFormat('#,##0.##').format(total)} total  ·  '
                    'TSh ${NumberFormat('#,##0.####').format(perBag)} per bag',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }

  Widget _money(TextEditingController controller, String label, {bool required = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'TSh ',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
      validator: required
          ? (value) {
              final parsed = double.tryParse(value?.trim() ?? '');
              if (parsed == null) return 'Enter a number';
              if (parsed <= 0) return 'Must be greater than zero';
              return null;
            }
          : null,
    );
  }
}
