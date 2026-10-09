import 'package:flutter/material.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'managed_list_screen.dart';

class IndustryPackingProductsScreen extends StatelessWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryPackingProductsScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  Widget build(BuildContext context) {
    return ManagedListScreen<PackingProduct>(
      title: 'Packing Products',
      fields: const [],
      onSearch: ({required search, required limit, required offset}) =>
          service.searchPackingProducts(search: search, limit: limit, offset: offset),
      onGetRow: service.getPackingProduct,
      onSave: ({id, required fields}) => service.savePackingProduct(id: id, fields: fields),
      onDelete: (id) => service.deletePackingProducts([id]),
      rowToFields: (row) => row.toFormFields(),
      rowTitle: (row) => row['name']?.toString() ?? '',
      rowSubtitle: (row) => row['unit_label']?.toString(),
      rowId: (row) => int.tryParse(row['product_id']?.toString() ?? '') ?? 0,
      onSessionExpired: onSessionExpired,
      itemBuilder: (context, row, onTap, onDelete) => _PackingProductCard(row: row, onTap: onTap, onDelete: onDelete),
      customFormOpener: (context, id) => showDialog<bool>(
        context: context,
        builder: (_) => _PackingProductFormDialog(service: service, id: id, onSessionExpired: onSessionExpired),
      ),
    );
  }
}

class _PackingProductCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PackingProductCard({required this.row, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = row['name']?.toString() ?? '';
    final middleRatio = row['middle_ratio']?.toString() ?? '-';
    final outerRatio = row['outer_ratio']?.toString() ?? '-';
    final payRate = row['pay_rate_per_unit']?.toString() ?? '-';
    final bonus = row['bonus']?.toString() ?? '-';
    final bagCapacity = row['bag_capacity']?.toString() ?? '-';
    final itemName = row['item_name']?.toString() ?? '';

    Widget infoChip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade800))),
            ],
          ),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  infoChip(Icons.layers, 'Middle: $middleRatio'),
                  if (outerRatio != '-') infoChip(Icons.inventory_2_outlined, 'Outer: $outerRatio'),
                  infoChip(Icons.payments_outlined, payRate),
                  if (bonus != '-') infoChip(Icons.card_giftcard, bonus),
                  infoChip(Icons.inventory_outlined, 'Roba: $bagCapacity'),
                  if (itemName.isNotEmpty) infoChip(Icons.link, itemName),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full carbon-copy of packing_products/form.php.
class _PackingProductFormDialog extends StatefulWidget {
  final IndustryService service;
  final int? id;
  final VoidCallback onSessionExpired;

  const _PackingProductFormDialog({required this.service, required this.id, required this.onSessionExpired});

  @override
  State<_PackingProductFormDialog> createState() => _PackingProductFormDialogState();
}

