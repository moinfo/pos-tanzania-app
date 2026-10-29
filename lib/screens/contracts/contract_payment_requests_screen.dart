import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contract_extras.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'contract_theme.dart';

/// Staff review queue for customer-submitted payment claims (amount +
/// receipt photo). Approving applies it as a real payment; rejecting
/// leaves the ledger untouched. Mirrors web Contracts::paymentRequests().
class ContractPaymentRequestsScreen extends StatefulWidget {
  const ContractPaymentRequestsScreen({super.key});

  @override
  State<ContractPaymentRequestsScreen> createState() => _ContractPaymentRequestsScreenState();
}

class _ContractPaymentRequestsScreenState extends State<ContractPaymentRequestsScreen> {
  final ApiService _apiService = ApiService();
  List<ContractPaymentRequest>? _requests;
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _busyIds = {};

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
    final response = await _apiService.getContractPaymentRequests();
    setState(() {
      _isLoading = false;
      if (response.isSuccess && response.data != null) {
        _requests = response.data;
      } else {
        _errorMessage = response.message;
      }
    });
  }

  Future<void> _approve(ContractPaymentRequest r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve payment'),
        content: Text(
            'Approve ${Formatters.formatCurrency(r.amount)} from ${r.contractName}? This records it as a real payment immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(r.id));
    final response = await _apiService.approveContractPaymentRequest(r.id);
    if (!mounted) return;
    setState(() => _busyIds.remove(r.id));

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment approved.'), backgroundColor: AppColors.success),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _reject(ContractPaymentRequest r) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject ${Formatters.formatCurrency(r.amount)} from ${r.contractName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(r.id));
    final response = await _apiService.rejectContractPaymentRequest(
      r.id,
      reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busyIds.remove(r.id));

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment rejected.'), backgroundColor: AppColors.success),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  void _viewReceipt(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, errorBuilder: (_, __, ___) => const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Could not load receipt image'),
          )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: ContractTheme.appBar(isDark: isDark, eyebrow: 'Review', title: 'Payment requests'),
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
              : (_requests == null || _requests!.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.task_alt, size: 48, color: isDark ? AppColors.darkTextLight : AppColors.textLight),
                            const SizedBox(height: 12),
                            Text('All caught up',
                                style: ContractTheme.display(
                                    size: 18, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                            const SizedBox(height: 4),
                            Text('No payment requests awaiting review',
                                style: ContractTheme.body(size: 13.5, color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Awaiting review',
                                  style: ContractTheme.display(
                                      size: 17, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(999)),
                                child: Text('${_requests!.length} pending',
                                    style: ContractTheme.body(size: 12, weight: FontWeight.w600, color: const Color(0xFF92400E))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._requests!.map((r) {
                            final busy = _busyIds.contains(r.id);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(r.contractName,
                                                style: ContractTheme.display(
                                                    size: 22, weight: FontWeight.w700, color: isDark ? AppColors.darkText : AppColors.text)),
                                            if (r.contractPhone != null && r.contractPhone!.isNotEmpty)
                                              Text(r.contractPhone!,
                                                  style: ContractTheme.body(
                                                      size: 14, color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                                          ],
                                        ),
                                      ),
                                      Text(Formatters.formatCurrency(r.amount),
                                          style: ContractTheme.display(size: 24, weight: FontWeight.w700, color: AppColors.primary)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Submitted ${Formatters.formatDate(r.date)}',
                                          style: ContractTheme.body(
                                              size: 13, color: isDark ? AppColors.darkTextLight : AppColors.textLight)),
                                      if (r.receiptUrl.isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () => _viewReceipt(r.receiptUrl),
                                          icon: const Icon(Icons.receipt_long, size: 18),
                                          label: const Text('View receipt'),
                                          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (busy)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
                                  else
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _reject(r),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFFB91C1C),
                                              side: const BorderSide(color: AppColors.error),
                                              minimumSize: const Size.fromHeight(46),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            ),
                                            child: const Text('Reject'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _approve(r),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF047857),
                                              foregroundColor: Colors.white,
                                              minimumSize: const Size.fromHeight(46),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            ),
                                            child: const Text('Approve'),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}
