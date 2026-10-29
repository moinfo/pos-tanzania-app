import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/lodge.dart';
import '../../models/permission_model.dart';
import '../../providers/permission_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import 'lodge_statement_screen.dart';

/// `GET lodge/bookings/{id}` + the action set the README lists under 3.2:
/// Check in, Check out, Pay, Statement for Phase 1 (Extend/Move/Edit/Cancel/
/// Tuma ujumbe come in later phases).
class LodgeBookingDetailScreen extends StatefulWidget {
  final int bookingId;

  const LodgeBookingDetailScreen({super.key, required this.bookingId});

  @override
  State<LodgeBookingDetailScreen> createState() => _LodgeBookingDetailScreenState();
}

class _LodgeBookingDetailScreenState extends State<LodgeBookingDetailScreen> {
  final ApiService _apiService = ApiService();

  LodgeBooking? _booking;
  LodgeMeta? _meta;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isBusy = false;

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
      _apiService.getLodgeBooking(widget.bookingId),
      _apiService.getLodgeMeta(),
    ]);
    if (!mounted) return;

    final bookingResponse = results[0];
    final metaResponse = results[1];

    setState(() {
      _isLoading = false;
      if (bookingResponse.isSuccess) {
        _booking = bookingResponse.data as LodgeBooking;
      } else {
        _errorMessage = bookingResponse.message;
      }
      if (metaResponse.isSuccess) {
        _meta = metaResponse.data as LodgeMeta;
      }
    });
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
        title: Text(_booking?.guestName ?? 'Booking'),
        actions: [
          if (_booking != null && permissions.hasPermission(PermissionIds.lodgeStatement))
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Statement',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LodgeStatementScreen(bookingId: widget.bookingId)),
              ),
            ),
        ],
      ),
      body: _buildBody(isDark, permissions),
    );
  }

  Widget _buildBody(bool isDark, PermissionProvider permissions) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null || _booking == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Haikupatikana', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Jaribu tena')),
            ],
          ),
        ),
      );
    }

    final b = _booking!;
    final ledger = b.ledger;
    final cs = _meta?.currencySymbol ?? '';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _card(
            isDark,
            children: [
              _statusChip(b.status, isDark),
              const SizedBox(height: 10),
              _infoRow('Chumba', b.roomNumber ?? '-', isDark),
              _infoRow('Simu', b.guestPhone ?? '-', isDark),
              _infoRow('Wageni', '${b.numGuests}', isDark),
              _infoRow('Check-in', Formatters.formatDate(b.checkInDate), isDark),
              _infoRow('Check-out', Formatters.formatDate(b.checkOutDate), isDark),
              _infoRow('Bei/usiku', '$cs ${Formatters.formatCurrency(b.ratePerNight)}', isDark),
              if (b.notes != null && b.notes!.isNotEmpty)
                _infoRow('Maelezo', b.notes!, isDark),
            ],
          ),
          if (ledger != null) ...[
            const SizedBox(height: 12),
            _card(
              isDark,
              title: 'Hesabu',
              children: [
                _infoRow('Amelipa', '$cs ${Formatters.formatCurrency(ledger.paid)}', isDark),
                _infoRow('Amelipia mpaka',
                    ledger.paidThrough != null ? Formatters.formatDate(ledger.paidThrough) : '-',
                    isDark),
                _infoRow(
                  'Anadaiwa leo',
                  '$cs ${Formatters.formatCurrency(ledger.balanceNow)}',
                  isDark,
                  valueColor: ledger.balanceNow > 0 ? AppColors.error : AppColors.success,
                ),
                _infoRow('Jumla ya salio (mpaka check-out)',
                    '$cs ${Formatters.formatCurrency(ledger.balancePlanned)}', isDark),
                if (ledger.overstay)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Amezidisha muda',
                        style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
          if (b.payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              isDark,
              title: 'Malipo',
              children: b.payments
                  .map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${p.paymentType} · ${Formatters.formatDate(p.paymentTime)}',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
                            ),
                            Text('$cs ${Formatters.formatCurrency(p.amount)}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          _buildActions(b, isDark, permissions),
        ],
      ),
    );
  }

  Widget _buildActions(LodgeBooking b, bool isDark, PermissionProvider permissions) {
    final buttons = <Widget>[];

    if (b.status == 'reserved' && permissions.hasPermission(PermissionIds.lodgeCheckin)) {
      buttons.add(ElevatedButton.icon(
        onPressed: _isBusy ? null : _checkin,
        icon: const Icon(Icons.login),
        label: const Text('Check in'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
      ));
    }

    if (b.status == 'checked_in') {
      if (permissions.hasPermission(PermissionIds.lodgePaymentsAdd)) {
        buttons.add(OutlinedButton.icon(
          onPressed: _isBusy ? null : _showPaymentSheet,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Lipa'),
        ));
      }
      if (permissions.hasPermission(PermissionIds.lodgeCheckout)) {
        buttons.add(ElevatedButton.icon(
          onPressed: _isBusy ? null : _showCheckoutSheet,
          icon: const Icon(Icons.logout),
          label: const Text('Check out'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brandPrimary, foregroundColor: Colors.white),
        ));
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 10, runSpacing: 10, children: buttons);
  }

  Widget _card(bool isDark, {String? title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.lightText)),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: isDark ? AppColors.darkTextLight : AppColors.lightTextLight)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? (isDark ? AppColors.darkText : AppColors.lightText))),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status, bool isDark) {
    final labels = {
      'reserved': 'Amehifadhi',
      'checked_in': 'Yupo',
      'checked_out': 'Ameondoka',
      'cancelled': 'Imeghairiwa',
      'no_show': 'Hakuja',
    };
    final colors = {
      'reserved': AppColors.info,
      'checked_in': AppColors.success,
      'checked_out': Colors.grey,
      'cancelled': AppColors.error,
      'no_show': AppColors.error,
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(labels[status] ?? status,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
    );
  }

  Future<void> _checkin() async {
    setState(() => _isBusy = true);
    final response = await _apiService.checkinLodgeBooking(widget.bookingId);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (response.isSuccess) {
      setState(() => _booking = response.data);
      _showSnack('Ameingia.', success: true);
    } else {
      _showSnack(response.message, success: false);
    }
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: success ? AppColors.success : AppColors.error),
    );
  }

  Future<void> _showPaymentSheet() async {
    final booking = _booking!;
    final ledger = booking.ledger;
    final rate = ledger?.rate ?? booking.ratePerNight;
    final paymentTypes = _meta?.paymentTypes ?? const ['Cash', 'Bank', 'Lipa Namba'];

    final nightsController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String paymentType = paymentTypes.first;
    bool updatingFromNights = false;
    bool updatingFromAmount = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void onNightsChanged(String v) {
              if (updatingFromAmount) return;
              final n = int.tryParse(v);
              updatingFromNights = true;
              amountController.text = n != null ? (n * rate).toStringAsFixed(0) : '';
              updatingFromNights = false;
            }

            void onAmountChanged(String v) {
              if (updatingFromNights) return;
              final a = double.tryParse(v);
              updatingFromAmount = true;
              nightsController.text =
                  (a != null && rate > 0) ? (a / rate).floor().toString() : '';
              updatingFromAmount = false;
            }

            return Padding(
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
                  const Text('Pokea malipo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nightsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Analipia usiku ngapi', border: OutlineInputBorder()),
                    onChanged: (v) {
                      onNightsChanged(v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kiasi', border: OutlineInputBorder()),
                    onChanged: (v) {
                      onAmountChanged(v);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: paymentType,
                    decoration: const InputDecoration(labelText: 'Aina ya malipo', border: OutlineInputBorder()),
                    items: paymentTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => paymentType = v ?? paymentType),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Maelezo (hiari)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) {
                          _showSnack('Weka kiasi sahihi', success: false);
                          return;
                        }
                        Navigator.pop(sheetContext);
                        await _submitPayment(
                          amount: amount,
                          paymentType: paymentType,
                          nights: int.tryParse(nightsController.text),
                          note: noteController.text.isEmpty ? null : noteController.text,
                        );
                      },
                      child: const Text('Pokea malipo'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitPayment({
    required double amount,
    required String paymentType,
    int? nights,
    String? note,
  }) async {
    setState(() => _isBusy = true);
    final response = await _apiService.addLodgePayment(
      bookingId: widget.bookingId,
      amount: amount,
      paymentType: paymentType,
      nights: nights,
      note: note,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (response.isPending) {
      _showSnack(response.message, success: true);
      return;
    }
    if (response.isSuccess && response.data != null) {
      setState(() => _booking = response.data);
      final paidThrough = response.data!.ledger?.paidThrough;
      _showSnack(
        paidThrough != null
            ? 'Amelipia mpaka ${Formatters.formatDate(paidThrough)}.'
            : 'Malipo yamepokelewa.',
        success: true,
      );
    } else {
      _showSnack(response.message, success: false);
    }
  }

  Future<void> _showCheckoutSheet() async {
    final booking = _booking!;
    final ledger = booking.ledger;
    final rate = ledger?.rate ?? booking.ratePerNight;
    final paymentTypes = _meta?.paymentTypes ?? const ['Cash', 'Bank', 'Lipa Namba'];

    final defaultNights = ledger?.nightsSoFar ?? 1;
    final total = defaultNights * rate;
    final alreadyPaid = ledger?.paid ?? booking.amountPaid;
    final defaultBalance = (total - alreadyPaid).clamp(0, double.infinity).toDouble();

    final nightsController = TextEditingController(text: defaultNights.toString());
    final amountNowController = TextEditingController(text: defaultBalance.toStringAsFixed(0));
    String paymentType = paymentTypes.first;
    bool onCredit = false;
    final canPutOnCredit = booking.customerId != null &&
        (booking.creditAllowed ?? false) &&
        context.read<PermissionProvider>().hasPermission(PermissionIds.lodgeCredit);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final nights = int.tryParse(nightsController.text) ?? defaultNights;
            final jumla = nights * rate;
            final salio = (jumla - alreadyPaid).clamp(0, double.infinity).toDouble();
            final paidNow = double.tryParse(amountNowController.text) ?? 0;
            final remaining = (salio - paidNow).clamp(0, double.infinity).toDouble();

            return Padding(
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
                  const Text('Check out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nightsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Usiku', border: OutlineInputBorder()),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Text('Jumla: ${_meta?.currencySymbol ?? ''} ${Formatters.formatCurrency(jumla)}'),
                  Text('Amelipa: ${_meta?.currencySymbol ?? ''} ${Formatters.formatCurrency(alreadyPaid)}'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountNowController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: 'Analipa sasa (salio: ${_meta?.currencySymbol ?? ''} ${Formatters.formatCurrency(salio)})',
                        border: const OutlineInputBorder()),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: paymentType,
                    decoration: const InputDecoration(labelText: 'Aina ya malipo', border: OutlineInputBorder()),
                    items: paymentTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => paymentType = v ?? paymentType),
                  ),
                  if (remaining > 0.009) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          'Salio ${_meta?.currencySymbol ?? ''} ${Formatters.formatCurrency(remaining)}',
                          style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
                    ),
                    if (canPutOnCredit)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Weka salio kwenye mkopo wa ${booking.guestName}'),
                        value: onCredit,
                        onChanged: (v) => setSheetState(() => onCredit = v),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Lipa salio kwanza, au unganisha mgeni na akaunti ya mteja kwenye kuhariri booking.',
                          style: TextStyle(fontSize: 12, color: AppColors.warning),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _submitCheckout(
                          nights: nights,
                          amountPaidNow: paidNow,
                          paymentType: paymentType,
                          onCredit: remaining > 0.009 && onCredit,
                        );
                      },
                      child: const Text('Kamilisha check out'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitCheckout({
    required int nights,
    required double amountPaidNow,
    required String paymentType,
    required bool onCredit,
  }) async {
    setState(() => _isBusy = true);
    final response = await _apiService.checkoutLodgeBooking(
      bookingId: widget.bookingId,
      nights: nights,
      amountPaidNow: amountPaidNow,
      paymentType: paymentType,
      onCredit: onCredit,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (response.isSuccess && response.data != null) {
      setState(() => _booking = response.data!.booking);
      _showSnack('Check out imekamilika.', success: true);
    } else if (response.statusCode == 409 && response.errors?['owing'] != null) {
      _showSnack(response.message, success: false);
    } else {
      _showSnack(response.message, success: false);
    }
  }
}
