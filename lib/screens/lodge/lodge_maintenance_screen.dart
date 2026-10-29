import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// `GET/POST lodge/rooms/{id}/maintenance` -- README 3.10: history + add,
/// with the option to record the cost as an expense and/or put the room
/// into maintenance status in the same submit.
class LodgeMaintenanceScreen extends StatefulWidget {
  final LodgeRoom room;

  const LodgeMaintenanceScreen({super.key, required this.room});

  @override
  State<LodgeMaintenanceScreen> createState() => _LodgeMaintenanceScreenState();
}

class _LodgeMaintenanceScreenState extends State<LodgeMaintenanceScreen> {
  final ApiService _apiService = ApiService();
  List<LodgeMaintenance> _entries = [];
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
    final response = await _apiService.getLodgeRoomMaintenance(widget.room.roomId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _entries = response.data!;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _showAddSheet() async {
    final permissions = context.read<PermissionProvider>();
    final canBackdate = permissions.hasPermission(PermissionIds.lodgeMaintenanceDate);

    final descriptionController = TextEditingController();
    final categoryController = TextEditingController();
    final doneByController = TextEditingController();
    final costController = TextEditingController();
    DateTime doneOn = DateTime.now();
    bool postExpense = false;
    bool setStatus = false;
    const paymentTypes = ['Cash', 'Bank', 'Lipa Namba'];
    String paymentType = paymentTypes.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Maintenance Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: doneByController,
                  decoration: const InputDecoration(labelText: 'Done by', border: OutlineInputBorder()),
                ),
                if (canBackdate) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: doneOn,
                        firstDate: DateTime(DateTime.now().year - 2),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setSheetState(() => doneOn = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date done', border: OutlineInputBorder()),
                      child: Text(Formatters.formatDateForApi(doneOn)),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cost (optional)', border: OutlineInputBorder()),
                  onChanged: (_) => setSheetState(() {}),
                ),
                if ((double.tryParse(costController.text) ?? 0) > 0) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Record cost as an expense'),
                    value: postExpense,
                    onChanged: (v) => setSheetState(() => postExpense = v ?? false),
                  ),
                  if (postExpense)
                    DropdownButtonFormField<String>(
                      value: paymentType,
                      decoration: const InputDecoration(labelText: 'Payment type', border: OutlineInputBorder()),
                      items: paymentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setSheetState(() => paymentType = v ?? paymentType),
                    ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Put room into maintenance status'),
                  value: setStatus,
                  onChanged: (v) => setSheetState(() => setStatus = v ?? false),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (descriptionController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Description is required'), backgroundColor: AppColors.error),
                        );
                        return;
                      }
                      Navigator.pop(sheetContext);
                      final response = await _apiService.addLodgeMaintenance(
                        roomId: widget.room.roomId,
                        description: descriptionController.text.trim(),
                        doneOn: canBackdate ? Formatters.formatDateForApi(doneOn) : null,
                        category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
                        doneBy: doneByController.text.trim().isEmpty ? null : doneByController.text.trim(),
                        cost: double.tryParse(costController.text),
                        postExpense: postExpense,
                        paymentType: postExpense ? paymentType : null,
                        setStatus: setStatus,
                      );
                      if (!mounted) return;
                      if (response.isSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Maintenance entry saved.'), backgroundColor: AppColors.success),
                        );
                        _load();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEntry(LodgeMaintenance m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry'),
        content: Text('Delete "${m.description}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await _apiService.deleteLodgeMaintenance(m.maintenanceId);
    if (!mounted) return;
    if (response.isSuccess) {
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
    final permissions = context.watch<PermissionProvider>();
    final headerColor = isDark ? AppColors.darkSurface : AppColors.brandPrimary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        title: Text('Maintenance · ${widget.room.roomNumber}'),
      ),
      floatingActionButton: permissions.hasPermission(PermissionIds.lodgeMaintenanceAdd)
          ? FloatingActionButton(
              heroTag: 'lodge_maintenance_fab',
              onPressed: _showAddSheet,
              backgroundColor: AppColors.brandPrimary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
              : _entries.isEmpty
                  ? Center(
                      child: Text('No maintenance history yet',
                          style: TextStyle(color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) {
                          final m = _entries[i];
                          return Card(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              title: Text(m.description),
                              subtitle: Text([
                                if (m.category != null) m.category!,
                                if (m.doneOn != null) Formatters.formatDate(m.doneOn),
                                if (m.doneBy != null) m.doneBy!,
                              ].join(' · ')),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (m.cost > 0) Text(Formatters.formatCurrency(m.cost)),
                                  if (permissions.hasPermission(PermissionIds.lodgeMaintenanceDelete))
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => _deleteEntry(m),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
