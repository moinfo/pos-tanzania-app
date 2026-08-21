import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/approval.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/friendly_error.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/searchable_picker.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/state_views.dart';

/// Ask for one-time discounts for a customer, on as many items as the sale
/// needs.
///
/// The pickers are populated from the server's form_options, which is already
/// narrowed to this employee's stock locations and the customers under those
/// locations' supervisors — so there is nothing here the seller could choose
/// that the server would then refuse for scope.
///
/// One customer, one location, one reason, one day — and a list of items. Each
/// item becomes its own request, approved on its own, which is exactly how the
/// web form has always behaved; nothing here ties them together afterwards.
/// Before this the seller had to fill the whole form again, re-finding the same
/// shop, for every extra product they wanted to discount.
///
/// An approved request does not become a general price cut: it is one discount,
/// for one customer, on one item, on one day, consumed by a single sale whose
/// quantity matches.
class CreateDiscountRequestScreen extends StatefulWidget {
  const CreateDiscountRequestScreen({
    super.key,
    this.customerId,
    this.itemId,
    this.quantity,
  });

  /// Pre-fill from a sale in progress, so a seller who hits the item's
  /// discount limit with the customer in front of them can ask for more
  /// without abandoning the cart and re-finding both. The item arrives as the
  /// first row of the list, waiting only for an amount.
  final int? customerId;
  final int? itemId;
  final double? quantity;

  @override
  State<CreateDiscountRequestScreen> createState() =>
      _CreateDiscountRequestScreenState();
}

/// One item on the request. Each of these becomes a separate discount record.
class _DiscountLine {
  _DiscountLine({
    required this.item,
    required this.quantity,
    required this.discountAmount,
  });

  final DiscountEligibleItem item;
  double quantity;
  double discountAmount;

  double get total => quantity * discountAmount;

  /// A row the seller still has to finish — the checkout hand-off arrives with
  /// the item and the quantity but no amount, since only they can decide it.
  bool get isIncomplete => discountAmount <= 0 || quantity <= 0;
}

/// The rules the server will apply to a row, checked here so the seller finds
/// out before submitting rather than after. Kept as one function so the row
/// editor and the submit check cannot disagree.
String? _rowProblem(
  DiscountEligibleItem item,
  double quantity,
  double discount,
  NumberFormat money,
) {
  if (quantity <= 0) return 'Enter a quantity';
  if (discount <= 0) return 'Enter a discount amount';
  if (discount >= item.unitPrice) {
    return 'The discount cannot reach the item price '
        '(${money.format(item.unitPrice)})';
  }
  if (item.costPrice > 0 && discount >= item.costPrice) {
    return 'The discount cannot reach the cost price '
        '(${money.format(item.costPrice)})';
  }
  return null;
}

