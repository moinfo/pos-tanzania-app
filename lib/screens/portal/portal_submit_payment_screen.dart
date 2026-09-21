import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/customer_api_service.dart';
import '../../models/contract.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../l10n/portal_locale.dart';
import '../../l10n/portal_strings.dart';
import '../../l10n/portal_language_switch.dart';

/// Customer self-service: "I paid, here's the amount and proof" --
/// submits a payment claim for staff to review (api/Portal::
/// submit_payment_request()). Doesn't touch the contract balance itself;
/// that only happens once a staff member approves it. Receipt photo is
/// mandatory -- the whole point is replacing a paper receipt that can get
/// lost with one that's in the system immediately.
class PortalSubmitPaymentScreen extends StatefulWidget {
  final Contract contract;

  const PortalSubmitPaymentScreen({super.key, required this.contract});

  @override
  State<PortalSubmitPaymentScreen> createState() =>
      _PortalSubmitPaymentScreenState();
}

class _PortalSubmitPaymentScreenState extends State<PortalSubmitPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CustomerApiService();
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  File? _receiptFile;
  String? _receiptDataUri;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final ext = image.path.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      _receiptFile = File(image.path);
      _receiptDataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';
    });
  }

  void _showReceiptSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: Text(PortalStrings.t('take_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text(PortalStrings.t('choose_from_gallery')),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_receiptDataUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PortalStrings.t('receipt_required')),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final response = await _service.submitPaymentRequest(
      contractId: widget.contract.id,
      amount: double.parse(_amountController.text.trim()),
      date: Formatters.formatDateForApi(_date),
      receiptDataUri: _receiptDataUri!,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(PortalStrings.t('payment_submitted')),
            backgroundColor: AppColors.success),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PortalLocale.instance.language,
      builder: (context, _, __) => Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          title: Text(PortalStrings.t('submit_payment')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: const [PortalLanguageSwitch()],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                PortalStrings.t('submit_payment_intro'),
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: PortalStrings.t('amount_paid'),
                  prefixText: 'TSH ',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) {
                    return PortalStrings.t('enter_valid_amount');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                    Formatters.formatDate(Formatters.formatDateForApi(_date))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(44),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 20),
              Text(PortalStrings.t('receipt_photo'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showReceiptSourceSheet,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _receiptFile == null
                            ? Colors.grey.shade300
                            : AppColors.primary,
                        style: BorderStyle.solid),
                  ),
                  child: _receiptFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo,
                                size: 36, color: AppColors.textLight),
                            const SizedBox(height: 8),
                            Text(PortalStrings.t('tap_to_add_receipt'),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textLight)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_receiptFile!, fit: BoxFit.cover),
                              Positioned(
                                right: 6,
                                top: 6,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.edit,
                                        size: 14, color: Colors.white),
                                    onPressed: _showReceiptSourceSheet,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(PortalStrings.t('submit_for_review')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
