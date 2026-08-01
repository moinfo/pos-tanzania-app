import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../utils/sale_design.dart';
import 'keypad_sheet.dart';

final NumberFormat _money = NumberFormat('#,##0', 'en_US');

/// Shows a sale bottom sheet with the handoff's scrim and slide-up animation.
Future<T?> showSaleSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: SaleColors.scrim,
    builder: builder,
  );
}

/// Quantity sheet -- opened by tapping a cart line's quantity pill.
///
/// The value is applied live as the seller types, so there is no cancel: the
/// caller receives every change through [onChanged] and "Done" just closes.
class QuantitySheet extends StatefulWidget {
  final String itemName;
  final double initialQuantity;
  final ValueChanged<double> onChanged;

  const QuantitySheet({
    super.key,
    required this.itemName,
    required this.initialQuantity,
    required this.onChanged,
  });

  @override
  State<QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<QuantitySheet> {
  late String _buffer;

  @override
  void initState() {
    super.initState();
    _buffer = widget.initialQuantity.toStringAsFixed(0);
  }

  /// Quantity never drops below 1 -- removing a line is the ✕, not a zero qty.
  double get _quantity {
    final parsed = double.tryParse(_buffer) ?? 0;
    return parsed < 1 ? 1 : parsed;
  }

  void _apply() => widget.onChanged(_quantity);

  void _onDigit(String digit) {
    if (_buffer.length >= 9) return;
    setState(() => _buffer = (_buffer == '0' ? '' : _buffer) + digit);
    _apply();
  }

  void _onBackspace() {
    if (_buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
    _apply();
  }

  void _setPreset(int value) {
    setState(() => _buffer = value.toString());
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    return KeypadSheet(
      label: 'QUANTITY',
      subtitle: widget.itemName,
      value: _buffer.isEmpty ? '0' : _buffer,
      valueSize: 34,
      keyHeight: 52,
      onDigit: _onDigit,
      onBackspace: _onBackspace,
      aboveKeypad: [
        Row(
          children: [
            for (final preset in const [1, 5, 10, 25, 50]) ...[
              if (preset != 1) const SizedBox(width: 7),
              Expanded(
                child: SalePresetChip(
                  label: '$preset',
                  onTap: () => _setPreset(preset),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
      ],
      footer: SaleSheetButton(
        label: 'Done',
        color: SaleColors.brand,
        pressedColor: SaleColors.brandPressed,
        onTap: () {
          _apply();
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Payment sheet -- replaces the old payment dialog. Supports split payments.
class PaymentSheet extends StatefulWidget {
  final double amountDue;
  final bool isPartPayment;

  /// Payment methods to offer. "Bank" is only present when the selected
  /// customer is allowed to use it, so the caller decides the list.
  final List<String> methods;

  final void Function(String method, double amount) onConfirm;

  const PaymentSheet({
    super.key,
    required this.amountDue,
    required this.methods,
    required this.onConfirm,
    this.isPartPayment = false,
  });

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  late String _buffer;
  late String _method;

  @override
  void initState() {
    super.initState();
    // Default to the full amount due -- one tap to confirm is the common case
    _buffer = widget.amountDue.toStringAsFixed(0);
    _method = widget.methods.first;
  }

  double get _entered => double.tryParse(_buffer) ?? 0;

  /// A payment never exceeds the balance; overpaying is not a thing here.
  double get _amount =>
      _entered > widget.amountDue ? widget.amountDue : _entered;

  bool get _coversBalance => _amount >= widget.amountDue && _amount > 0;

  void _onDigit(String digit) {
    if (_buffer.length >= 9) return;
    setState(() => _buffer = (_buffer == '0' ? '' : _buffer) + digit);
  }

  void _onBackspace() {
    if (_buffer.isEmpty) return;
    setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.amountDue - _amount;

    return KeypadSheet(
      label: widget.isPartPayment ? 'PART PAYMENT' : 'PAYMENT',
      subtitle: 'Due ${_money.format(widget.amountDue)} TSh',
      value: _money.format(_entered),
      onDigit: _onDigit,
      onBackspace: _onBackspace,
      aboveKeypad: [
        Row(
          children: [
            for (var i = 0; i < widget.methods.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: SaleChoiceChip(
                  label: widget.methods[i],
                  selected: _method == widget.methods[i],
                  onTap: () => setState(() => _method = widget.methods[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
      ],
      footer: SaleSheetButton(
        label: _coversBalance
            ? 'Complete · ${_money.format(_amount)}'
            : 'Add ${_money.format(_amount)} · ${_money.format(remaining)} left',
        icon: Icons.check_rounded,
        height: 54,
        color: SaleColors.success,
        pressedColor: SaleColors.successPressed,
        shadow: SaleShadows.successButton,
        onTap: _amount <= 0
            ? null
            : () {
                widget.onConfirm(_method, _amount);
                Navigator.pop(context);
              },
      ),
    );
  }
}
