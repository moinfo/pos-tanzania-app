import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/credit.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../services/nfc_service.dart';
import '../../utils/constants.dart';
import '../nfc_scan_dialog.dart';
import 'credit_list_widgets.dart';

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

  /// debits_credits.paid_payment_type, as the web dialog sets it:
  /// 1 = Cash, 2 = Bank, 3 = Chip. Without this the API defaulted every
  /// payment to Cash, so a chip or bank collection was recorded as cash.
  int _paymentType = 1;

  /// The supervisor's remaining chip pool, loaded the first time Chip is
  /// picked. Null while unknown, so the sheet can say so rather than imply a
  /// zero balance.
  double? _chipBalance;
  bool _loadingChip = false;

  int? _selectedLocationId;
  bool _isSubmitting = false;

  /// One id per intended payment: retrying after a failure reuses it so the
  /// server can spot a replay, and it rotates only after a confirmed success.
  String _requestId = const Uuid().v4();

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

  /// A chip payment cannot draw more than the pool holds. Enforced server-side
  /// too; this is so the seller finds out before typing an amount they cannot
  /// take.
  bool get _overChipBalance =>
      _paymentType == 3 && _chipBalance != null && _amount > _chipBalance!;

  Future<void> _selectPaymentType(int type) async {
    setState(() => _paymentType = type);
    if (type != 3 || _chipBalance != null || _loadingChip) return;

    setState(() => _loadingChip = true);
    final response = await _apiService.getChipBalance(widget.customerId);
    if (!mounted) return;

    setState(() {
      _loadingChip = false;
      if (response.isSuccess) _chipBalance = response.data;
    });
  }

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

  Future<void> _submit() async {
    if (_amount <= 0 || _isSubmitting) return;
    // Locked BEFORE the first await: the NFC-settings fetch below used to run
    // with the button still live, and every tap in that window posted the
    // payment again -- four taps, four rows.
    setState(() => _isSubmitting = true);
    try {

    if (_overChipBalance) {
      _showError(
          'Payment exceeds the available chip balance (${_money.format(_chipBalance)} TSh)');
      return;
    }

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

    final description = _descriptionController.text.trim();
    final response = await _apiService.addCreditPayment(
      PaymentFormData(
        customerId: widget.customerId,
        amount: amount,
        paidPaymentType: _paymentType,
        stockLocationId: _selectedLocationId ??
            context.read<LocationProvider>().selectedLocation?.locationId,
        description: description.isEmpty ? null : description,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        requestId: _requestId,
      ),
    );

    if (!mounted) return;

    if (response.isSuccess) {
      _requestId = const Uuid().v4(); // consumed; a next payment is a new one
      Navigator.pop(context, true);
    } else {
      _showError(response.message);
    }

    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        decoration: BoxDecoration(
          color: creditCardBg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
                      color: creditTrack(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 14),
                _buildAmountBlock(remaining),
                const SizedBox(height: 14),
                _buildPaymentTypes(),
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
            style: TextStyle(
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: creditInkStrong(context),
                ),
              ),
              Text(
                'Balance ${_money.format(widget.currentBalance)} TSh',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: creditInkMuted(context),
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
              color: creditTrack(context),
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
        color: creditInset(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAYMENT AMOUNT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: creditInkMuted(context),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: creditInkMuted(context),
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
                Text(
                  'TSh',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: creditInkMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Payment type (4.5 addition, mirroring the web "Make Payment" dialog).
  Widget _buildPaymentTypes() {
    // Values are the ones credit_account.php posts.
    const types = {1: 'Cash', 3: 'Chip', 2: 'Bank'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAYMENT TYPE',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: creditInkMuted(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: types.entries.map((entry) {
            final selected = _paymentType == entry.key;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: entry.key == types.keys.last ? 0 : 8),
                child: GestureDetector(
                  onTap: () => _selectPaymentType(entry.key),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? creditTint(context, const Color(0xFF1D7DC4),
                              const Color(0xFFEAF3FB))
                          : creditCardBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1D7DC4)
                            : creditBorder(context),
                      ),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? (creditDark(context)
                                ? const Color(0xFF6FA8DC)
                                : const Color(0xFF1668A6))
                            : creditInkMuted(context),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_paymentType == 3) ...[
          const SizedBox(height: 8),
          Text(
            _loadingChip
                ? 'Checking chip balance…'
                : _chipBalance == null
                    ? 'Chip balance unavailable'
                    : 'Available chip balance: ${_money.format(_chipBalance)} TSh',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _overChipBalance
                  ? AppColors.error
                  : creditInkMuted(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocations() {
    final locations = context.watch<LocationProvider>().allowedLocations;
    if (locations.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STOCK LOCATION',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: creditInkMuted(context),
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
                    color: selected
                        ? creditTint(context, const Color(0xFF1D7DC4),
                            const Color(0xFFEAF3FB))
                        : creditCardBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1D7DC4)
                          : creditBorder(context),
                    ),
                  ),
                  child: Text(
                    location.locationName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? (creditDark(context)
                              ? const Color(0xFF6FA8DC)
                              : const Color(0xFF1668A6))
                          : creditInkMuted(context),
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
          color: creditTrack(context),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: creditInkStrong(context),
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
        color: creditInset(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: creditBorder(context), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.notes, size: 16, color: Color(0xFF8A94A6)),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _descriptionController,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: creditInkStrong(context),
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
    final enabled = _amount > 0 && !_isSubmitting && !_overChipBalance;

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context, false),
          child: Container(
            width: 96,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: creditTrack(context),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: creditInkStrong(context),
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
                            _overChipBalance
                                ? 'Over chip balance'
                                : _amount > 0
                                    ? 'Submit ${_money.format(_amount)}'
                                    : 'Enter amount',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
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
