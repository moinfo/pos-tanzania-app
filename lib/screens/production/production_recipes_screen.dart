import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/production.dart';
import '../../models/item.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/constants.dart';
import '../../utils/production_messages.dart';

/// Read-only. Creating a recipe means picking raw materials and yield rates --
/// setup work that belongs on the web form, where the whole item catalogue is
/// to hand. The write endpoints exist if this ever needs to change.
class ProductionRecipesScreen extends StatefulWidget {
  const ProductionRecipesScreen({super.key});

  @override
  State<ProductionRecipesScreen> createState() => _ProductionRecipesScreenState();
}

class _ProductionRecipesScreenState extends State<ProductionRecipesScreen> {
  final ApiService _apiService = ApiService();
  final _number = NumberFormat('#,##0.##');

  List<ProductionRecipe> _recipes = [];
  List<Item> _items = [];
  bool _showInactive = false;
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

    final response = await _apiService.getProductionRecipes(all: _showInactive);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _recipes = response.data!;
      } else {
        _errorMessage = productionErrorMessage(response.message);
      }
    });

    _loadItems();
  }

  /// Items feed the Product and Raw material pickers. Fetched after the list
  /// so the recipes appear immediately; a failure only disables the form.
  Future<void> _loadItems() async {
    if (_items.isNotEmpty) return;
    final response = await _apiService.getItems(limit: 500);
    if (!mounted) return;
    if (response.isSuccess && response.data != null) {
      setState(() => _items = response.data!);
    }
  }

  Future<void> _openForm({ProductionRecipe? existing}) async {
    if (_items.isEmpty) await _loadItems();
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RecipeForm(items: _items, existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(ProductionRecipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${recipe.name}?'),
        content: const Text(
          'A recipe already used by a batch cannot be deleted -- the server '
          'will refuse it so past efficiency reports stay intact. Deactivate '
          'it instead to stop it being used for new batches.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final response = await _apiService.deleteProductionRecipe(recipe.recipeId);
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
    // Create, update and delete all sit behind production_recipe server-side.
    final canWrite = context
        .watch<PermissionProvider>()
        .hasPermission(PermissionIds.productionRecipe);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Recipes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            tooltip: _showInactive ? 'Active only' : 'Show inactive',
            onPressed: () {
              setState(() => _showInactive = !_showInactive);
              _load();
            },
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Recipe', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error)),
                  ),
                )
              : _recipes.isEmpty
                  ? Center(
                      child: Text('No recipes',
                          style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : Colors.grey[500])),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _recipes.length,
                      itemBuilder: (_, i) =>
                          _buildCard(_recipes[i], isDark, canWrite),
                    ),
    );
  }

  Widget _buildCard(ProductionRecipe r, bool isDark, bool canWrite) {
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
                  child: Text(r.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: textColor)),
                ),
                if (!r.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Text('inactive',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_number.format(r.standardYieldPerBag)} per bag'
              '${r.curingDays != null ? ' · ${r.curingDays} curing days' : ' · curing from settings'}',
              style: TextStyle(fontSize: 12.5, color: subColor),
            ),
            if (r.items.isNotEmpty) ...[
              const Divider(height: 18),
              ...r.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.itemName ?? 'Item #${item.itemId}',
                            style: TextStyle(fontSize: 12.5, color: subColor)),
                        Text('${_number.format(item.qtyPerBag)} / bag',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                      ],
                    ),
                  )),
            ],
            if (canWrite) ...[
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmDelete(r),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _openForm(existing: r),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Create or edit a recipe.
///
/// The endpoint takes a single raw-material line (raw_item_id + qty_per_bag),
/// which is how every recipe here is shaped: one cement rate per bag. Leaving
/// the raw material blank on edit leaves the existing line untouched, since
/// the server only writes it when raw_item_id is present.
class _RecipeForm extends StatefulWidget {
  final List<Item> items;
  final ProductionRecipe? existing;

  const _RecipeForm({required this.items, this.existing});

  @override
  State<_RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<_RecipeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _yieldController = TextEditingController();
  final _curingController = TextEditingController();
  final _qtyPerBagController = TextEditingController(text: '1');
  final ApiService _apiService = ApiService();

  int? _itemId;
  int? _rawItemId;
  bool _isActive = true;
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _yieldController.text = existing.standardYieldPerBag.toString();
      _curingController.text = existing.curingDays?.toString() ?? '';
      _itemId = existing.itemId;
      _isActive = existing.isActive;
      if (existing.items.isNotEmpty) {
        _rawItemId = existing.items.first.itemId;
        _qtyPerBagController.text = existing.items.first.qtyPerBag.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yieldController.dispose();
    _curingController.dispose();
    _qtyPerBagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_itemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the product this recipe makes'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final yieldPerBag = double.parse(_yieldController.text.trim());
    // Blank means "use settings.default_curing_days", so send nothing.
    final curing = int.tryParse(_curingController.text.trim());
    final qtyPerBag = double.tryParse(_qtyPerBagController.text.trim());

    final response = _isEdit
        ? await _apiService.updateProductionRecipe(
            widget.existing!.recipeId,
            itemId: _itemId!,
            name: name,
            standardYieldPerBag: yieldPerBag,
            curingDays: curing,
            isActive: _isActive,
            rawItemId: _rawItemId,
            qtyPerBag: qtyPerBag,
          )
        : await _apiService.createProductionRecipe(
            itemId: _itemId!,
            name: name,
            standardYieldPerBag: yieldPerBag,
            curingDays: curing,
            isActive: _isActive,
            rawItemId: _rawItemId,
            qtyPerBag: qtyPerBag,
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
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Recipe' : 'New Recipe'),
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
                  helperText: 'The item this recipe produces',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.items
                    .map((i) => DropdownMenuItem(
                          value: i.itemId,
                          child: Text(i.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _itemId = value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Recipe name *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Recipe name is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _yieldController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Yield per bag *',
                  helperText: 'Blocks produced from one cement bag',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null) return 'Enter a number';
                  if (parsed <= 0) return 'Must be greater than zero';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _curingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Curing days',
                  helperText: 'Leave blank to use the production settings',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _rawItemId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Raw material',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.items
                    .map((i) => DropdownMenuItem(
                          value: i.itemId,
                          child: Text(i.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _rawItemId = value),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _qtyPerBagController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Qty per bag',
                  helperText: 'How much raw material one bag consumes',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active', style: TextStyle(fontSize: 14)),
                subtitle: const Text(
                  'Only an active recipe is picked automatically for new batches',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
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
              : const Text('Save'),
        ),
      ],
    );
  }
}
