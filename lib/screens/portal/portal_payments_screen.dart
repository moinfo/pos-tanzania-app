import 'package:flutter/material.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../models/portal_contract_detail.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';

/// Full, unrestricted payment history for one contract -- the same ledger
/// embedded (capped at 15 + "show more") on the contract detail screen,
/// as its own dedicated page reachable from the contract's menu.
class PortalPaymentsScreen extends StatefulWidget {
  final Contract contract;

  const PortalPaymentsScreen({super.key, required this.contract});

  @override
  State<PortalPaymentsScreen> createState() => _PortalPaymentsScreenState();
}

class _PortalPaymentsScreenState extends State<PortalPaymentsScreen> {
  final _service = CustomerApiService();
  PortalContractDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await _service.getContractDetail(widget.contract.id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _detail = response.data;
      } else {
        _error = response.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: Text(PortalStrings.t('malipo')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: const [PortalLanguageSwitch()],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildList(_detail!),
        ),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }

  Widget _buildList(PortalContractDetail detail) {
    final payments = detail.paymentsList.reversed.toList();
    if (payments.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.receipt_long, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Center(child: Text(PortalStrings.t('no_payments_yet'))),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _paymentCard(payments[index]),
    );
  }

  Widget _paymentCard(PortalPayment payment) {
    final bal = payment.runningBalance.round();
    final behind = bal > 0;
    final even = bal == 0;
    final pillColor = even
        ? AppColors.textLight
        : (behind ? AppColors.error : AppColors.success);
    final pillText = even
        ? '0'
        : (behind
            ? Formatters.formatCurrency(bal.toDouble())
            : '+${Formatters.formatCurrency(bal.abs().toDouble())}');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.date,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                    payment.description.isEmpty
                        ? PortalStrings.t('malipo')
                        : payment.description,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textLight)),
              ],
            ),
          ),
          Text('TSH ${Formatters.formatCurrency(payment.amount)}',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pillColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(pillText,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: pillColor)),
          ),
        ],
      ),
    );
  }
}
