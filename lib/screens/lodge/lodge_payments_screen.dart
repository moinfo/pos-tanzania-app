import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_booking_detail_screen.dart';
import 'lodge_theme.dart';

/// `GET lodge/payments` -- README 3.11: totals by payment type, date range
/// (gated on lodge_payments_date_range_filter), then the list with edit/
/// delete. `editable=false` rows (the guest already checked out, the
/// payment is on the sale now) are shown locked either way.
class LodgePaymentsScreen extends StatefulWidget {
  const LodgePaymentsScreen({super.key});

  @override
  State<LodgePaymentsScreen> createState() => _LodgePaymentsScreenState();
}

class _LodgePaymentsScreenState extends State<LodgePaymentsScreen> {
  final ApiService _apiService = ApiService();
  LodgePaymentsByType? _data;
  LodgeMeta? _meta;
  bool _isLoading = true;
  String? _errorMessage;

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

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
    final results = await Future.wait([
      _apiService.getLodgePayments(
        startDate: Formatters.formatDateForApi(_startDate),
        endDate: Formatters.formatDateForApi(_endDate),
      ),
      _apiService.getLodgeMeta(),
    ]);
    if (!mounted) return;
    final response = results[0];
    final metaResponse = results[1];
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _data = response.data as LodgePaymentsByType;
      } else {
        _errorMessage = response.message;
      }
      if (metaResponse.isSuccess) _meta = metaResponse.data as LodgeMeta?;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    _load();
  }

  Future<void> _editPayment(LodgePayment p) async {
    final amountController = TextEditingController(text: p.amount.toStringAsFixed(0));
    final nightsController = TextEditingController(text: p.nights?.toString() ?? '');
    final noteController = TextEditingController(text: p.note ?? '');
    final paymentTypes = _meta?.paymentTypes ?? const ['Cash', 'Bank', 'Lipa Namba'];
    String paymentType = paymentTypes.contains(p.paymentType) ? p.paymentType : paymentTypes.first;

    final save = await showModalBottomSheet<bool>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit payment', style: LodgeTheme.display(size: 18, weight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: paymentType,
                decoration: const InputDecoration(labelText: 'Payment type', border: OutlineInputBorder()),
                items: paymentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setSheetState(() => paymentType = v ?? paymentType),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nightsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nights (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (save != true) return;

    final amount = double.tryParse(amountController.text);
    final response = await _apiService.editLodgePayment(
      paymentId: p.paymentId,
      amount: amount,
      paymentType: paymentType,
      nights: int.tryParse(nightsController.text),
      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
    );
    if (!mounted) return;
    if (response.isSuccess) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deletePayment(LodgePayment p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment'),
        content: const Text("The guest's balance will increase by this amount."),
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

    final response = await _apiService.deleteLodgePayment(p.paymentId);
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: LodgeTheme.appBar(
        isDark: isDark,
        eyebrow: 'Takings',
        title: 'Payments',
        actions: [
          if (permissions.hasPermission(PermissionIds.lodgePaymentsDateRangeFilter))
            IconButton(icon: const Icon(Icons.date_range, size: 20), onPressed: _pickRange),
        ],
      ),
      body: _buildBody(isDark, permissions),
    );
  }

  Widget _buildBody(bool isDark, PermissionProvider permissions) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    final canEdit = permissions.hasPermission(PermissionIds.lodgePaymentsEdit);
    final canDelete = permissions.hasPermission(PermissionIds.lodgePaymentsDelete);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '${Formatters.formatDateForApi(_startDate)} to ${Formatters.formatDateForApi(_endDate)}',
            style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight),
          ),
          const SizedBox(height: 8),
          if (_data!.byType.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _data!.byType.entries
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Formatters.formatCompactCurrency(e.value),
                                style: LodgeTheme.display(weight: FontWeight.w700, size: 15)),
                            Text(e.key, style: LodgeTheme.body(size: 11.5, color: Colors.grey)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 12),
          ..._data!.payments.map((p) => Card(
                color: isDark ? AppColors.darkCard : Colors.white,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                ),
                elevation: 0,
                child: ListTile(
                  dense: true,
                  leading: !p.editable ? const Icon(Icons.lock_outline, size: 18) : null,
                  title: Text('${p.paymentType} · ${Formatters.formatCurrency(p.amount)}'),
                  subtitle: Text(
                      '${Formatters.formatDate(p.paymentTime)}${p.receivedByName != null ? ' · ${p.receivedByName}' : ''}'),
                  trailing: p.editable && (canEdit || canDelete)
                      ? PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'edit') _editPayment(p);
                            if (action == 'delete') _deletePayment(p);
                          },
                          itemBuilder: (_) => [
                            if (canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            if (canDelete) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        )
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LodgeBookingDetailScreen(bookingId: p.bookingId)),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
