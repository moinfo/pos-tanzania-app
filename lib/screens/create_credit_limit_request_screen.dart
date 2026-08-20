import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/approval.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

/// Ask for more credit headroom for one customer.
///
/// The screen leads with the customer's live position — limit, what they owe,
/// what is left — because that is the argument the approver will weigh, and
/// the seller should see the same numbers before deciding what to ask for.
///
/// WHAT APPROVAL ACTUALLY GRANTS
/// -----------------------------
/// The server writes people.one_time_credit_limit and flags
/// customers.one_time_credit; it does NOT raise the customer's standing
/// credit_limit. The next credit sale consumes the allowance and the flag is
/// cleared. The copy says "one-time" throughout for that reason — calling it
/// a limit increase would mislead the seller about what they are getting.
class CreateCreditLimitRequestScreen extends StatefulWidget {
  const CreateCreditLimitRequestScreen({
    super.key,
    required this.customerId,
    this.customerName,
  });

  final int customerId;
  final String? customerName;

  @override
  State<CreateCreditLimitRequestScreen> createState() =>
      _CreateCreditLimitRequestScreenState();
}

class _CreateCreditLimitRequestScreenState
    extends State<CreateCreditLimitRequestScreen> {
  final _api = ApiService();
  final _money = NumberFormat('#,##0');
  final _formKey = GlobalKey<FormState>();

  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _notes = TextEditingController();

  CustomerCreditPosition? _position;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final response = await _api.getCustomerCreditPosition(widget.customerId);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (response.isSuccess && response.data != null) {
        _position = response.data;
      } else {
        _error = response.message;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final response = await _api.createCreditLimitRequest(
      customerId: widget.customerId,
      creditAmount: double.parse(_amount.text),
      reason: _reason.text.trim(),
      notes: _notes.text.trim(),
    );

    if (!mounted) return;

    if (response.isSuccess) {
      final needsApproval = response.data?['requires_approval'] == true;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsApproval
                ? 'Ombi limetumwa kwa idhini'
                : 'Kikomo kimekubaliwa moja kwa moja',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _submitting = false;
        _error = response.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Omba Mkopo wa Ziada'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    final position = _position;

    if (position == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(_error ?? 'Imeshindikana kupakia', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // One open request at a time — the server refuses a second with 409, so
    // there is nothing useful to show but the one already in flight.
    if (position.hasPendingRequest) {
      final pending = position.pendingRequest!;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hourglass_top, size: 52, color: AppColors.warning),
              const SizedBox(height: 14),
              Text(
                'Tayari kuna ombi linalosubiri',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${pending.documentNumber}\n'
                '${_money.format(pending.creditAmount)} TSh',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _positionCard(position, isDark),

          if (!position.creditAllowed)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.block, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mteja huyu hajaruhusiwa kununua kwa mkopo kabisa. '
                      'Kikomo cha ziada hakitasaidia hadi ruhusa itolewe.',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Kiasi kinachoombwa (TSh)',
                border: InputBorder.none,
                helperText: 'Hiki ni kikomo cha mara moja, si ongezeko la kudumu',
              ),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Weka kiasi';
                return null;
              },
            ),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Sababu',
                border: InputBorder.none,
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Andika sababu' : null,
            ),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Maelezo ya ziada (hiari)',
                border: InputBorder.none,
              ),
            ),
          ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: const Text('Tuma Ombi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionCard(CustomerCreditPosition position, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.customerName ?? 'Mteja',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _line('Kikomo cha sasa', position.creditLimit),
          _line('Deni la sasa', position.currentBalance),
          const Divider(color: Colors.white24, height: 18),
          _line('Kilichobaki', position.remainingCredit, emphasise: true),
          if (position.hasOneTimeCredit) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Ana kikomo cha mara moja kilichobaki: '
                      '${_money.format(position.oneTimeRemaining)} TSh',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, double value, {bool emphasise = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: emphasise ? 13 : 12,
            ),
          ),
          Text(
            '${_money.format(value)} TSh',
            style: TextStyle(
              color: Colors.white,
              fontSize: emphasise ? 18 : 13,
              fontWeight: emphasise ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
