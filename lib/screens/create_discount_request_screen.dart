import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/approval.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/friendly_error.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/state_views.dart';

/// Ask for a one-time discount on a specific item for a specific customer.
///
/// The pickers are populated from the server's form_options, which is already
/// narrowed to this employee's stock locations and the customers under those
/// locations' supervisors — so there is nothing here the seller could choose
/// that the server would then refuse for scope.
///
/// An approved request does not become a general price cut: it is one discount,
/// for one customer, on one item, on one day, consumed by a single sale whose
/// quantity matches.
class CreateDiscountRequestScreen extends StatefulWidget {
  const CreateDiscountRequestScreen({super.key, this.customerId});

  /// Pre-select a customer, for when this is opened from a sale in progress.
  final int? customerId;

  @override
  State<CreateDiscountRequestScreen> createState() =>
      _CreateDiscountRequestScreenState();
}

class _CreateDiscountRequestScreenState
    extends State<CreateDiscountRequestScreen> {
  final _api = ApiService();
  final _money = NumberFormat('#,##0', 'en_US');
  final _formKey = GlobalKey<FormState>();

  final _quantity = TextEditingController();
  final _discount = TextEditingController();
  final _reason = TextEditingController();
  final _itemSearch = TextEditingController();

  DiscountFormOptions? _options;
  List<DiscountEligibleItem> _items = [];
  Timer? _searchDebounce;

  ScopedLocation? _location;
  ScopedCustomer? _customer;
  DiscountEligibleItem? _item;
  DateTime _validDate = DateTime.now();

  bool _loading = true;
  bool _searchingItems = false;
  bool _submitting = false;
  String? _error;

  /// Held across retries so a timeout that actually committed replays the
  /// original answer instead of raising a second request.
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _quantity.addListener(_refreshPreview);
    _discount.addListener(_refreshPreview);
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _quantity.dispose();
    _discount.dispose();
    _reason.dispose();
    _itemSearch.dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  Future<void> _load() async {
    final response = await _api.getDiscountFormOptions();
    if (!mounted) return;

    if (!response.isSuccess || response.data == null) {
      setState(() {
        _loading = false;
        _error = FriendlyError.of(response.message);
      });
      return;
    }

    final options = response.data!;

    setState(() {
      _options = options;
      _loading = false;

      // One location is the common case for a seller on a route: pick it.
      if (options.locations.length == 1) {
        _location = options.locations.first;
      }

      final preset = widget.customerId;
      if (preset != null) {
        for (final candidate in options.customers) {
          if (candidate.customerId == preset) {
            _customer = candidate;
            break;
          }
        }
      }
    });

    _searchItems('');
  }

  void _onItemSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), () => _searchItems(value));
  }

  Future<void> _searchItems(String search) async {
    setState(() => _searchingItems = true);

    final response = await _api.getDiscountEligibleItems(search: search);
    if (!mounted) return;

    setState(() {
      _searchingItems = false;
      if (response.isSuccess && response.data != null) {
        _items = response.data!;
      }
    });
  }

  /// The rules the server will apply, checked here so the seller finds out
  /// before submitting rather than after.
  String? _validateDiscount(String? raw) {
    final value = double.tryParse(raw ?? '');
    if (value == null || value <= 0) return 'Weka kiasi cha punguzo';

    final item = _item;
    if (item == null) return null;

    if (value >= item.unitPrice) {
      return 'Punguzo haliwezi kufikia bei ya bidhaa '
          '(${_money.format(item.unitPrice)})';
    }
    if (item.costPrice > 0 && value >= item.costPrice) {
      return 'Punguzo haliwezi kufikia bei ya gharama '
          '(${_money.format(item.costPrice)})';
    }
    return null;
  }

  double? get _totalGiven {
    final qty = double.tryParse(_quantity.text);
    final off = double.tryParse(_discount.text);
    if (qty == null || off == null || qty <= 0 || off <= 0) return null;
    return qty * off;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_customer == null) {
      setState(() => _error = 'Chagua mteja');
      return;
    }
    if (_location == null) {
      setState(() => _error = 'Chagua eneo');
      return;
    }
    if (_item == null) {
      setState(() => _error = 'Chagua bidhaa');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    _requestId ??= const Uuid().v4();

    final response = await _api.createOneTimeDiscountRequest(
      customerId: _customer!.customerId,
      itemId: _item!.itemId,
      stockLocationId: _location!.locationId,
      quantity: double.parse(_quantity.text),
      discountAmount: double.parse(_discount.text),
      reason: _reason.text.trim(),
      validDate: DateFormat('yyyy-MM-dd').format(_validDate),
      requestId: _requestId,
    );

    if (!mounted) return;

    if (response.isSuccess) {
      // Under the bypass threshold the server activates the discount outright
      // and there is nobody to wait for -- say so rather than promising an
      // approval that will never arrive.
      final needsApproval = response.data?['requires_approval'] == true;
      final document = response.data?['document_number']?.toString() ?? '';

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            needsApproval
                ? 'Ombi $document limetumwa kwa idhini'
                : 'Punguzo $document limekubaliwa moja kwa moja',
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Omba Punguzo'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading ? _buildSkeleton(isDark) : _buildForm(isDark),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < 5; i++) ...[
          SkeletonLoader(
              width: double.infinity, height: 62, borderRadius: 12, isDark: isDark),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildForm(bool isDark) {
    final options = _options;

    if (options == null) {
      return ErrorStateView(
        message: FriendlyError.of(_error ?? 'Imeshindikana kupakia'),
        onRetry: _load,
        isDark: isDark,
      );
    }

    if (!options.canRequest) {
      return EmptyStateView(
        icon: Icons.lock_outline,
        title: 'Huna ruhusa ya kuomba punguzo',
        message: 'Wasiliana na msimamizi wako kama unahitaji ruhusa hii.',
        isDark: isDark,
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_totalGiven != null && _item != null && _customer != null)
            _preview(isDark),

          if (options.locations.length > 1)
            _field(
              isDark,
              DropdownButtonFormField<ScopedLocation>(
                value: _location,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Eneo',
                  border: InputBorder.none,
                ),
                items: options.locations
                    .map((location) => DropdownMenuItem(
                          value: location,
                          child: Text(location.locationName,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _location = value),
              ),
            ),

          // A searchable sheet, not a dropdown. A route's customer list runs to
          // a few hundred names; scrolling one to find the shop you are
          // standing in is the slowest step of the whole form.
          _field(
            isDark,
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.storefront_outlined,
                color: _customer == null
                    ? (isDark ? AppColors.darkTextLight : AppColors.textLight)
                    : AppColors.primary,
              ),
              title: Text(
                'Mteja',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ),
              subtitle: Text(
                _customer?.customerName ?? 'Gusa kuchagua',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _customer == null
                      ? (isDark ? AppColors.darkTextLight : AppColors.textLight)
                      : (isDark ? AppColors.darkText : AppColors.text),
                ),
              ),
              trailing: const Icon(Icons.search, size: 20),
              onTap: () async {
                final picked = await SearchablePicker.show<ScopedCustomer>(
                  context,
                  title: 'Chagua Mteja',
                  items: options.customers,
                  labelOf: (c) => c.customerName,
                  subtitleOf: (c) => c.phoneNumber,
                  searchHint: 'Tafuta kwa jina au namba ya simu...',
                  emptyMessage: 'Hakuna mteja anayelingana',
                );
                if (picked != null) setState(() => _customer = picked);
              },
            ),
          ),

          _buildItemPicker(isDark),

          Row(
            children: [
              Expanded(
                child: _field(
                  isDark,
                  TextFormField(
                    controller: _quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      labelText: 'Idadi',
                      border: InputBorder.none,
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed <= 0) return 'Weka idadi';
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  isDark,
                  TextFormField(
                    controller: _discount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      labelText: 'Punguzo/kimoja',
                      border: InputBorder.none,
                    ),
                    validator: _validateDiscount,
                  ),
                ),
              ),
            ],
          ),

          // The quantity is not advisory: redemption requires the sale's
          // quantity to match this to within 0.001, so say so plainly.
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Mauzo yatakayotumia punguzo lazima yawe na idadi hii hasa.',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
              ),
            ),
          ),

          if (options.canSetDate)
            _field(
              isDark,
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Tarehe ya kutumika',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                  ),
                ),
                subtitle: Text(
                  DateFormat('EEE, dd MMM yyyy').format(_validDate),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _validDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 7)),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) setState(() => _validDate = picked);
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

  /// What is actually being given away, before it is asked for.
  ///
  /// The per-unit figure understates the ask: 500 off looks small until it is
  /// multiplied by a hundred cartons. The approver will see the total, so the
  /// requester should too.
  Widget _preview(bool isDark) {
    final total = _totalGiven!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
            'JUMLA YA PUNGUZO',
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
              '${_money.format(total)} TSh',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_money.format(double.tryParse(_quantity.text) ?? 0)}'
            ' × ${_money.format(double.tryParse(_discount.text) ?? 0)}'
            ' · ${_item!.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemPicker(bool isDark) {
    final selected = _item;

    if (selected != null) {
      final headroom = selected.discountLimit > 0
          ? 'Kikomo cha punguzo: ${_money.format(selected.discountLimit)}'
          : null;

      return _field(
        isDark,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.inventory_2,
                    color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? AppColors.darkText : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        'Bei: ${_money.format(selected.unitPrice)} TSh',
                        if (headroom != null) headroom,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                            isDark ? AppColors.darkTextLight : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Badilisha bidhaa',
                onPressed: () => setState(() => _item = null),
              ),
            ],
          ),
        ),
      );
    }

    return _field(
      isDark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _itemSearch,
            decoration: InputDecoration(
              labelText: 'Tafuta bidhaa',
              border: InputBorder.none,
              suffixIcon: _searchingItems
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
            ),
            onChanged: _onItemSearchChanged,
          ),
          if (_items.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: _items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                ),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return InkWell(
                    onTap: () {
                      setState(() => _item = item);
                      FocusScope.of(context).unfocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkText : AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _money.format(item.unitPrice),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkTextLight
                                  : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else if (!_searchingItems && _itemSearch.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Hakuna bidhaa inayolingana',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
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
