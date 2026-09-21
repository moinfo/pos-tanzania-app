import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../models/portal_contract_detail.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';
import 'portal_submit_payment_screen.dart';

/// Full, unrestricted payment history for one contract -- the same ledger
/// embedded (capped at 15 + "show more") on the contract detail screen,
/// as its own dedicated page reachable from the contract's menu.
class PortalPaymentsScreen extends StatefulWidget {
  final Contract contract;

  /// True when shown as the portal shell's Malipo tab, under the shared
  /// [PortalTopBar] -- suppresses this screen's own Scaffold/AppBar so the
  /// two don't stack. False (default) for the standalone, pushed route from
  /// the contract detail screen's menu, which keeps its own simple AppBar.
  final bool embedded;

  const PortalPaymentsScreen(
      {super.key, required this.contract, this.embedded = false});

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
      builder: (context, _, __) {
        final body = RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _buildList(_detail!),
        );

        if (widget.embedded) {
          return ColoredBox(color: AppColors.lightBackground, child: body);
        }

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: Text(PortalStrings.t('malipo')),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: const [PortalLanguageSwitch()],
          ),
          body: body,
        );
      },
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

  Future<void> _openSubmitPayment() async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PortalSubmitPaymentScreen(contract: widget.contract),
      ),
    );
    if (submitted == true) _load();
  }

  Widget _submitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: OutlinedButton.icon(
        onPressed: _openSubmitPayment,
        icon: const Icon(Icons.add_a_photo, size: 18),
        label: Text(PortalStrings.t('submit_payment')),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(44),
        ),
      ),
    );
  }

  Widget _buildList(PortalContractDetail detail) {
    final payments = detail.paymentsList.reversed.toList();
    if (payments.isEmpty) {
      return ListView(
        children: [
          _submitButton(),
          const SizedBox(height: 60),
          const Icon(Icons.receipt_long, size: 48, color: AppColors.textLight),
          const SizedBox(height: 12),
          Center(child: Text(PortalStrings.t('no_payments_yet'))),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      itemCount: payments.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 4) : const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) return _submitButton();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _paymentCard(payments[index - 1]),
        );
      },
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
          const SizedBox(width: 6),
          if ((payment.receiptUrl ?? '').isNotEmpty)
            const Icon(Icons.receipt_long, size: 18, color: AppColors.success)
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.add_a_photo_outlined,
                  size: 18, color: AppColors.textLight),
              tooltip: PortalStrings.t('add_receipt'),
              onPressed: () => _attachReceipt(payment),
            ),
        ],
      ),
    );
  }

  Future<void> _attachReceipt(PortalPayment payment) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text(PortalStrings.t('take_photo')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text(PortalStrings.t('choose_from_gallery')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await picker.pickImage(
        source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final ext = image.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';

    final response = await _service.attachPaymentReceipt(
      contractId: widget.contract.id,
      paymentId: payment.id,
      receiptDataUri: dataUri,
    );
    if (!mounted) return;
    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PortalStrings.t('receipt_attached')),
            backgroundColor: AppColors.success),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }
}
