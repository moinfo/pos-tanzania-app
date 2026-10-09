import 'package:flutter/material.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'managed_list_screen.dart';

class IndustryMachinesScreen extends StatelessWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryMachinesScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  Widget build(BuildContext context) {
    return ManagedListScreen<IndustryMachine>(
      title: 'Machines',
      fields: const [
        ManagedField(formKey: 'name', label: 'Name'),
        ManagedField(formKey: 'type', label: 'Type'),
        ManagedField(formKey: 'ctn_item_name', label: 'Carton Item'),
        ManagedField(formKey: 'reject_ctn_item_name', label: 'Reject Carton Item'),
      ],
      onSearch: ({required search, required limit, required offset}) =>
          service.searchMachines(search: search, limit: limit, offset: offset),
      onGetRow: service.getMachine,
      onSave: ({id, required fields}) => service.saveMachine(
        id: id,
        name: fields['name'] ?? '',
        type: fields['type'] ?? '',
        ctnItemName: fields['ctn_item_name'] ?? '',
        rejectCtnItemName: fields['reject_ctn_item_name'] ?? '',
      ),
      onDelete: (id) => service.deleteMachines([id]),
      rowToFields: (row) => row.toFormFields(),
      rowTitle: (row) => row['name']?.toString() ?? '',
      rowSubtitle: (row) => '${row['type'] ?? ''} · ${row['line'] ?? '-'}',
      rowId: (row) => int.tryParse(row['machine_id']?.toString() ?? '') ?? 0,
      onSessionExpired: onSessionExpired,
      itemBuilder: (context, row, onTap, onDelete) => _MachineCard(row: row, onTap: onTap, onDelete: onDelete),
      customFormOpener: (context, id) => showDialog<bool>(
        context: context,
        builder: (_) => _MachineFormDialog(service: service, id: id, onSessionExpired: onSessionExpired),
      ),
    );
  }
}

class _MachineCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MachineCard({required this.row, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = row['name']?.toString() ?? '';
    final type = row['type']?.toString() ?? '-';
    final line = row['line']?.toString() ?? '-';
    final ctnItem = row['ctn_item_name']?.toString() ?? '';
    final rejectItem = row['reject_ctn_item_name']?.toString() ?? '';

    Widget infoChip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
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
                  Expanded(
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(type,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
                  ),
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
                  if (line != '-') infoChip(Icons.linear_scale, line),
                  if (ctnItem.isNotEmpty) infoChip(Icons.inbox_outlined, ctnItem),
                  if (rejectItem.isNotEmpty) infoChip(Icons.remove_shopping_cart_outlined, rejectItem),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full carbon-copy of machines/form.php: Name/Type (required), Line,
/// CTN Item, Reject Item (Mbovu) - with the same dropdown-driven save
/// contract as web (raw type value + line_id, not display labels).
class _MachineFormDialog extends StatefulWidget {
  final IndustryService service;
  final int? id;
  final VoidCallback onSessionExpired;

  const _MachineFormDialog({required this.service, required this.id, required this.onSessionExpired});

  @override
  State<_MachineFormDialog> createState() => _MachineFormDialogState();
}

class _MachineFormDialogState extends State<_MachineFormDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;

  final _nameController = TextEditingController();
  final _ctnItemController = TextEditingController();
  final _rejectItemController = TextEditingController();
  String _type = 'auto';
  String _lineId = '';
  List<DropdownOption> _productionLines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ctnItemController.dispose();
    _rejectItemController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final response = await widget.service.getMachineForm(widget.id ?? -1);
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
      _ctnItemController.text = data.ctnItemName;
      _rejectItemController.text = data.rejectCtnItemName;
      _type = data.type.isNotEmpty ? data.type : 'auto';
      _productionLines = data.productionLines;
      _lineId = data.lineId;
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _saveError = 'Name is required');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final response = await widget.service.saveMachine(
      id: widget.id,
      name: _nameController.text.trim(),
      type: _type,
      lineId: _lineId,
      ctnItemName: _ctnItemController.text.trim(),
      rejectCtnItemName: _rejectItemController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
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
                      widget.id == null ? 'New Machine' : 'Update Machine',
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
                              _fieldLabel('Name', required: true),
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              ),
                              const SizedBox(height: 14),
                              _fieldLabel('Type', required: true),
                              DropdownButtonFormField<String>(
                                initialValue: _type,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                items: const [
                                  DropdownMenuItem(value: 'auto', child: Text('Auto')),
                                  DropdownMenuItem(value: 'manual', child: Text('Manual')),
                                ],
                                onChanged: (v) => setState(() => _type = v ?? 'auto'),
                              ),
                              const SizedBox(height: 14),
                              _fieldLabel('Line'),
                              DropdownButtonFormField<String>(
                                initialValue: _productionLines.any((o) => o.value == _lineId) ? _lineId : '',
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('-- Bila Line --')),
                                  ..._productionLines
                                      .where((o) => o.value.isNotEmpty)
                                      .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label))),
                                ],
                                onChanged: (v) => setState(() => _lineId = v ?? ''),
                              ),
                              const SizedBox(height: 14),
                              _fieldLabel('CTN Item'),
                              TextField(
                                controller: _ctnItemController,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              ),
                              const SizedBox(height: 14),
                              _fieldLabel('Reject Item (Mbovu)'),
                              TextField(
                                controller: _rejectItemController,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              ),
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