class _PackingProductFormDialogState extends State<_PackingProductFormDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;

  final _nameController = TextEditingController();
  final _unitsPerPcController = TextEditingController();
  final _unitLabelController = TextEditingController();
  final _middleQtyController = TextEditingController();
  final _middleLabelController = TextEditingController();
  final _outerQtyController = TextEditingController();
  final _outerLabelController = TextEditingController();
  final _payRateController = TextEditingController();
  final _bonusThresholdController = TextEditingController();
  final _bonusAmountController = TextEditingController();
  final _fillerBagCapacityController = TextEditingController();
  final _boxBagCapacityController = TextEditingController();
  final _itemNameController = TextEditingController();
  String _itemId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _nameController, _unitsPerPcController, _unitLabelController, _middleQtyController,
      _middleLabelController, _outerQtyController, _outerLabelController, _payRateController,
      _bonusThresholdController, _bonusAmountController, _fillerBagCapacityController,
      _boxBagCapacityController, _itemNameController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final response = await widget.service.getPackingProductForm(widget.id ?? -1);
    if (!mounted) return;

    if (response.statusCode == 440) {
      Navigator.pop(context);
      widget.onSessionExpired();
      return;
    }

    if (!response.isSuccess || response.data == null) {
      setState(() {
        _isLoading = false;
        _loadError = response.message;
      });
      return;
    }

    final data = response.data!;
    setState(() {
      _nameController.text = data.name;
      _unitsPerPcController.text = data.unitsPerPc;
      _unitLabelController.text = data.unitLabel;
      _middleQtyController.text = data.middleQty;
      _middleLabelController.text = data.middleLabel;
      _outerQtyController.text = data.outerQty;
      _outerLabelController.text = data.outerLabel;
      _payRateController.text = data.payRatePerUnit;
      _bonusThresholdController.text = data.bonusThresholdUnits;
      _bonusAmountController.text = data.bonusAmountPerUnit;
      _fillerBagCapacityController.text = data.fillerBagPcCapacity;
      _boxBagCapacityController.text = data.boxBagPcCapacity;
      _itemNameController.text = data.itemName;
      _itemId = data.itemId;
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _unitsPerPcController.text.trim().isEmpty ||
        _middleQtyController.text.trim().isEmpty ||
        _payRateController.text.trim().isEmpty) {
      setState(() => _saveError = 'Please fill in all required fields (in red)');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final response = await widget.service.savePackingProduct(
      id: widget.id,
      fields: {
        'name': _nameController.text.trim(),
        'units_per_pc': _unitsPerPcController.text.trim(),
        'unit_label': _unitLabelController.text.trim(),
        'middle_qty': _middleQtyController.text.trim(),
        'middle_label': _middleLabelController.text.trim(),
        'outer_qty': _outerQtyController.text.trim(),
        'outer_label': _outerLabelController.text.trim(),
        'pay_rate_per_unit': _payRateController.text.trim(),
        'bonus_threshold_units': _bonusThresholdController.text.trim(),
        'bonus_amount_per_unit': _bonusAmountController.text.trim(),
        'filler_bag_pc_capacity': _fillerBagCapacityController.text.trim(),
        'box_bag_pc_capacity': _boxBagCapacityController.text.trim(),
        'item_id': _itemId,
        'item_name': _itemNameController.text.trim(),
      },
    );

    if (!mounted) return;

    if (response.statusCode == 440) {
      Navigator.pop(context);
      widget.onSessionExpired();
      return;
    }

    if (response.isSuccess) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isSaving = false;
        _saveError = response.message;
      });
    }
  }

  Widget _fieldLabel(String label, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: required ? Colors.red.shade700 : Colors.black87,
          ),
        ),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
      );

  Widget _twoUp(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
      );

  Widget _numField(TextEditingController c, {String? hintText}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(border: const OutlineInputBorder(), isDense: true, hintText: hintText),
      );

  Widget _textField(TextEditingController c, {String? hintText}) => TextField(
        controller: c,
        decoration: InputDecoration(border: const OutlineInputBorder(), isDense: true, hintText: hintText),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.id == null ? 'New Packing Product' : 'Update Packing Product',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
                  : _loadError != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_loadError!, style: const TextStyle(color: Colors.red)),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: Text('Fields in red are required',
                                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54, fontSize: 12)),
                              ),
                              const SizedBox(height: 16),
                              _fieldLabel('Product Name', required: true),
                              _textField(_nameController),
                              const SizedBox(height: 14),
                              _fieldLabel('Units per PC', required: true),
                              _twoUp(
                                _numField(_unitsPerPcController),
                                _textField(_unitLabelController, hintText: 'e.g. Stick, MAT'),
                              ),
                              _hint('Informational only (e.g. 30 sticks make up 1 PC) -- stock is tracked in PC '
                                  'and up, not in loose sticks/mats.'),
                              const SizedBox(height: 14),
                              _fieldLabel('Middle Tier', required: true),
                              _twoUp(
                                _numField(_middleQtyController),
                                _textField(_middleLabelController, hintText: 'e.g. OUTER, PACKET, KIBEGI'),
                              ),
                              _hint("How many PCs make up the middle packaging unit, and what it's called."),
                              const SizedBox(height: 14),
                              _fieldLabel('Outer Tier'),
                              _twoUp(
                                _numField(_outerQtyController),
                                _textField(_outerLabelController, hintText: 'e.g. CTN -- leave blank if none'),
                              ),
                              _hint('Optional -- leave blank if the middle tier is already the final unit '
                                  '(e.g. Ridax Kibegi has no CTN stage).'),
                              const SizedBox(height: 14),
                              _fieldLabel('Pay Rate (per Final Unit)', required: true),
                              _numField(_payRateController),
                              _hint('Kiasi kinacholipwa kwa kila carton (au Kibegi) kamili aliyokamilisha -- si kwa PC.'),
                              const SizedBox(height: 14),
                              _fieldLabel('Bonus'),
                              _twoUp(
                                _numField(_bonusThresholdController, hintText: 'e.g. 7 (units, per day)'),
                                _numField(_bonusAmountController, hintText: 'e.g. 1000 (extra per unit)'),
                              ),
                              _hint('Hiari: akifikisha idadi hii ya units SIKU MOJA, kuanzia unit hiyo (siyo zote) '
                                  'analipwa Rate + Bonus kwa kila unit -- inarudi sifuri kila siku mpya. Acha wazi '
                                  'kama hakuna bonus.'),
                              const SizedBox(height: 14),
                              _fieldLabel('Uwezo wa Roba (Dawa / Box)'),
                              _twoUp(
                                _numField(_fillerBagCapacityController, hintText: 'mfano 480'),
                                _numField(_boxBagCapacityController, hintText: 'mfano 1100'),
                              ),
                              _hint('Hiari: kiasi cha kawaida cha PC kinachopatikana kwenye roba moja iliyofungwa '
                                  '(ya dawa/bidhaa na ya box), kwa bidhaa hii.'),
                              const SizedBox(height: 14),
                              _fieldLabel('Linked Item'),
                              _textField(_itemNameController),
                              _hint("The Item this product's final packed unit maps to, for Issuing into stock."),
                              if (_saveError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(_saveError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                                ),
                            ],
                          ),
                        ),
            ),
            if (!_isLoading && _loadError == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
