import 'package:flutter/material.dart';
import '../../services/industry_service.dart';
import '../../models/industry.dart';
import '../../utils/constants.dart';
import 'managed_list_screen.dart';

class IndustryCasualLabourersScreen extends StatelessWidget {
  final IndustryService service;
  final VoidCallback onSessionExpired;

  const IndustryCasualLabourersScreen({
    super.key,
    required this.service,
    required this.onSessionExpired,
  });

  @override
  Widget build(BuildContext context) {
    return ManagedListScreen<CasualLabourer>(
      title: 'Casual Labourers',
      fields: const [
        ManagedField(formKey: 'name', label: 'Name'),
        ManagedField(formKey: 'phone_number', label: 'Phone Number'),
        ManagedField(formKey: 'device_user_id', label: 'ZKTeco Device User ID'),
        ManagedField(formKey: 'is_paid', label: 'Paid', isCheckbox: true),
      ],
      onSearch: ({required search, required limit, required offset}) =>
          service.searchCasualLabourers(search: search, limit: limit, offset: offset),
      onGetRow: service.getCasualLabourer,
      onSave: ({id, required fields}) => service.saveCasualLabourer(
        id: id,
        name: fields['name'] ?? '',
        phoneNumber: fields['phone_number'] ?? '',
        deviceUserId: fields['device_user_id'] ?? '',
        isPaid: fields['is_paid'] == '1',
      ),
      onDelete: (id) => service.deleteCasualLabourers([id]),
      rowToFields: (row) => row.toFormFields(),
      rowTitle: (row) => row['name']?.toString() ?? '',
      rowSubtitle: (row) => row['phone_number']?.toString(),
      rowId: (row) => int.tryParse(row['casual_labourer_id']?.toString() ?? '') ?? 0,
      onSessionExpired: onSessionExpired,
      itemBuilder: (context, row, onTap, onDelete) => _CasualLabourerCard(
        row: row,
        onTap: onTap,
        onDelete: onDelete,
      ),
      customFormOpener: (context, id) => showDialog<bool>(
        context: context,
        builder: (_) => _CasualLabourerFormDialog(service: service, id: id, onSessionExpired: onSessionExpired),
      ),
    );
  }
}

/// Full carbon-copy of casual_labourers/form.php: Name/Phone Number
/// (required), Device User ID, Aina ya Kazi dropdown, Mshahara wa Mwezi,
/// Line dropdown, Is Paid checkbox - all with the same hint text as web.
class _CasualLabourerFormDialog extends StatefulWidget {
  final IndustryService service;
  final int? id;
  final VoidCallback onSessionExpired;

  const _CasualLabourerFormDialog({required this.service, required this.id, required this.onSessionExpired});

  @override
  State<_CasualLabourerFormDialog> createState() => _CasualLabourerFormDialogState();
}

class _CasualLabourerFormDialogState extends State<_CasualLabourerFormDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _saveError;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _deviceUserIdController = TextEditingController();
  final _monthlySalaryController = TextEditingController();
  String? _labourerTypeId;
  String? _lineId;
  bool _isPaid = true;
  List<DropdownOption> _labourerTypes = [];
  List<DropdownOption> _productionLines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _deviceUserIdController.dispose();
    _monthlySalaryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final response = await widget.service.getCasualLabourerForm(widget.id ?? -1);
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
      _phoneController.text = data.phoneNumber;
      _deviceUserIdController.text = data.deviceUserId;
      _monthlySalaryController.text = data.monthlySalary;
      _labourerTypes = data.labourerTypes;
      _productionLines = data.productionLines;
      _labourerTypeId = data.labourerTypeId.isNotEmpty
          ? data.labourerTypeId
          : (data.labourerTypes.isNotEmpty ? data.labourerTypes.first.value : null);
      _lineId = data.lineId;
      _isPaid = widget.id == null ? true : data.isPaid;
      _isLoading = false;
    });
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      setState(() => _saveError = 'Name and Phone Number are required');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final response = await widget.service.saveCasualLabourer(
      id: widget.id,
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      deviceUserId: _deviceUserIdController.text.trim(),
      monthlySalary: _monthlySalaryController.text.trim(),
      labourerTypeId: _labourerTypeId ?? '',
      lineId: _lineId ?? '',
      isPaid: _isPaid,
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
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
                      widget.id == null ? 'New Casual Labourer' : 'Update Casual Labourer',
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
                              _fieldLabel('Phone Number', required: true),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              ),
                              const SizedBox(height: 14),
                              _fieldLabel('Device User ID'),
                              TextField(
                                controller: _deviceUserIdController,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              ),
                              _hint('The ID this person is enrolled under on the ZKTeco fingerprint scanner. '
                                  'Leave blank if they do not use it.'),
                              const SizedBox(height: 14),
                              _fieldLabel('Aina ya Kazi (Labourer Type)'),
                              DropdownButtonFormField<String>(
                                initialValue: _labourerTypes.any((o) => o.value == _labourerTypeId) ? _labourerTypeId : null,
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                items: _labourerTypes
                                    .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
                                    .toList(),
                                onChanged: (v) => setState(() => _labourerTypeId = v),
                              ),
                              _hint('Aina za kazi na jinsi zinavyolipwa zinasimamiwa kwenye Settings > Aina za Kazi.'),
                              const SizedBox(height: 14),
                              _fieldLabel('Mshahara wa Mwezi'),
                              TextField(
                                controller: _monthlySalaryController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              ),
                              _hint("Jaza tu kama Aina yake ya Kazi ni 'Mshahara wa Mwezi' -- kila wiki atalipwa "
                                  'sehemu ya hii kulingana na siku alizohudhuria (mshahara/30 x siku).'),
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
                                onChanged: (v) => setState(() => _lineId = v),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isPaid,
                                    onChanged: (v) => setState(() => _isPaid = v ?? true),
                                  ),
                                  const Text('Is Paid?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: _hint("Uncheck for supervisors and others who don't earn the daily wage -- "
                                    'they stay on Attendance but drop off Wages payroll.'),
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
                          : const Text('Save'),
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

class _CasualLabourerCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CasualLabourerCard({required this.row, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = row['name']?.toString() ?? '';
    final phone = row['phone_number']?.toString() ?? '-';
    final deviceUserId = row['device_user_id']?.toString() ?? '-';
    final labourerType = row['labourer_type']?.toString() ?? '-';
    final line = row['line']?.toString() ?? '-';
    final isPaidText = row['is_paid']?.toString() ?? '';
    final isPaid = isPaidText.toLowerCase() == 'yes';

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
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isPaid ? Colors.green.shade200 : Colors.orange.shade200),
                    ),
                    child: Text(
                      isPaidText.isEmpty ? '-' : isPaidText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                    ),
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
                  _infoChip(Icons.phone_outlined, phone),
                  _infoChip(Icons.fingerprint, 'ID: $deviceUserId'),
                  _infoChip(Icons.build_outlined, labourerType),
                  if (line != '-') _infoChip(Icons.linear_scale, line),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
        ],
      ),
    );
  }
}
