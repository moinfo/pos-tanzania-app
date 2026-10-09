import 'package:flutter/material.dart';
import '../../services/transfer_service.dart';
import '../../services/api_service.dart';
import '../../models/transfer.dart';
import '../../models/item.dart';
import '../../models/stock_location.dart';
import '../../utils/constants.dart';

/// CTN-to-PC same-location item conversion (matches application/views/transfer/transfer.php).
/// Distinct from Stock Transfers (location-to-location).
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TransferService _service = TransferService();
  final ApiService _apiService = ApiService();

  List<StockLocation> _locations = [];
  int? _selectedLocationId;
  List<TransferHistoryRow> _history = [];
  bool _isLoading = false;
  String? _errorMessage;

  final _itemController = TextEditingController();
  final _quantityController = TextEditingController();
  List<Item> _itemResults = [];
  Item? _selectedParentItem;
  TransferInventoryInfo? _parentInfo;
  TransferInventoryInfo? _childInfo;
  bool _isLookingUp = false;
  bool _isSubmitting = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final locationsResponse = await _apiService.getAllStockLocations();
    if (!mounted) return;

    final locations = locationsResponse.data ?? [];
    setState(() {
      _locations = locations;
      _selectedLocationId ??= locations.isNotEmpty ? locations.first.locationId : null;
      _isLoading = false;
    });

    if (_selectedLocationId != null) _loadHistory();
  }

  Future<void> _loadHistory() async {
    final response = await _service.getTransferHistory(_selectedLocationId!);
    if (!mounted) return;
    if (response.statusCode == 440) {
      _onSessionExpired();
      return;
    }
    if (response.isSuccess) {
      setState(() => _history = response.data ?? []);
    }
  }

  void _onSessionExpired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session expired. Please log out and log back in.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _searchItems(String query) async {
    if (query.length < 2) {
      setState(() => _itemResults = []);
      return;
    }
    final response = await _apiService.getItems(search: query, limit: 15);
    if (!mounted) return;
    setState(() => _itemResults = response.data ?? []);
  }

  Future<void> _selectParentItem(Item item) async {
    setState(() {
      _selectedParentItem = item;
      _itemController.text = item.name;
      _itemResults = [];
      _parentInfo = null;
      _childInfo = null;
      _formError = null;
      _isLookingUp = true;
    });

    final locationId = _selectedLocationId;
    if (locationId == null) return;

    final parentResponse = await _service.getInventory(itemId: item.itemId, stockLocationId: locationId);
    if (!mounted) return;

    if (parentResponse.statusCode == 440) {
      setState(() => _isLookingUp = false);
      _onSessionExpired();
      return;
    }

    if (!parentResponse.isSuccess || parentResponse.data == null) {
      setState(() {
        _isLookingUp = false;
        _formError = parentResponse.message;
      });
      return;
    }

    final parentInfo = parentResponse.data!;
    if (parentInfo.childItemId == null) {
      setState(() {
        _isLookingUp = false;
        _parentInfo = parentInfo;
        _formError = 'This item has no linked PC item configured for conversion.';
      });
      return;
    }

    final childResponse = await _service.getInventoryTwo(
      itemId: parentInfo.childItemId!,
      stockLocationId: locationId,
    );
    if (!mounted) return;

    setState(() {
      _isLookingUp = false;
      _parentInfo = parentInfo;
      if (childResponse.isSuccess) {
        _childInfo = childResponse.data;
      } else {
        _formError = childResponse.message;
      }
    });
  }

  double get _quantityReceived {
    final qty = double.tryParse(_quantityController.text) ?? 0;
    return qty * (_parentInfo?.ctn ?? 0);
  }

  double get _pcPrice {
    final ctn = _parentInfo?.ctn ?? 0;
    if (ctn == 0) return 0;
    return (_parentInfo?.costPrice ?? 0) / ctn;
  }

  bool get _costMatches =>
      _childInfo != null && _pcPrice.round() == (_childInfo!.costPrice).round();

  bool get _insufficientStock {
    final qty = double.tryParse(_quantityController.text);
    return _parentInfo != null && qty != null && qty > _parentInfo!.currentStock;
  }

  bool get _canSubmit {
    final qty = double.tryParse(_quantityController.text) ?? 0;
    return _parentInfo != null &&
        _childInfo != null &&
        qty > 0 &&
        qty <= (_parentInfo!.currentStock) &&
        _costMatches;
  }

  Future<void> _submit() async {
    final locationId = _selectedLocationId;
    final parentItem = _selectedParentItem;
    final parentInfo = _parentInfo;
    final childInfo = _childInfo;
    if (locationId == null || parentItem == null || parentInfo == null || childInfo == null) return;

    setState(() => _isSubmitting = true);

    final response = await _service.addTransfer(
      stockLocationId: locationId,
      parentItemId: parentItem.itemId,
      childItemId: parentInfo.childItemId!,
      quantity: double.tryParse(_quantityController.text) ?? 0,
      quantityReceived: _quantityReceived,
      ctnPrice: parentInfo.costPrice,
      pcPrice: _pcPrice,
      childCostPrice: childInfo.costPrice,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response.statusCode == 440) {
      _onSessionExpired();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(response.isSuccess ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(response.isSuccess ? 'Transfer completed' : response.message)),
          ],
        ),
        backgroundColor: response.isSuccess ? Colors.green[700] : Colors.red[700],
      ),
    );

    if (response.isSuccess) {
      setState(() {
        _selectedParentItem = null;
        _itemController.clear();
        _quantityController.clear();
        _parentInfo = null;
        _childInfo = null;
      });
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Same as Stock Transfers: this screen's cards/background are hardcoded
    // light (Colors.white on 0xFFF6F7FA) and its unstyled Text widgets rely
    // on that for contrast against the default (theme-adaptive) text color -
    // forcing light theme here keeps it consistent regardless of dark mode.
    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: AppColors.brandPrimary,
        colorScheme: ThemeData.light().colorScheme.copyWith(primary: AppColors.brandPrimary),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FA),
        appBar: AppBar(title: const Text('Transfer'), backgroundColor: AppColors.brandPrimary),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isLoading
              ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
              : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('error'),
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: DropdownButtonFormField<int>(
              initialValue: _selectedLocationId,
              decoration: InputDecoration(
                labelText: 'Stock Location',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.store_outlined, color: AppColors.brandPrimary),
              ),
              items: _locations
                  .map((l) => DropdownMenuItem(value: l.locationId, child: Text(l.locationName)))
                  .toList(),
              onChanged: (id) {
                setState(() {
                  _selectedLocationId = id;
                  _selectedParentItem = null;
                  _parentInfo = null;
                  _childInfo = null;
                  _itemController.clear();
                });
                _loadHistory();
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildConversionCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.brandPrimary),
              const SizedBox(width: 6),
              Text('Transfer Report',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.brandPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, color: Colors.grey[350], size: 32),
                  const SizedBox(height: 8),
                  Text('No transfer history for this location.', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          else
            ..._history.asMap().entries.map((entry) => TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 250 + (entry.key * 40).clamp(0, 400)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(offset: Offset(0, (1 - value) * 10), child: child),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: ListTile(
                      title: Text(entry.value.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Qty: ${entry.value.quantity.toStringAsFixed(0)}'),
                      trailing: Text(
                        entry.value.total.toStringAsFixed(0),
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandPrimary),
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildConversionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelHeader(Icons.logout, 'From (Bulk / CTN)', Colors.orange),
            const SizedBox(height: 10),
            TextField(
              controller: _itemController,
              decoration: InputDecoration(
                labelText: 'Item',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.search),
              ),
              onChanged: _searchItems,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: _itemResults.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: _itemResults
                            .map((item) => ListTile(
                                  dense: true,
                                  title: Text(item.name),
                                  onTap: () => _selectParentItem(item),
                                ))
                            .toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity to Convert', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _isLookingUp
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    )
                  : _parentInfo == null
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            _infoGrid([
                              _InfoItem('Current Stock', _parentInfo!.currentStock.toStringAsFixed(0)),
                              _InfoItem('Units / CTN', _parentInfo!.ctn.toStringAsFixed(0)),
                              _InfoItem('CTN Price', _parentInfo!.costPrice.toStringAsFixed(0)),
                              _InfoItem('PC Price', _pcPrice.toStringAsFixed(0)),
                            ]),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            _panelHeader(Icons.login, 'To (Unit / PC)', Colors.green),
                            if (_childInfo != null) ...[
                              const SizedBox(height: 10),
                              _infoGrid([
                                _InfoItem('Item', _childInfo!.childName ?? '-'),
                                _InfoItem('Qty Received', _quantityReceived.toStringAsFixed(0)),
                                _InfoItem('Current Stock', _childInfo!.currentStock.toStringAsFixed(0)),
                                _InfoItem('Price', _childInfo!.costPrice.toStringAsFixed(0)),
                              ]),
                            ],
                            const SizedBox(height: 12),
                            _buildStatusBanner(),
                          ],
                        ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton.icon(
                  onPressed: _canSubmit && !_isSubmitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.compare_arrows, color: Colors.white, size: 18),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit Transfer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelHeader(IconData icon, String label, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color.withOpacity(0.9))),
      ],
    );
  }

  Widget _infoGrid(List<_InfoItem> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              const SizedBox(height: 2),
              Text(item.value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusBanner() {
    IconData icon;
    Color color;
    String message;

    if (_formError != null) {
      icon = Icons.remove_circle;
      color = Colors.red;
      message = _formError!;
    } else if (_insufficientStock) {
      icon = Icons.warning_amber;
      color = Colors.red;
      message = 'Cannot transfer — only ${_parentInfo!.currentStock.toStringAsFixed(0)} available.';
    } else if (_childInfo != null && !_costMatches) {
      icon = Icons.remove_circle;
      color = Colors.red;
      message = 'Cannot transfer — item cost does not match.';
    } else if (_costMatches) {
      icon = Icons.check_circle;
      color = Colors.green;
      message = 'Item ready for transfer — cost matches.';
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  _InfoItem(this.label, this.value);
}
