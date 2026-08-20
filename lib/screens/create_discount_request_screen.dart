import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/approval.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

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
  final _money = NumberFormat('#,##0');
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

  @override
  void initState() {
    super.initState();
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

  Future<void> _load() async {
    final response = await _api.getDiscountFormOptions();
    if (!mounted) return;

    if (!response.isSuccess || response.data == null) {
      setState(() {
        _loading = false;
        _error = response.message;
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
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchItems(value),
    );
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
      return 'Punguzo haliwezi kufikia bei ya bidhaa (${_money.format(item.unitPrice)})';
    }
    if (item.costPrice > 0 && value >= item.costPrice) {
      return 'Punguzo haliwezi kufikia bei ya gharama (${_money.format(item.costPrice)})';
    }
    return null;
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

    final response = await _api.createOneTimeDiscountRequest(
      customerId: _customer!.customerId,
      itemId: _item!.itemId,
      stockLocationId: _location!.locationId,
      quantity: double.parse(_quantity.text),
      discountAmount: double.parse(_discount.text),
      reason: _reason.text.trim(),
      validDate: DateFormat('yyyy-MM-dd').format(_validDate),
    );

    if (!mounted) return;

    if (response.isSuccess) {
      // Under the bypass threshold the server activates the discount outright
      // and there is nobody to wait for — say so rather than promising an
      // approval that will never arrive.
      final needsApproval = response.data?['requires_approval'] == true;
      final document = response.data?['document_number']?.toString() ?? '';

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
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
        title: const Text('Omba Punguzo'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(isDark),
    );
  }

  Widget _buildForm(bool isDark) {
    final options = _options;

    if (options == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error ?? 'Imeshindikana kupakia'),
        ),
      );
    }

    if (!options.canRequest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
              const SizedBox(height: 14),
              Text(
                'Huna ruhusa ya kuomba punguzo',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.text,
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
          if (options.locations.length > 1)
            _card(
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
                          child: Text(location.locationName),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _location = value),
              ),
            ),

          _card(
            isDark,
            DropdownButtonFormField<ScopedCustomer>(
              value: _customer,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mteja',
                border: InputBorder.none,
              ),
              items: options.customers
                  .map((customer) => DropdownMenuItem(
                        value: customer,
                        child: Text(
                          customer.customerName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _customer = value),
              validator: (value) => value == null ? 'Chagua mteja' : null,
            ),
          ),

          // Item picker: search box plus the filtered list, because 488 carton
          // items in a dropdown is unusable on a phone.
          _card(
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
                if (_item != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 16, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _item!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Bei: ${_money.format(_item!.unitPrice)} TSh',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextLight
                                      : AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _item = null),
                        ),
                      ],
                    ),
                  )
                else if (_items.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 190),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${_money.format(item.unitPrice)} TSh',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () {
                            setState(() => _item = item);
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          _card(
            isDark,
            TextFormField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Idadi',
                border: InputBorder.none,
                helperText: 'Mauzo yatakayotumia punguzo lazima yawe na idadi hii',
              ),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) return 'Weka idadi';
                return null;
              },
            ),
          ),

          _card(
            isDark,
            TextFormField(
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Punguzo kwa kila kimoja (TSh)',
                border: InputBorder.none,
              ),
              validator: _validateDiscount,
            ),
          ),

          if (options.canSetDate)
            _card(
              isDark,
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tarehe ya kutumika', style: TextStyle(fontSize: 12)),
                subtitle: Text(
                  DateFormat('EEE, dd MMM yyyy').format(_validDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
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

          _card(
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

  Widget _card(bool isDark, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
