import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/production.dart';
import '../../models/supervisor.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../utils/production_messages.dart';

/// Production batches: the operator workflow. Open a draft, record what
/// actually came out, void a mistake.
class ProductionBatchesScreen extends StatefulWidget {
  const ProductionBatchesScreen({super.key});

  @override
  State<ProductionBatchesScreen> createState() => _ProductionBatchesScreenState();
}

class _ProductionBatchesScreenState extends State<ProductionBatchesScreen> {
  final ApiService _apiService = ApiService();
  final _number = NumberFormat('#,##0.##');
  final _dateApi = DateFormat('yyyy-MM-dd');

  List<ProductionBatch> _batches = [];
  List<ProductionRecipe> _recipes = [];
  List<ProductionLot> _lots = [];
  List<Supervisor> _operators = [];
  String? _statusFilter;
  late DateTimeRange _range;
  bool _isLoading = true;
  String? _errorMessage;

  static const List<String> _statuses = ['draft', 'curing', 'ready', 'closed'];

  @override
  void initState() {
    super.initState();
    // Last 30 days, matching the web default. Commit af9565e41 moved the
    // production screens off "today only" on purpose -- production is not
    // daily for every product, so a today-only list reads as "no data".
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Batches first and on their own. Recipes and lots only feed the New
    // Batch dialog, so waiting for all three before painting anything left
    // the screen on a spinner for three round trips instead of one.
    final response = await _apiService.getProductionBatches(
      status: _statusFilter,
      startDate: _dateApi.format(_range.start),
      endDate: _dateApi.format(_range.end),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _batches = response.data!.batches;
      } else {
        _errorMessage = productionErrorMessage(response.message);
      }
    });

    _loadFormData();
  }

  /// Recipes and lots for the New Batch dialog. Fetched after the list is on
  /// screen; a failure here only disables creating a batch, so it is not
  /// surfaced as a page error.
  Future<void> _loadFormData() async {
    final results = await Future.wait([
      _apiService.getProductionRecipes(),
      _apiService.getProductionLots(),
      // No employees endpoint exists; the supervisors list is the tenant's
      // employees and is what the web Operator dropdown shows too.
      _apiService.getSupervisors(),
    ]);
    if (!mounted) return;

    final recipeResponse = results[0] as dynamic;
    final lotResponse = results[1] as dynamic;
    final operatorResponse = results[2] as dynamic;

    setState(() {
      if (recipeResponse.isSuccess && recipeResponse.data != null) {
        _recipes = recipeResponse.data!;
      }
      if (lotResponse.isSuccess && lotResponse.data != null) {
        _lots = lotResponse.data!.where((l) => l.isActive).toList();
      }
      if (operatorResponse.isSuccess && operatorResponse.data != null) {
        _operators = operatorResponse.data!;
      }
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return AppColors.warning;
      case 'curing':
        return AppColors.info;
      case 'ready':
        return AppColors.success;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat('dd MMM').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  Future<void> _newBatch() async {
    if (_recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active recipe -- set one up on the web first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _NewBatchDialog(
        recipes: _recipes,
        lots: _lots,
        operators: _operators,
      ),
    );
    if (created == true) _load();
  }

  Future<void> _closeBatch(ProductionBatch batch) async {
    final closed = await showDialog<bool>(
      context: context,
      builder: (_) => _CloseBatchDialog(batch: batch),
    );
    if (closed == true) _load();
  }

  Future<void> _voidBatch(ProductionBatch batch) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Void ${batch.batchNo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The exact warning the web form carries -- this is destructive.
            const Text(
              'Voiding reverses ALL stock movements of this batch (raw '
              'materials return, output is removed). This cannot be undone.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Void', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    final reason = controller.text.trim();
    controller.dispose();
    if (confirmed != true || !mounted) return;

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A void reason is required'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final response = await _apiService.voidProductionBatch(batch.batchId, reason);
    if (!mounted) return;

    messenger.showSnackBar(SnackBar(
      content: Text(productionErrorMessage(response.message)),
      backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
    ));
    if (response.isSuccess) _load();
  }

  Future<void> _releaseCured() async {
    final messenger = ScaffoldMessenger.of(context);
    final response = await _apiService.releaseCuredBatches();
    if (!mounted) return;

    messenger.showSnackBar(SnackBar(
      content: Text(productionErrorMessage(response.message)),
      backgroundColor: response.isSuccess ? AppColors.success : AppColors.error,
    ));
    if (response.isSuccess) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final permissions = context.watch<PermissionProvider>();
    final canVoid = permissions.hasPermission(PermissionIds.productionVoid);
    // Batch create/close/release all sit behind production_batch server-side.
    final canWrite = permissions.hasPermission(PermissionIds.productionBatch);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Production Batches'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (canWrite)
            IconButton(
              icon: const Icon(Icons.local_shipping_outlined),
              tooltip: 'Release cured',
              onPressed: _isLoading ? null : _releaseCured,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: _newBatch,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('New Batch', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          _buildFilters(isDark),
          Expanded(child: _buildList(isDark, canVoid, canWrite)),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    final label = DateFormat('dd MMM yyyy');

    return Container(
      color: isDark ? AppColors.darkSurface : Colors.white,
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: InkWell(
              onTap: _pickRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${label.format(_range.start)}  -  ${label.format(_range.end)}',
                        style: TextStyle(
                            fontSize: 13.5,
                            color: isDark ? AppColors.darkText : AppColors.lightText),
                      ),
                    ),
                    Icon(Icons.expand_more,
                        size: 18,
                        color: isDark ? AppColors.darkTextLight : Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildStatusChips(isDark),
        ],
      ),
    );
  }

  Widget _buildStatusChips(bool isDark) {
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _filterChip('All', null, isDark),
            ..._statuses.map((s) => _filterChip(
                  '${s[0].toUpperCase()}${s.substring(1)}',
                  s,
                  isDark,
                )),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? value, bool isDark) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        selected: selected,
        onSelected: (_) {
          setState(() => _statusFilter = value);
          _load();
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.darkTextLight : Colors.grey[700]),
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildList(bool isDark, bool canVoid, bool canWrite) {
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

    if (_batches.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Icon(Icons.precision_manufacturing_outlined,
                size: 52, color: isDark ? Colors.grey[700] : Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No batches in this date range',
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
        itemCount: _batches.length,
        itemBuilder: (_, i) => _buildCard(_batches[i], isDark, canVoid, canWrite),
      ),
    );
  }

  Widget _buildCard(
      ProductionBatch b, bool isDark, bool canVoid, bool canWrite) {
    final color = _statusColor(b.status);
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkTextLight : Colors.grey[600];

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
                      Text(b.itemName ?? 'Batch ${b.batchNo}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: textColor)),
                      const SizedBox(height: 2),
                      Text(
                        '${b.batchNo} · ${_formatDate(b.productionDate)}'
                        '${b.lotNo != null ? ' · Lot ${b.lotNo}' : ''}',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    b.status,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metric('Bags', _number.format(b.bagsUsed), subColor, textColor),
                _metric('Expected', _number.format(b.expectedOutput), subColor, textColor),
                _metric(
                  'Actual',
                  b.actualOutput == null ? '—' : _number.format(b.actualOutput),
                  subColor,
                  textColor,
                ),
                _metric(
                  'Cost/unit',
                  b.costPerUnit == null ? '—' : _number.format(b.costPerUnit),
                  subColor,
                  textColor,
                ),
              ],
            ),
            if (b.efficiencyPct != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.speed, size: 15, color: subColor),
                  const SizedBox(width: 5),
                  Text('Efficiency ${_number.format(b.efficiencyPct)}%',
                      style: TextStyle(fontSize: 12.5, color: subColor)),
                ],
              ),
            ],
            if ((b.canClose && canWrite) || canVoid) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canVoid)
                    TextButton.icon(
                      onPressed: () => _voidBatch(b),
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Void'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    ),
                  if (b.canClose && canWrite) ...[
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () => _closeBatch(b),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color? subColor, Color textColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: subColor)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}

/// Open a draft batch.
class _NewBatchDialog extends StatefulWidget {
  final List<ProductionRecipe> recipes;
  final List<ProductionLot> lots;
  final List<Supervisor> operators;

  const _NewBatchDialog({
    required this.recipes,
    required this.lots,
    required this.operators,
  });

  @override
  State<_NewBatchDialog> createState() => _NewBatchDialogState();
}

class _NewBatchDialogState extends State<_NewBatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bagsController = TextEditingController();
  // Labour and overhead actually paid, matching the web form's three inputs.
  final _wafyatuaajiController = TextEditingController(text: '0');
  final _wapangajiController = TextEditingController(text: '0');
  final _waterController = TextEditingController(text: '0');
  final ApiService _apiService = ApiService();

  /// The chosen product. Recipes are grouped by it, mirroring the web form's
  /// two dropdowns.
  int? _itemId;

  /// null means "(active recipe of the product)" -- recipe_id is then left
  /// out of the request and Production_lib picks the active one itself, which
  /// is what the web's blank option does.
  ProductionRecipe? _recipe;
  int? _lotId;
  int? _operatorId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _itemId = widget.recipes.first.itemId;
    if (widget.lots.isNotEmpty) _lotId = widget.lots.first.lotId;
  }

  @override
  void dispose() {
    _bagsController.dispose();
    _wafyatuaajiController.dispose();
    _wapangajiController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  /// One entry per product, in recipe order.
  List<ProductionRecipe> get _products {
    final seen = <int>{};
    return widget.recipes.where((r) => seen.add(r.itemId)).toList();
  }

  List<ProductionRecipe> get _recipesForProduct =>
      widget.recipes.where((r) => r.itemId == _itemId).toList();

  /// The recipe that will actually be used: the explicit choice, or the
  /// product's active one when "(active recipe)" is selected. Only needed to
  /// preview the expected output -- the server resolves it either way.
  ProductionRecipe? get _effectiveRecipe {
    if (_recipe != null) return _recipe;
    final active = _recipesForProduct.where((r) => r.isActive);
    return active.isNotEmpty
        ? active.first
        : (_recipesForProduct.isNotEmpty ? _recipesForProduct.first : null);
  }

  double? get _bags => double.tryParse(_bagsController.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _itemId == null) return;

    setState(() => _isSaving = true);

    // Sand is sent equal to bags: the lib rejects anything else with
    // production_sand_mismatch, so there is no second field to get wrong.
    final response = await _apiService.createProductionBatch(
      itemId: _itemId!,
      bagsUsed: _bags!,
      sand: _bags!,
      // Omitted when "(active recipe)" is chosen, so the lib resolves it.
      recipeId: _recipe?.recipeId,
      lotId: _lotId,
      operatorId: _operatorId,
      productionDate: DateFormat('yyyy-MM-dd').format(_date),
      wafyatuaajiCost: double.tryParse(_wafyatuaajiController.text.trim()) ?? 0,
      wapangajiCost: double.tryParse(_wapangajiController.text.trim()) ?? 0,
      waterElectricityCost: double.tryParse(_waterController.text.trim()) ?? 0,
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

  /// One of the three manual cost inputs. Blank is read as 0 on submit,
  /// matching the web form, which pre-fills them with 0.
  Widget _cost(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'TSh ',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expected = (_bags ?? 0) * (_effectiveRecipe?.standardYieldPerBag ?? 0);

    return AlertDialog(
      title: const Text('New Batch'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _itemId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Product *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _products
                    .map((r) => DropdownMenuItem(
                          value: r.itemId,
                          child: Text(r.productLabel,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _itemId = value;
                  // The old recipe belongs to the old product.
                  _recipe = null;
                }),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ProductionRecipe?>(
                initialValue: _recipe,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Recipe',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<ProductionRecipe?>(
                    value: null,
                    child: Text('(active recipe of the product)',
                        overflow: TextOverflow.ellipsis),
                  ),
                  ..._recipesForProduct.map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (value) => setState(() => _recipe = value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bagsController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cement bags *',
                  helperText: 'Half bags allowed. Sand is used 1:1.',
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
              if (expected > 0) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '= ${NumberFormat('#,##0.##').format(expected)} blocks expected',
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Sand mirrors cement 1:1 and the lib rejects anything else, so
              // it is shown read-only rather than as a field to get wrong --
              // same as the web form, which greys it out.
              TextFormField(
                enabled: false,
                key: ValueKey('sand-${_bagsController.text}'),
                initialValue:
                    _bags == null ? '' : NumberFormat('#,##0.##').format(_bags),
                decoration: const InputDecoration(
                  labelText: 'Sand',
                  helperText: 'Always equals cement used (1:1)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              _cost(_wafyatuaajiController, 'WAFYATUAJI'),
              const SizedBox(height: 12),
              _cost(_wapangajiController, 'WAPANGAJI'),
              const SizedBox(height: 12),
              _cost(_waterController, 'WATER & ELECTRICITY'),
              const SizedBox(height: 14),
              if (widget.operators.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _operatorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Operator (mfyatuaji)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: widget.operators
                      .map((o) => DropdownMenuItem(
                            value: int.tryParse(o.id),
                            child: Text(o.displayName,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _operatorId = value),
                ),
              if (widget.operators.isNotEmpty) const SizedBox(height: 14),
              if (widget.lots.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _lotId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sand lot',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: widget.lots
                      .map((l) => DropdownMenuItem(
                            value: l.lotId,
                            child: Text('${l.lotNo} (${l.bagsRemaining.toStringAsFixed(0)} bags left)',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _lotId = value),
                ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Production date',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_date)),
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
}

/// Record what actually came out. This moves stock, so it warns first.
class _CloseBatchDialog extends StatefulWidget {
  final ProductionBatch batch;

  const _CloseBatchDialog({required this.batch});

  @override
  State<_CloseBatchDialog> createState() => _CloseBatchDialogState();
}

class _CloseBatchDialogState extends State<_CloseBatchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _outputController = TextEditingController();
  final _rejectsController = TextEditingController(text: '0');
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the expected figure: most batches hit it, and the
    // operator only has to correct the ones that did not.
    _outputController.text = widget.batch.expectedOutput.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _outputController.dispose();
    _rejectsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final response = await _apiService.closeProductionBatch(
      widget.batch.batchId,
      actualOutput: double.parse(_outputController.text.trim()),
      rejects: double.tryParse(_rejectsController.text.trim()) ?? 0,
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
    final b = widget.batch;

    return AlertDialog(
      title: Text('Close ${b.batchNo}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Expected ${NumberFormat('#,##0.##').format(b.expectedOutput)} '
              'from ${NumberFormat('#,##0.##').format(b.bagsUsed)} bags. '
              'Closing moves stock.',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _outputController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Actual output *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null) return 'Enter a number';
                if (parsed <= 0) return 'Must be greater than zero';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _rejectsController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Rejects',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          child: _isSaving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Close batch', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
