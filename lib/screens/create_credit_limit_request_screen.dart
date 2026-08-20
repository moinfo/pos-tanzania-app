import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/approval.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/friendly_error.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/state_views.dart';

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
/// cleared. The copy says "one-time" throughout for that reason — calling it a
/// limit increase would mislead the seller about what they are getting.
class CreateCreditLimitRequestScreen extends StatefulWidget {
  const CreateCreditLimitRequestScreen({
    super.key,
    this.customerId,
    this.customerName,
  });

  /// The customer to ask for. Omitted when opened from the drawer or the FAB
  /// rather than from a customer row, in which case the screen asks first.
  final int? customerId;
  final String? customerName;

  @override
  State<CreateCreditLimitRequestScreen> createState() =>
      _CreateCreditLimitRequestScreenState();
}

class _CreateCreditLimitRequestScreenState
    extends State<CreateCreditLimitRequestScreen> {
  final _api = ApiService();
  final _money = NumberFormat('#,##0', 'en_US');
  final _formKey = GlobalKey<FormState>();

  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _customerSearch = TextEditingController();

  /// Resolved once a customer is known — either passed in or picked here.
  int? _customerId;
  String? _customerName;

  List<CreditScopedCustomer> _candidates = [];
  bool _searchingCustomers = false;
  Timer? _searchDebounce;

  CustomerCreditPosition? _position;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// Held across retries — see the note in the discount form.
  String? _requestId;

  /// True while the screen is still asking which customer this is about.
  bool get _picking => _customerId == null;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customerId;
    _customerName = widget.customerName;

    if (_picking) {
      _searchCustomers('');
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _amount.dispose();
    _reason.dispose();
    _notes.dispose();
    _customerSearch.dispose();
    super.dispose();
  }

  // ---- picking a customer ------------------------------------------------

  void _onCustomerSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), () => _searchCustomers(value));
  }

  Future<void> _searchCustomers(String search) async {
    setState(() {
      _searchingCustomers = true;
      _loading = false;
      _error = null;
    });

    // Deliberately the scoped list, not the app's general customer search:
    // that one applies no stock-location filter, so it would offer customers
    // whose request the server then refuses with 403.
    final response = await _api.getCreditLimitCustomers(search: search);
    if (!mounted) return;

    setState(() {
      _searchingCustomers = false;
      if (response.isSuccess && response.data != null) {
        _candidates = response.data!;
      } else {
        _error = FriendlyError.of(response.message);
      }
    });
  }

  void _selectCustomer(CreditScopedCustomer customer) {
    FocusScope.of(context).unfocus();
    setState(() {
      _customerId = customer.customerId;
      _customerName = customer.customerName;
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _clearCustomer() {
    setState(() {
      _customerId = null;
      _customerName = null;
      _position = null;
      _error = null;
      _loading = false;
    });
    if (_candidates.isEmpty) _searchCustomers('');
  }

  // ---- the request itself ------------------------------------------------

  Future<void> _load() async {
    final customerId = _customerId;
    if (customerId == null) return;

    final response = await _api.getCustomerCreditPosition(customerId);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (response.isSuccess && response.data != null) {
        _position = response.data;
      } else {
        _error = FriendlyError.of(response.message);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    _requestId ??= const Uuid().v4();

    final response = await _api.createCreditLimitRequest(
      customerId: _customerId!,
      creditAmount: double.parse(_amount.text),
      reason: _reason.text.trim(),
      notes: _notes.text.trim(),
      requestId: _requestId,
    );

    if (!mounted) return;

    if (response.isSuccess) {
      final needsApproval = response.data?['requires_approval'] == true;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
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
        _error = FriendlyError.of(response.message);
      });
    }
  }

  // ---- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(_picking ? 'Chagua Mteja' : 'Omba Mkopo wa Ziada'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Only when this screen owns the choice. Arriving from a customer
          // row, that customer is the whole point of the navigation -- and a
          // 403 or an existing pending request would otherwise strand the
          // seller with no way forward.
          if (widget.customerId == null && !_picking)
            IconButton(
              icon: const Icon(Icons.person_search),
              tooltip: 'Badilisha mteja',
              onPressed: _clearCustomer,
            ),
        ],
      ),
      body: _picking ? _buildPicker(isDark) : _buildRequest(isDark),
    );
  }

  Widget _buildPicker(bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: isDark ? AppColors.darkCard : Colors.white,
          child: TextField(
            controller: _customerSearch,
            decoration: InputDecoration(
              hintText: 'Tafuta kwa jina au namba ya simu...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchingCustomers
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_customerSearch.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _customerSearch.clear();
                            _searchCustomers('');
                          },
                        )),
            ),
            onChanged: _onCustomerSearchChanged,
          ),
        ),
        Expanded(child: _buildCandidates(isDark)),
      ],
    );
  }

  Widget _buildCandidates(bool isDark) {
    if (_searchingCustomers && _candidates.isEmpty) {
      return SkeletonRowList(isDark: isDark, itemCount: 7);
    }

    if (_error != null && _candidates.isEmpty) {
      return ErrorStateView(
        message: _error!,
        onRetry: () => _searchCustomers(_customerSearch.text),
        isDark: isDark,
      );
    }

    if (_candidates.isEmpty) {
      return EmptyStateView(
        icon: Icons.person_off_outlined,
        title: _customerSearch.text.isEmpty
            ? 'Hakuna mteja kwenye maeneo yako'
            : 'Hakuna mteja anayelingana',
        message: _customerSearch.text.isEmpty
            ? 'Wateja wa maeneo uliyopangiwa ndio wataonekana hapa.'
            : 'Jaribu jina au namba nyingine.',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final customer = _candidates[index];
        return _CustomerRow(
          customer: customer,
          index: index + 1,
          money: _money,
          isDark: isDark,
          onTap: () => _selectCustomer(customer),
        );
      },
    );
  }

  Widget _buildRequest(bool isDark) {
    if (_loading) {
      return _buildRequestSkeleton(isDark);
    }

    final position = _position;

    if (position == null) {
      return ErrorStateView(
        message: _error ?? 'Imeshindikana kupakia',
        onRetry: _load,
        isDark: isDark,
      );
    }

    // One open request at a time -- the server refuses a second with 409, so
    // there is nothing useful to show but the one already in flight.
    if (position.hasPendingRequest) {
      final pending = position.pendingRequest!;
      return EmptyStateView(
        icon: Icons.hourglass_top,
        title: 'Tayari kuna ombi linalosubiri',
        message: '${pending.documentNumber}\n'
            '${_money.format(pending.creditAmount)} TSh',
        isDark: isDark,
        action: widget.customerId == null
            ? OutlinedButton.icon(
                onPressed: _clearCustomer,
                icon: const Icon(Icons.person_search, size: 18),
                label: const Text('Chagua mteja mwingine'),
              )
            : null,
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _positionCard(position, isDark),

          if (!position.creditAllowed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _notice(
                icon: Icons.block,
                colour: AppColors.error,
                text: 'Mteja huyu hajaruhusiwa kununua kwa mkopo kabisa. '
                    'Kikomo cha ziada hakitasaidia hadi ruhusa itolewe.',
              ),
            ),

          _field(
            isDark,
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Kiasi kinachoombwa (TSh)',
                border: InputBorder.none,
                helperText: 'Kikomo cha mara moja, si ongezeko la kudumu',
              ),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Weka kiasi';
                return null;
              },
            ),
          ),

          _field(
            isDark,
            TextFormField(
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

          _field(
            isDark,
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Maelezo ya ziada (hiari)',
                border: InputBorder.none,
              ),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _notice(
                icon: Icons.error_outline,
                colour: AppColors.error,
                text: _error!,
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

  Widget _buildRequestSkeleton(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SkeletonLoader(
            width: double.infinity, height: 168, borderRadius: 16, isDark: isDark),
        const SizedBox(height: 16),
        for (var i = 0; i < 3; i++) ...[
          SkeletonLoader(
              width: double.infinity, height: 64, borderRadius: 12, isDark: isDark),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// The numbers the approver will weigh, shown before the ask is written.
  Widget _positionCard(CustomerCreditPosition position, bool isDark) {
    final used = position.creditLimit <= 0
        ? 0.0
        : (position.currentBalance / position.creditLimit).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D7DC4), Color(0xFF155E92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (_customerName ?? 'MTEJA').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_money.format(position.remainingCredit)} TSh',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'kimebaki kwenye kikomo cha sasa',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: used,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation(
                used > 0.9 ? AppColors.warning : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _line('Kikomo cha sasa', position.creditLimit),
          _line('Deni la sasa', position.currentBalance),
          if (position.hasOneTimeCredit) ...[
            const SizedBox(height: 10),
            _notice(
              icon: Icons.info_outline,
              colour: Colors.white,
              text: 'Ana kikomo cha mara moja kilichobaki: '
                  '${_money.format(position.oneTimeRemaining)} TSh',
              onGradient: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          Text(
            '${_money.format(value)} TSh',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice({
    required IconData icon,
    required Color colour,
    required String text,
    bool onGradient = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: onGradient
            ? Colors.white.withValues(alpha: 0.15)
            : colour.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: onGradient ? Colors.white70 : colour, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: onGradient ? Colors.white : colour,
                fontSize: onGradient ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(bool isDark, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

/// One customer in the picker, with enough of their position to choose.
class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.index,
    required this.money,
    required this.isDark,
    required this.onTap,
  });

  final CreditScopedCustomer customer;
  final int index;
  final NumberFormat money;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final allowed = customer.creditAllowed;

    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Route position, muted when the customer cannot take credit at
              // all -- asking for headroom they cannot use is a wasted trip.
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (allowed ? AppColors.primary : Colors.grey)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (allowed ? AppColors.primary : Colors.grey)
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: allowed ? AppColors.primary : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          customer.phoneNumber ?? '-',
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                        if (!allowed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'HARUHUSIWI MKOPO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ] else if (customer.hasOneTimeCredit) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ANA CHA ZIADA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money.format(customer.creditLimit),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkText : AppColors.text,
                    ),
                  ),
                  Text('kikomo', style: TextStyle(fontSize: 10, color: muted)),
                ],
              ),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: isDark ? AppColors.darkTextLight : Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