class _CreateDiscountRequestScreenState
    extends State<CreateDiscountRequestScreen> {
  final _api = ApiService();
  final _money = NumberFormat('#,##0', 'en_US');
  final _qty = NumberFormat('#,##0.###', 'en_US');
  final _formKey = GlobalKey<FormState>();

  final _reason = TextEditingController();

  DiscountFormOptions? _options;

  /// The whole eligible catalogue, fetched once. 488 rows is 7.6 KB on the
  /// wire; filtering locally beats a round trip per keystroke on 2G.
  List<DiscountEligibleItem> _items = [];

  /// The items being asked for, in the order the seller added them.
  final List<_DiscountLine> _lines = [];

  ScopedLocation? _location;
  ScopedCustomer? _customer;
  DateTime _validDate = DateTime.now();

  bool _loading = true;
  bool _searchingItems = false;
  bool _submitting = false;
  String? _error;

  /// Rows the server refused, kept on screen after a partial submit so the
  /// seller can see which of their items did not become requests, and why.
  List<Map<String, dynamic>> _rejected = [];

  /// Held across retries so a timeout that actually committed replays the
  /// original answer instead of raising a second request.
  ///
  /// Tied to the payload it was minted for. Reusing one id for a whole screen
  /// is wrong: edit the item or the amount after a timeout, submit again, and
  /// the server replays the FIRST request's response — the app reports success
  /// for a request that was never made. The whole item list is part of the key
  /// for the same reason: the server replays a batch, so adding, removing or
  /// re-pricing a single row has to mint a new id or the reply would describe
  /// the batch the seller has since changed.
  String? _requestId;
  String? _requestKey;

  String _payloadKey() => [
        _customer?.customerId,
        _location?.locationId,
        _reason.text.trim(),
        DateFormat('yyyy-MM-dd').format(_validDate),
        for (final line in _lines)
          '${line.item.itemId}:${line.quantity}:${line.discountAmount}',
      ].join('|');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

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

    await _loadItems();

    // The item can only be matched once the catalogue is in. It lands as the
    // first row with the sale's quantity and no amount yet — the row shows as
    // unfinished until the seller says how much off.
    final presetItem = widget.itemId;
    if (presetItem != null && mounted) {
      for (final candidate in _items) {
        if (candidate.itemId == presetItem) {
          final presetQuantity = widget.quantity;
          setState(() {
            _lines.add(_DiscountLine(
              item: candidate,
              quantity:
                  presetQuantity != null && presetQuantity > 0 ? presetQuantity : 0,
              discountAmount: 0,
            ));
          });
          break;
        }
      }
    }
  }

  Future<void> _loadItems() async {
    setState(() => _searchingItems = true);

    final response = await _api.getDiscountEligibleItems();
    if (!mounted) return;

    setState(() {
      _searchingItems = false;
      if (response.isSuccess && response.data != null) {
        _items = response.data!;
      } else {
        _items = [];
        _error = FriendlyError.of(response.message);
      }
    });
  }

  double get _totalGiven =>
      _lines.fold<double>(0, (sum, line) => sum + line.total);

  /// Pick an item, then say how much comes off it.
  Future<void> _addLine() async {
    final picked = await SearchablePicker.show<DiscountEligibleItem>(
      context,
      title: 'Choose an Item',
      items: _items,
      labelOf: (i) => i.name,
      subtitleOf: (i) => i.itemNumber,
      trailingOf: (i) => _money.format(i.unitPrice),
      searchHint: 'Search items...',
      emptyMessage: 'No matching item',
      numbered: false,
    );
    if (picked == null || !mounted) return;

    // The server refuses the same item twice in one request — the model allows
    // one discount per customer, item, location and day — so say so here
    // rather than let the seller build a request that cannot be sent.
    final existing = _lines.indexWhere((line) => line.item.itemId == picked.itemId);
    if (existing >= 0) {
      setState(() => _error = '${picked.name} is already on this request');
      await _editLine(existing);
      return;
    }

    final draft = await _showRowEditor(item: picked);
    if (draft == null || !mounted) return;

    setState(() {
      _error = null;
      _rejected = [];
      _lines.add(_DiscountLine(
        item: picked,
        quantity: draft.quantity,
        discountAmount: draft.discountAmount,
      ));
    });
  }

  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final draft = await _showRowEditor(
      item: line.item,
      quantity: line.quantity,
      discountAmount: line.discountAmount,
      isEditing: true,
    );
    if (draft == null || !mounted) return;

    setState(() {
      _error = null;
      line.quantity = draft.quantity;
      line.discountAmount = draft.discountAmount;
    });
  }

  Future<_RowDraft?> _showRowEditor({
    required DiscountEligibleItem item,
    double quantity = 0,
    double discountAmount = 0,
    bool isEditing = false,
  }) {
    return showModalBottomSheet<_RowDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RowEditorSheet(
        item: item,
        quantity: quantity,
        discountAmount: discountAmount,
        isEditing: isEditing,
        money: _money,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_customer == null) {
      setState(() => _error = 'Choose a customer');
      return;
    }
    if (_location == null) {
      setState(() => _error = 'Choose a location');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }

    // Every row, named by its position, so a seller with six items knows which
    // one to go back to.
    final problems = <String>[];
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      final problem =
          _rowProblem(line.item, line.quantity, line.discountAmount, _money);
      if (problem != null) {
        problems.add('Item ${index + 1} (${line.item.name}): $problem');
      }
    }
    if (problems.isNotEmpty) {
      setState(() => _error = problems.join('\n'));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _rejected = [];
    });

    final key = _payloadKey();
    if (_requestKey != key) {
      _requestKey = key;
      _requestId = const Uuid().v4();
    }

    final response = await _api.createOneTimeDiscountRequest(
      customerId: _customer!.customerId,
      stockLocationId: _location!.locationId,
      items: [
        for (final line in _lines)
          {
            'item_id': line.item.itemId,
            'quantity': line.quantity,
            'discount_amount': line.discountAmount,
          },
      ],
      reason: _reason.text.trim(),
      validDate: DateFormat('yyyy-MM-dd').format(_validDate),
      requestId: _requestId,
    );

    if (!mounted) return;

    if (!response.isSuccess) {
      setState(() {
        _submitting = false;
        _error = FriendlyError.of(response.message);
      });
      return;
    }

    final data = response.data ?? const <String, dynamic>{};
    final results = (data['results'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final failures =
        results.where((row) => row['created'] != true).toList(growable: false);

    // A partial batch: some rows became requests and some did not. Stay on the
    // screen, drop the rows that were created, and show what happened to the
    // rest — resubmitting then retries only what is left.
    if (failures.isNotEmpty) {
      final createdIds = results
          .where((row) => row['created'] == true)
          .map((row) => row['item_id'].toString())
          .toSet();

      setState(() {
        _submitting = false;
        _lines.removeWhere(
            (line) => createdIds.contains(line.item.itemId.toString()));
        _rejected = failures;
        _error = createdIds.isEmpty
            ? 'No request could be created'
            : '${createdIds.length} of ${results.length} requests were created. '
                'These were not:';
      });
      return;
    }

    final created = results.isEmpty ? 1 : results.length;
    final waiting = results.isEmpty
        ? (data['requires_approval'] == true ? 1 : 0)
        : results.where((row) => row['requires_approval'] == true).length;
    final document = data['document_number']?.toString() ?? '';

    // Under the bypass threshold the server activates the discount outright
    // and there is nobody to wait for -- say so rather than promising an
    // approval that will never arrive.
    final String message;
    if (created == 1) {
      message = waiting == 1
          ? 'Request $document sent for approval'
          : 'Discount $document approved automatically';
    } else if (waiting == created) {
      message = '$created discount requests sent for approval';
    } else if (waiting == 0) {
      message = '$created discounts approved automatically';
    } else {
      message = '$created discounts created, $waiting waiting for approval';
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Request a Discount'),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      // On the Scaffold rather than inside a branch, so the bar is there in
      // every state this screen can show: skeleton, error, no-permission and
      // the form itself.
      bottomNavigationBar: const AppBottomNavigation(currentIndex: -1),
      body: _loading ? _buildSkeleton(isDark) : _buildForm(isDark),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
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
        message: FriendlyError.of(_error ?? 'Could not load'),
        onRetry: FriendlyError.isPermanent(_error) ? null : _load,
        isDark: isDark,
      );
    }

    if (!options.canRequest) {
      return EmptyStateView(
        icon: Icons.lock_outline,
        title: 'You cannot raise discount requests',
        message: 'Ask your supervisor if you need this permission.',
        isDark: isDark,
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        // The bottom inset keeps Send Request clear of the navigation bar
        // instead of sitting flush on top of it.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_lines.isNotEmpty && _customer != null) _preview(isDark),

          if (options.locations.length > 1)
            _field(
              isDark,
              DropdownButtonFormField<ScopedLocation>(
                value: _location,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Location',
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
                'Customer',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                ),
              ),
              subtitle: Text(
                _customer?.customerName ?? 'Tap to choose',
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
                  title: 'Choose a Customer',
                  items: options.customers,
                  labelOf: (c) => c.customerName,
                  subtitleOf: (c) => c.phoneNumber,
                  searchHint: 'Search by name or phone number...',
                  emptyMessage: 'No matching customer',
                );
                if (picked != null) setState(() => _customer = picked);
              },
            ),
          ),

          _buildItemList(isDark),

          // The quantity is not advisory: redemption requires the sale's
          // quantity to match the row to within 0.001, so say so plainly.
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Each item becomes its own request, approved separately, and '
              'only applies to a sale with exactly that quantity.',
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
                  'Valid on',
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
                labelText: 'Reason',
                helperText: 'Applies to every item on this request',
                border: InputBorder.none,
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Give a reason' : null,
            ),
          ),

          if (_error != null) _errorPanel(isDark),

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
            label: Text(_lines.length > 1
                ? 'Send ${_lines.length} Requests'
                : 'Send Request'),
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

  /// The error banner, and — after a partial submit — the rows the server
  /// refused, each with the reason it gave.
  Widget _errorPanel(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.error_outline, color: AppColors.error, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            ],
          ),
          for (final row in _rejected)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 26),
              child: Text(
                '${row['item_name'] ?? 'Item ${(row['index'] as num? ?? 0).toInt() + 1}'}'
                ' — ${row['error'] ?? 'Not created'}',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// What is actually being given away, before it is asked for.
  ///
  /// The per-unit figure understates the ask: 500 off looks small until it is
  /// multiplied by a hundred cartons, and a six-item request hides it six times
  /// over. The approver will see each total, so the requester should see the
  /// sum of them.
  Widget _preview(bool isDark) {
    final count = _lines.length;

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
            'TOTAL DISCOUNT',
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
              '${_money.format(_totalGiven)} TSh',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == 1
                ? '1 item · 1 request'
                : '$count items · $count separate requests',
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

  Widget _buildItemList(bool isDark) {
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;

    return _field(
      isDark,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Items',
                      style: TextStyle(fontSize: 12, color: muted)),
                ),
                if (_lines.isNotEmpty)
                  Text(
                    '${_lines.length}',
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: muted),
                  ),
              ],
            ),
            for (var index = 0; index < _lines.length; index++)
              _itemRow(isDark, index),
            const SizedBox(height: 4),
            InkWell(
              onTap: _searchingItems ? null : _addLine,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _searchingItems
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_circle_outline,
                            size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      _searchingItems
                          ? 'Loading items...'
                          : (_lines.isEmpty ? 'Add an item' : 'Add another item'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _searchingItems ? muted : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(bool isDark, int index) {
    final line = _lines[index];
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final incomplete = line.isIncomplete;

    return InkWell(
      onTap: () => _editLine(index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (incomplete ? AppColors.warning : AppColors.success)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                incomplete ? Icons.edit_outlined : Icons.inventory_2,
                color: incomplete ? AppColors.warning : AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.item.name,
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
                    incomplete
                        ? 'Tap to set the quantity and discount'
                        : '${_qty.format(line.quantity)}'
                            ' × ${_money.format(line.discountAmount)} per item',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: incomplete ? AppColors.warning : muted,
                      fontWeight:
                          incomplete ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  incomplete ? '—' : _money.format(line.total),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.text,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove item',
              color: muted,
              onPressed: () => setState(() {
                _lines.removeAt(index);
                _error = null;
                _rejected = [];
              }),
            ),
          ],
        ),
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

/// What the row editor hands back.
class _RowDraft {
  const _RowDraft(this.quantity, this.discountAmount);

  final double quantity;
  final double discountAmount;
}

/// How much comes off one item, and for how many of it.
///
/// A sheet rather than two more fields on the form: the form now holds a list,
/// and a single pair of inputs sitting under it is ambiguous about which row it
/// belongs to. Here the item being priced is the sheet's title.
class _RowEditorSheet extends StatefulWidget {
  const _RowEditorSheet({
    required this.item,
    required this.quantity,
    required this.discountAmount,
    required this.isEditing,
    required this.money,
  });

  final DiscountEligibleItem item;
  final double quantity;
  final double discountAmount;
  final bool isEditing;
  final NumberFormat money;

  @override
  State<_RowEditorSheet> createState() => _RowEditorSheetState();
}

class _RowEditorSheetState extends State<_RowEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _discount;

  @override
  void initState() {
    super.initState();
    _quantity = TextEditingController(
      text: widget.quantity > 0 ? _plain(widget.quantity) : '',
    );
    _discount = TextEditingController(
      text: widget.discountAmount > 0 ? _plain(widget.discountAmount) : '',
    );
    _quantity.addListener(_refresh);
    _discount.addListener(_refresh);
  }

  static String _plain(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  @override
  void dispose() {
    _quantity.dispose();
    _discount.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  double? get _total {
    final qty = double.tryParse(_quantity.text);
    final off = double.tryParse(_discount.text);
    if (qty == null || off == null || qty <= 0 || off <= 0) return null;
    return qty * off;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkTextLight : AppColors.textLight;
    final total = _total;

    return Padding(
      // Lift the sheet above the keyboard so the button stays reachable.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          widget.item.name,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          'Price: ${widget.money.format(widget.item.unitPrice)} TSh',
                          if (widget.item.discountLimit > 0)
                            'Limit: ${widget.money.format(widget.item.discountLimit)}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 11.5, color: muted),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _sheetField(
                          isDark,
                          TextFormField(
                            controller: _quantity,
                            autofocus: widget.quantity <= 0,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              // Both number fields carry a helper so they end
                              // up the same height; one with and one without
                              // leaves the pair visibly misaligned.
                              helperText: 'on the sale',
                              border: InputBorder.none,
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Enter a quantity';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _sheetField(
                          isDark,
                          TextFormField(
                            controller: _discount,
                            autofocus: widget.quantity > 0 &&
                                widget.discountAmount <= 0,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*')),
                            ],
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              labelText: 'Discount',
                              helperText: 'per item',
                              border: InputBorder.none,
                            ),
                            validator: (value) => _rowProblem(
                              widget.item,
                              double.tryParse(_quantity.text) ?? 1,
                              double.tryParse(value ?? '') ?? 0,
                              widget.money,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'This row',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          total == null
                              ? '—'
                              : '${widget.money.format(total)} TSh',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkText : AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.pop(
                          context,
                          _RowDraft(
                            double.parse(_quantity.text),
                            double.parse(_discount.text),
                          ),
                        );
                      },
                      icon: Icon(widget.isEditing ? Icons.check : Icons.add),
                      label: Text(
                          widget.isEditing ? 'Save item' : 'Add to request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetField(bool isDark, Widget child) {
    return Container(
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
