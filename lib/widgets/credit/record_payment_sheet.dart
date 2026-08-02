import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/credit.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../services/nfc_service.dart';
import '../../utils/constants.dart';
import '../nfc_scan_dialog.dart';

/// Record-payment sheet (design_handoff_home_credit 4.5).
///
/// Replaces the centre dialog: a keypad beats a keyboard for entering round
/// cash amounts one-handed, and the sheet keeps the customer's balance on
/// screen while the seller types.
///
/// The NFC confirmation step from the dialog is preserved exactly -- customers
/// carrying `nfc_confirm_required` must still tap their card before the payment
/// posts, and that guard is the whole point of the flag.
class RecordPaymentSheet extends StatefulWidget {
  final int customerId;
  final String customerName;
  final double currentBalance;

  const RecordPaymentSheet({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentBalance,
  });

  /// Returns true when a payment was recorded, so the caller can refresh.
  static Future<bool> show(
    BuildContext context, {
    required int customerId,
    required String customerName,
    required double currentBalance,
  }) async {
    final recorded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x73041A3D),
      builder: (_) => RecordPaymentSheet(
        customerId: customerId,
        customerName: customerName,
        currentBalance: currentBalance,
      ),
    );

    return recorded ?? false;
  }

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  static final NumberFormat _money = NumberFormat('#,###');

  final ApiService _apiService = ApiService();
  final TextEditingController _descriptionController = TextEditingController();

  /// Digits as typed. Kept as a string so the keypad can append and backspace
  /// without the round-tripping a double would need.
  String _digits = '';
  int? _selectedLocationId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedLocationId =
        context.read<LocationProvider>().selectedLocation?.locationId;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_digits) ?? 0;

  void _append(String value) {
    if (_digits.length + value.length > 12) return;

    final next = (_digits + value).replaceFirst(RegExp(r'^0+(?=\d)'), '');

    // Capped at the outstanding balance: overpaying a credit account is
    // almost always a typo, and the API has no concept of a credit note.
    final capped = (double.tryParse(next) ?? 0) > widget.currentBalance
        ? widget.currentBalance.round().toString()
        : next;

    setState(() => _digits = capped);
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _setAmount(double value) {
    setState(() => _digits = value.round().toString());
  }

  Future<void> _submit() async {
    if (_amount <= 0 || _isSubmitting) return;

    final amount = _amount;

    // NFC gate first: nothing is posted until the customer has confirmed.
    final nfcSettings = await _apiService.getCustomerNfcSettings(widget.customerId);
    if (nfcSettings.isSuccess && nfcSettings.data?.nfcConfirmRequired == true) {
      final cards = await _apiService.getCustomerCards(widget.customerId);
      if (!cards.isSuccess || cards.data == null || cards.data!.isEmpty) {
        _showError('Customer requires NFC confirmation but has no card linked');
        return;
      }

      final card = cards.data!.first;
      if (!mounted) return;

      final confirmed = await showDialog<NfcScanResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => NfcScanDialog(
          title: 'Confirm Payment',
          subtitle:
              'Customer must scan NFC card to confirm payment of TZS ${_money.format(amount)}',
          expectedCardUid: card.cardUid,
          lookupCustomer: false,
        ),
      );

      if (confirmed == null || !confirmed.success) {
        _showError('Payment cancelled - NFC confirmation required');
        return;
      }

      await _apiService.confirmPaymentWithNfc(
        cardUid: card.cardUid,
        amount: amount,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    final description = _descriptionController.text.trim();
    final response = await _apiService.addCreditPayment(
      PaymentFormData(
        customerId: widget.customerId,
        amount: amount,
        stockLocationId: _selectedLocationId ??
            context.read<LocationProvider>().selectedLocation?.locationId,
        description: description.isEmpty ? null : description,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response.isSuccess) {
      Navigator.pop(context, true);
    } else {
      _showError(response.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.currentBalance - _amount;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 14),
                _buildAmountBlock(remaining),
                const SizedBox(height: 10),
                _buildPresets(),
                const SizedBox(height: 14),
                _buildLocations(),
                const SizedBox(height: 14),
                _buildKeypad(),
                const SizedBox(height: 12),
                _buildDescription(),
                const SizedBox(height: 14),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1D7DC4),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            _initials(widget.customerName),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF103863),
                ),
              ),
              Text(
                'Balance ${_money.format(widget.currentBalance)} TSh',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5C6675),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context, false),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.close, size: 18, color: Color(0xFF5C6675)),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountBlock(double remaining) {
    final zero = _amount <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAYMENT AMOUNT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF6B7684),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  zero
                      ? 'Enter the amount received'
                      : remaining <= 0
                          ? 'Clears the full balance'
                          : 'Leaves ${_money.format(remaining)} TSh',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C6675),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    zero ? '0' : _money.format(_amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                      color: zero
                          ? const Color(0xFF9AA5B4)
                          : const Color(0xFF103863),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'TSh',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7684),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    final presets = <String, double>{
      'Full ${_money.format(widget.currentBalance)}': widget.currentBalance,
      'Half': widget.currentBalance / 2,
      '500,000': 500000,
    };

    return Row(
      children: presets.entries.map((entry) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: entry.key == presets.keys.last ? 0 : 8),
            child: GestureDetector(
              onTap: () => _setAmount(entry.value),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1668A6),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocations() {
    final locations = context.watch<LocationProvider>().allowedLocations;
    if (locations.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STOCK LOCATION',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: Color(0xFF6B7684),
          ),
        ),
        const SizedBox(height: 8),
        // Scrolls rather than wrapping: a seller with many stores would
        // otherwise push the keypad off the sheet.
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: locations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final location = locations[index];
              final selected = location.locationId == _selectedLocationId;

              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedLocationId = location.locationId),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEAF3FB) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1D7DC4)
                          : const Color(0xFFE6EBF2),
                    ),
                  ),
                  child: Text(
                    location.locationName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? const Color(0xFF1668A6)
                          : const Color(0xFF5C6675),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeypad() {
    const keys = [
      '1', '2', '3', //
      '4', '5', '6',
      '7', '8', '9',
      '000', '0', '⌫',
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.3,
      children: keys.map((key) {
        return Material(
          color: const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => key == '⌫' ? _backspace() : _append(key),
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: key == '⌫'
                  ? const Icon(Icons.backspace_outlined,
                      size: 20, color: Color(0xFF103863))
                  : Text(
                      key,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF103863),
                      ),
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescription() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6EBF2), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.notes, size: 16, color: Color(0xFF8A94A6)),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _descriptionController,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF103863),
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Note (optional)',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A94A6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final enabled = _amount > 0 && !_isSubmitting;

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context, false),
          child: Container(
            width: 96,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: GestureDetector(
            onTap: enabled ? _submit : null,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: enabled ? null : const Color(0xFFC3CBD8),
                gradient: enabled
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1D7DC4), Color(0xFF103863)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(15),
                boxShadow: enabled
                    ? const [
                        BoxShadow(
                          color: Color(0x42103863),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 19, color: Colors.white),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            _amount > 0
                                ? 'Submit ${_money.format(_amount)}'
                                : 'Enter amount',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// Initials, skipping non-letter tokens so "Mija (sembe) Mapinga" gives MM.
  static String _initials(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceAll(RegExp(r'[^A-Za-z]'), ''))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }
}
